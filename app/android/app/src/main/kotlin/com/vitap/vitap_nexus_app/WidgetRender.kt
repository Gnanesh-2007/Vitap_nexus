package com.vitap.vitap_nexus_app

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.graphics.Typeface
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/** Result of drawing the next-class widget: the art plus what the live timer should count to. */
class NextFrame(val bitmap: Bitmap, val remainingMs: Long?, val compact: Boolean)

/**
 * Draws every widget as a bitmap. All coordinates below are in dp - the canvas
 * is pre-scaled by the screen density - so layouts read like a design spec.
 * Nothing here touches a Context, which keeps it renderable in plain JVM tests.
 */
object WidgetRender {
    private const val WHITE = 0xFFFFFFFF.toInt()
    private const val SOFT = 0xFFB9C0D4.toInt()
    private const val MUTED = 0xFF7F879C.toInt()
    private const val GREEN = 0xFF4ADE80.toInt()
    private const val AMBER = 0xFFFBBF24.toInt()
    private const val RED = 0xFFFB7185.toInt()
    private const val DEFAULT_ACCENT = 0xFF8FB4FF.toInt()

    private val BOLD: Typeface by lazy { Typeface.create("sans-serif", Typeface.BOLD) }
    private val BLACK: Typeface by lazy { Typeface.create("sans-serif-black", Typeface.NORMAL) }
    private val MEDIUM: Typeface by lazy { Typeface.create("sans-serif-medium", Typeface.NORMAL) }
    private val REGULAR: Typeface by lazy { Typeface.create("sans-serif", Typeface.NORMAL) }

    // ------------------------------------------------------------------
    // Drawing toolkit
    // ------------------------------------------------------------------

    private fun begin(w: Float, h: Float, density: Float): Pair<Bitmap, Canvas> {
        var scale = density
        val px = w * h * scale * scale
        val maxPx = 1_400_000f
        if (px > maxPx) scale *= sqrt(maxPx / px)
        val bmp = Bitmap.createBitmap(
            max(1, ceil(w * scale).toInt()), max(1, ceil(h * scale).toInt()),
            Bitmap.Config.ARGB_8888,
        )
        val c = Canvas(bmp)
        c.scale(scale, scale)
        return bmp to c
    }

    private fun alpha(color: Int, a: Int) = (color and 0x00FFFFFF) or (a shl 24)

    private fun shiftHue(color: Int, deg: Float): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        hsv[0] = (hsv[0] + deg + 360f) % 360f
        hsv[1] = min(1f, hsv[1] * 1.15f + 0.1f)
        return Color.HSVToColor(hsv)
    }

    private fun tp(size: Float, color: Int, face: Typeface, spacing: Float = 0f) =
        TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            textSize = size
            this.color = color
            typeface = face
            letterSpacing = spacing
        }

    /** Truncates with an ellipsis so the text never runs past [maxW]. */
    private fun fit(s: String, p: TextPaint, maxW: Float): String {
        if (maxW <= 0f) return ""
        if (p.measureText(s) <= maxW) return s
        var lo = 0
        var hi = s.length
        while (lo < hi) {
            val mid = (lo + hi + 1) / 2
            if (p.measureText(s.substring(0, mid).trimEnd() + "…") <= maxW) lo = mid else hi = mid - 1
        }
        return if (lo == 0) "" else s.substring(0, lo).trimEnd() + "…"
    }

    /** Left-aligned single line; returns the drawn width. */
    private fun Canvas.textL(s: String, x: Float, base: Float, p: TextPaint, maxW: Float = 10_000f): Float {
        val t = fit(s, p, maxW)
        drawText(t, x, base, p)
        return p.measureText(t)
    }

    private fun Canvas.textR(s: String, right: Float, base: Float, p: TextPaint, maxW: Float = 10_000f): Float {
        val t = fit(s, p, maxW)
        val tw = p.measureText(t)
        drawText(t, right - tw, base, p)
        return tw
    }

    private fun Canvas.textC(s: String, cx: Float, base: Float, p: TextPaint, maxW: Float = 10_000f) {
        val t = fit(s, p, maxW)
        drawText(t, cx - p.measureText(t) / 2f, base, p)
    }

    /** Wrapped text block; returns its height. */
    private fun Canvas.paragraph(s: String, x: Float, top: Float, width: Float, p: TextPaint, maxLines: Int): Float {
        val sl = StaticLayout.Builder.obtain(s, 0, s.length, p, max(1, width.toInt()))
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .setIncludePad(false)
            .setLineSpacing(0f, 0.96f)
            .build()
        save()
        translate(x, top)
        sl.draw(this)
        restore()
        return sl.height.toFloat()
    }

    /** Rounded tag with text; returns its width. */
    private fun Canvas.pill(s: String, x: Float, cy: Float, p: TextPaint, bg: Int, padH: Float = 7f, height: Float = 17f, maxW: Float = 10_000f): Float {
        val t = fit(s, p, maxW - padH * 2)
        val tw = p.measureText(t)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bg }
        drawRoundRect(RectF(x, cy - height / 2, x + tw + padH * 2, cy + height / 2), height / 2, height / 2, paint)
        drawText(t, x + padH, cy - (p.ascent() + p.descent()) / 2f, p)
        return tw + padH * 2
    }

    /** The shared card: deep gradient, two soft colour glows and a glass edge. */
    private fun card(c: Canvas, w: Float, h: Float, accent: Int) {
        val r = min(26f, min(w, h) / 2f)
        val rect = RectF(0.5f, 0.5f, w - 0.5f, h - 0.5f)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)

        p.shader = LinearGradient(
            0f, 0f, w * 0.6f, h,
            intArrayOf(0xFF1D2233.toInt(), 0xFF11141E.toInt(), 0xFF0A0C13.toInt()),
            floatArrayOf(0f, 0.55f, 1f), Shader.TileMode.CLAMP,
        )
        c.drawRoundRect(rect, r, r, p)

        val big = max(w, h)
        p.shader = RadialGradient(
            w * 0.95f, -h * 0.15f, big * 0.85f,
            intArrayOf(alpha(accent, 0x5C), alpha(accent, 0x18), alpha(accent, 0)),
            floatArrayOf(0f, 0.5f, 1f), Shader.TileMode.CLAMP,
        )
        c.drawRoundRect(rect, r, r, p)

        val second = shiftHue(accent, 55f)
        p.shader = RadialGradient(
            -w * 0.05f, h * 1.2f, big * 0.7f,
            intArrayOf(alpha(second, 0x3A), alpha(second, 0)),
            null, Shader.TileMode.CLAMP,
        )
        c.drawRoundRect(rect, r, r, p)

        p.shader = LinearGradient(
            0f, 0f, w, h,
            intArrayOf(0x40FFFFFF, 0x0DFFFFFF, 0x1FFFFFFF),
            floatArrayOf(0f, 0.6f, 1f), Shader.TileMode.CLAMP,
        )
        p.style = Paint.Style.STROKE
        p.strokeWidth = 1f
        c.drawRoundRect(RectF(1f, 1f, w - 1f, h - 1f), r - 0.5f, r - 0.5f, p)
    }

    private fun emptyState(c: Canvas, w: Float, h: Float, accent: Int, message: String) {
        val pad = 16f
        c.textL("VITAP NEXUS", pad, pad + 9f, tp(9.5f, accent, BOLD, 0.14f))
        c.paragraph(message, pad, pad + 20f, w - pad * 2, tp(13f, SOFT, MEDIUM), 4)
    }

    private fun statusColor(p: Double) = when {
        p < 75.0 -> RED
        p < 80.0 -> AMBER
        else -> GREEN
    }

    private fun classTitle(c: ClassItem): String =
        if (c.lab && !c.name.contains("lab", ignoreCase = true)) "${c.name} Lab" else c.name

    private fun secondsNow(cal: Calendar) =
        cal.get(Calendar.HOUR_OF_DAY) * 3600 + cal.get(Calendar.MINUTE) * 60 + cal.get(Calendar.SECOND)

    private fun dayLabel(cal: Calendar, offset: Int): String =
        if (offset == 1) "Tomorrow" else WidgetData.dayName((WidgetData.dayIndex(cal) + offset) % 7)

    // ------------------------------------------------------------------
    // 1. Day timeline (4x2)
    // ------------------------------------------------------------------

    fun timeline(snap: Snapshot?, w: Float, h: Float, density: Float, cal: Calendar): Bitmap {
        val (bmp, c) = begin(w, h, density)
        val accent = snap?.accent ?: DEFAULT_ACCENT
        card(c, w, h, accent)
        if (snap == null) {
            emptyState(c, w, h, accent, "Open VITAP Nexus once and your day shows up here.")
            return bmp
        }

        val small = h < 125f
        val pad = if (small) 14f else 16f
        val now = WidgetData.minutesNow(cal)
        val st = WidgetData.today(snap, cal)
        val today = snap.days[WidgetData.dayIndex(cal)]
        val hero = st.ongoing ?: st.upcoming.firstOrNull()
        val then = if (st.ongoing != null) st.upcoming.firstOrNull() else st.upcoming.getOrNull(1)

        var track = today
        var live = true
        val label: String
        val title: String
        var venue: String? = null
        val sub: String
        val heroColor: Int

        if (hero != null) {
            heroColor = snap.colorFor(hero.code)
            label = if (st.ongoing != null) {
                "NOW  ·  UNTIL ${WidgetData.fmtTime(hero.end).uppercase()}"
            } else {
                "UP NEXT  ·  ${WidgetData.fmtTime(hero.start).uppercase()}"
            }
            title = classTitle(hero)
            venue = hero.venue.takeIf { it.isNotBlank() }
            sub = WidgetData.fmtRange(hero)
        } else {
            heroColor = accent
            val next = WidgetData.nextDayWithClasses(snap, cal)
            if (st.total == 0) {
                label = "FREE DAY"
                title = "No classes today"
                if (next != null) {
                    track = next.second
                    live = false
                }
            } else {
                label = "ALL DONE"
                title = "That's a wrap for today"
                if (next != null) {
                    track = next.second
                    live = false
                }
            }
            sub = next?.let {
                val n = it.second.size
                "${dayLabel(cal, it.first)}  ·  $n class${if (n == 1) "" else "es"} from ${WidgetData.fmtTime(it.second.first().start)}"
            } ?: SimpleDateFormat("EEEE d MMM", Locale.getDefault()).format(cal.time)
        }

        val trackTop = h - pad - 22f
        val showThen = then != null && w >= 250f
        val rw = if (showThen) (w * 0.30f).coerceIn(78f, 116f) else 0f
        val leftW = if (showThen) w - pad * 2 - rw - 22f else w - pad * 2

        // --- hero block
        val labelBase = pad + 9f
        var lx = pad
        if (st.ongoing != null) {
            val dot = Paint(Paint.ANTI_ALIAS_FLAG)
            dot.color = alpha(heroColor, 0x55)
            c.drawCircle(pad + 4f, labelBase - 3.4f, 5.5f, dot)
            dot.color = heroColor
            c.drawCircle(pad + 4f, labelBase - 3.4f, 3f, dot)
            lx = pad + 14f
        }
        c.textL(label, lx, labelBase, tp(9.5f, heroColor, BOLD, 0.1f), leftW - (lx - pad))
        if (hero != null && then == null && w >= 250f) {
            c.textR("LAST CLASS", w - pad, labelBase, tp(8.5f, MUTED, BOLD, 0.14f))
        }

        val titleTop = labelBase + 6f
        val th = c.paragraph(
            title, pad, titleTop, leftW,
            tp(if (small) 16f else 18f, WHITE, BOLD, -0.01f),
            if (h >= 140f) 2 else 1,
        )
        val subCy = titleTop + th + 12f
        if (subCy + 9f < trackTop - 3f) {
            var sx = pad
            if (venue != null) {
                sx += c.pill(venue, pad, subCy, tp(10f, WHITE, MEDIUM), 0x24FFFFFF, maxW = leftW * 0.5f) + 7f
            }
            val sp = tp(10.5f, SOFT, REGULAR)
            val room = pad + leftW - sx
            val line = if (hero != null && sp.measureText(sub) > room) WidgetData.fmtTime(hero.start) else sub
            c.textL(line, sx, subCy - (sp.ascent() + sp.descent()) / 2f, sp, room)
        }

        // --- "then" column
        if (showThen && then != null) {
            val x0 = w - pad - rw
            val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x1FFFFFFF }
            c.drawRoundRect(RectF(x0 - 12f, pad + 1f, x0 - 11f, trackTop - 10f), 0.5f, 0.5f, line)
            val col = snap.colorFor(then.code)
            c.textL("THEN", x0, pad + 9f, tp(8.5f, MUTED, BOLD, 0.16f))
            c.textL(WidgetData.fmtTime(then.start), x0, pad + 26f, tp(12.5f, col, BOLD), rw)
            c.textL(classTitle(then), x0, pad + 41f, tp(11.5f, WHITE, MEDIUM), rw)
            if (pad + 55f < trackTop - 8f && then.venue.isNotBlank()) {
                c.textL(then.venue, x0, pad + 55f, tp(9.5f, MUTED, REGULAR), rw)
            }
        }

        drawDayTrack(c, snap, track, live, now, pad, w - pad, trackTop, h - pad + 1f)
        return bmp
    }

    /** The whole day as one strip: a block per class, gaps for breaks, a marker for "now". */
    private fun drawDayTrack(
        c: Canvas, snap: Snapshot, list: List<ClassItem>, live: Boolean, now: Int,
        x0: Float, x1: Float, top: Float, labelBase: Float,
    ) {
        if (list.isEmpty()) return
        val trackH = 8f
        val startMin = (list.first().start / 60) * 60
        val endMin = ((list.maxOf { it.end } + 59) / 60) * 60
        val span = max(60, endMin - startMin).toFloat()
        fun x(m: Int) = x0 + (m - startMin) / span * (x1 - x0)

        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.color = 0x14FFFFFF
        c.drawRoundRect(RectF(x0, top, x1, top + trackH), trackH / 2, trackH / 2, p)

        for (item in list) {
            val col = snap.colorFor(item.code)
            val rect = RectF(x(item.start), top, max(x(item.start) + 3f, x(item.end) - 1.5f), top + trackH)
            val ongoing = live && item.start <= now && now < item.end
            val past = live && item.end <= now
            if (ongoing) {
                p.color = alpha(col, 0xB0)
                p.maskFilter = BlurMaskFilter(6f, BlurMaskFilter.Blur.NORMAL)
                c.drawRoundRect(rect, 4f, 4f, p)
                p.maskFilter = null
            }
            p.color = alpha(col, if (past) 0x4D else if (ongoing) 0xFF else 0xDD)
            c.drawRoundRect(rect, 4f, 4f, p)
        }

        // Hour ticks
        val hours = (endMin - startMin) / 60
        val step = if (hours > 7) 2 else 1
        val hp = tp(8.5f, MUTED, MEDIUM)
        var m = startMin
        while (m <= endMin) {
            val h24 = (m / 60) % 24
            val txt = (if (h24 % 12 == 0) 12 else h24 % 12).toString()
            val tw = hp.measureText(txt)
            val tx = (x(m) - tw / 2f).coerceIn(x0, x1 - tw)
            c.drawText(txt, tx, labelBase, hp)
            m += step * 60
        }

        if (live && now in startMin..endMin) {
            val nx = x(now)
            p.color = 0x66FFFFFF
            p.maskFilter = BlurMaskFilter(4f, BlurMaskFilter.Blur.NORMAL)
            c.drawRoundRect(RectF(nx - 2f, top - 5f, nx + 2f, top + trackH + 5f), 2f, 2f, p)
            p.maskFilter = null
            p.color = WHITE
            c.drawRoundRect(RectF(nx - 1.5f, top - 4.5f, nx + 1.5f, top + trackH + 4.5f), 1.5f, 1.5f, p)
        }
    }

    // ------------------------------------------------------------------
    // 2. Next class ring (2x2) - the live timer is overlaid by the caller
    // ------------------------------------------------------------------

    fun nextClass(
        snap: Snapshot?, w: Float, h: Float, density: Float, cal: Calendar,
        previewTimer: String? = null, // only for static preview images
    ): NextFrame {
        val (bmp, c) = begin(w, h, density)
        val accent = snap?.accent ?: DEFAULT_ACCENT
        card(c, w, h, accent)
        val compact = h < 132f
        if (snap == null) {
            emptyState(c, w, h, accent, "Open the app once to sync.")
            return NextFrame(bmp, null, compact)
        }

        val cx = w / 2f
        // These offsets are mirrored by the Chronometer overlay in the layouts.
        val cy = if (compact) h / 2f - 13f else h / 2f - 5f
        val r = if (compact) min(cy - 10f, (w - 36f) / 2f) else min(min(cy - 30f, 44f), (w - 40f) / 2f)
        val stroke = if (compact) 6f else 7f
        val ringRect = RectF(cx - r + stroke / 2, cy - r + stroke / 2, cx + r - stroke / 2, cy + r - stroke / 2)

        val st = WidgetData.today(snap, cal)
        val today = snap.days[WidgetData.dayIndex(cal)]
        val item = st.ongoing ?: st.upcoming.firstOrNull()
        val nowSecs = secondsNow(cal)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        p.color = 0x1FFFFFFF
        c.drawOval(ringRect, p)

        val nameP = tp(if (compact) 12f else 13f, WHITE, BOLD)
        val subP = tp(if (compact) 9.5f else 10f, SOFT, REGULAR)
        val nameBase = cy + r + (if (compact) 15f else 18f)
        val subBase = nameBase + (if (compact) 13f else 14f)
        val textW = w - 24f

        if (item == null) {
            p.color = alpha(GREEN, 0x66)
            c.drawOval(ringRect, p)
            val tick = Path().apply {
                moveTo(cx - r * 0.28f, cy + r * 0.02f)
                lineTo(cx - r * 0.06f, cy + r * 0.24f)
                lineTo(cx + r * 0.32f, cy - r * 0.2f)
            }
            p.color = GREEN
            p.strokeWidth = stroke * 0.7f
            p.strokeJoin = Paint.Join.ROUND
            c.drawPath(tick, p)
            if (!compact) c.textC(if (st.total == 0) "FREE DAY" else "ALL DONE", cx, 23f, tp(9f, GREEN, BOLD, 0.16f))
            c.textC(if (st.total == 0) "No classes today" else "Done for today", cx, nameBase, nameP, textW)
            val next = WidgetData.nextDayWithClasses(snap, cal)
            if (next != null) {
                c.textC(
                    "${dayLabel(cal, next.first)} at ${WidgetData.fmtTime(next.second.first().start)}",
                    cx, subBase, subP, textW,
                )
            }
            return NextFrame(bmp, null, compact)
        }

        val ongoing = st.ongoing != null
        val col = snap.colorFor(item.code)
        val frac: Float
        val targetSecs: Int
        if (ongoing) {
            targetSecs = item.end * 60
            frac = (nowSecs - item.start * 60f) / max(60f, (item.end - item.start) * 60f)
        } else {
            targetSecs = item.start * 60
            val prevEnd = today.lastOrNull { it.end * 60 <= nowSecs }?.end ?: (item.start - 60)
            val base = max(prevEnd, item.start - 120) * 60
            frac = (nowSecs - base).toFloat() / max(60, item.start * 60 - base)
        }
        val sweep = 360f * frac.coerceIn(0.02f, 1f)

        p.shader = SweepGradient(cx, cy, intArrayOf(accent, col, shiftHue(col, 30f), accent), null).apply {
            setLocalMatrix(Matrix().apply { setRotate(-90f, cx, cy) })
        }
        p.maskFilter = BlurMaskFilter(5f, BlurMaskFilter.Blur.NORMAL)
        p.alpha = 0x99
        c.drawArc(ringRect, -90f, sweep, false, p)
        p.maskFilter = null
        p.alpha = 0xFF
        c.drawArc(ringRect, -90f, sweep, false, p)
        p.shader = null

        // Knob at the tip of the arc
        val ang = Math.toRadians((-90f + sweep).toDouble())
        val kr = r - stroke / 2
        val knob = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = WHITE }
        c.drawCircle(cx + (kr * cos(ang)).toFloat(), cy + (kr * sin(ang)).toFloat(), stroke * 0.3f, knob)

        if (!compact) {
            c.textC(if (ongoing) "ENDS IN" else "STARTS IN", cx, 23f, tp(9f, col, BOLD, 0.16f))
        }
        if (previewTimer != null) {
            val tpm = tp(if (compact) 13f else 15f, WHITE, BOLD)
            c.textC(previewTimer, cx, cy - (tpm.ascent() + tpm.descent()) / 2f, tpm)
        }
        c.textC(classTitle(item), cx, nameBase, nameP, textW)
        val where = item.venue.takeIf { it.isNotBlank() }
        val time = if (ongoing) "until ${WidgetData.fmtTime(item.end)}" else WidgetData.fmtTime(item.start)
        val full = listOfNotNull(where, time).joinToString("  ·  ")
        c.textC(if (subP.measureText(full) > textW) time else full, cx, subBase, subP, textW)

        return NextFrame(bmp, (targetSecs - nowSecs).coerceAtLeast(0) * 1000L, compact)
    }

    // ------------------------------------------------------------------
    // 3. Attendance - one ring per subject, or a detailed list when tall
    // ------------------------------------------------------------------

    private fun courseLabel(c: CourseItem): String {
        val a = WidgetData.acronym(c.name, c.code)
        return if (c.lab) "$a Lab" else a
    }

    private fun hint(c: CourseItem): String = when {
        c.bunk > 0 -> "skip ${c.bunk}"
        c.bunk < 0 -> "need ${-c.bunk}"
        else -> "on edge"
    }

    fun attendance(snap: Snapshot?, w: Float, h: Float, density: Float): Bitmap {
        val (bmp, c) = begin(w, h, density)
        val accent = snap?.accent ?: DEFAULT_ACCENT
        card(c, w, h, accent)
        val courses = snap?.courses.orEmpty()
        if (snap == null || courses.isEmpty()) {
            emptyState(c, w, h, accent, "Open VITAP Nexus once to load your attendance.")
            return bmp
        }

        val pad = 14f
        val header = h >= 138f
        val top = if (header) pad + 20f else pad - 2f
        if (header) {
            c.textL("ATTENDANCE", pad + 2f, pad + 9f, tp(9.5f, accent, BOLD, 0.14f))
            if (w >= 230f) {
                val low = courses.count { it.percent < 75.0 }
                val hp = tp(9.5f, if (low > 0) RED else GREEN, BOLD, 0.06f)
                c.textR(if (low > 0) "$low BELOW 75%" else "ALL ABOVE 75%", w - pad - 2f, pad + 9f, hp)
            }
        }

        val listRow = (h - top - pad + 4f) / courses.size
        if (h >= 200f && listRow >= 17f && w >= 220f) {
            attendanceList(c, courses, w, pad, top, min(27f, listRow))
        } else {
            attendanceRings(c, courses.take(12), w, h, pad, top)
        }
        return bmp
    }

    private fun attendanceRings(c: Canvas, courses: List<CourseItem>, w: Float, h: Float, pad: Float, top: Float) {
        val n = courses.size
        val availW = w - pad * 2
        val availH = h - top - pad + 4f
        val textH = 25f
        var bestRows = 1
        var bestD = 0f
        for (rows in 1..4) {
            val cols = ceil(n / rows.toFloat()).toInt()
            val d = min(availW / cols - 7f, availH / rows - textH - 3f)
            if (d > bestD) {
                bestD = d
                bestRows = rows
            }
        }
        val d = bestD.coerceIn(18f, 58f)
        val rows = bestRows
        val cols = ceil(n / rows.toFloat()).toInt()
        val cellW = availW / cols
        val cellH = d + textH
        val gap = ((availH - rows * cellH) / (rows + 1)).coerceAtLeast(0f)
        val stroke = max(3f, d * 0.11f)

        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        val pctP = tp(d * 0.31f, WHITE, BOLD)
        val nameP = tp(if (d < 30f) 9f else 10f, WHITE, MEDIUM)

        for (i in 0 until n) {
            val row = i / cols
            val inRow = if (row == rows - 1) n - row * cols else cols
            val rowX = pad + (availW - inRow * cellW) / 2f
            val cx = rowX + (i % cols) * cellW + cellW / 2f
            val y0 = top + gap + row * (cellH + gap)
            val cy = y0 + d / 2f
            val course = courses[i]
            val col = statusColor(course.percent)
            val rect = RectF(cx - d / 2 + stroke / 2, cy - d / 2 + stroke / 2, cx + d / 2 - stroke / 2, cy + d / 2 - stroke / 2)

            ring.color = 0x1FFFFFFF
            ring.maskFilter = null
            c.drawOval(rect, ring)
            val sweep = (course.percent.coerceIn(2.0, 100.0) * 3.6).toFloat()
            ring.color = alpha(col, 0x70)
            ring.maskFilter = BlurMaskFilter(max(2f, d * 0.07f), BlurMaskFilter.Blur.NORMAL)
            c.drawArc(rect, -90f, sweep, false, ring)
            ring.maskFilter = null
            ring.color = col
            c.drawArc(rect, -90f, sweep, false, ring)

            // 75% notch - sits at nine o'clock
            val notch = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFF141826.toInt() }
            val rr = d / 2 - stroke / 2
            c.drawRect(
                RectF(cx - rr - stroke / 2 - 0.5f, cy - 1f, cx - rr + stroke / 2 + 0.5f, cy + 1f),
                notch,
            )

            c.textC(course.percent.roundToInt().toString(), cx, cy - (pctP.ascent() + pctP.descent()) / 2f, pctP)
            c.textC(courseLabel(course), cx, y0 + d + 12f, nameP, cellW - 4f)
            c.textC(hint(course), cx, y0 + d + 23f, tp(8.5f, col, MEDIUM), cellW - 2f)
        }
    }

    private fun attendanceList(c: Canvas, courses: List<CourseItem>, w: Float, pad: Float, top: Float, rowH: Float) {
        val nameP = tp(11.5f, WHITE, MEDIUM)
        val pctP = tp(11.5f, WHITE, BOLD)
        val right = w - pad - 2f
        val hintW = 48f
        val pctRight = right - hintW - 6f
        val barX1 = pctRight - 34f
        val barX0 = pad + (w - pad * 2) * 0.46f
        val p = Paint(Paint.ANTI_ALIAS_FLAG)

        courses.forEachIndexed { i, course ->
            val cy = top + rowH * i + rowH / 2f
            val col = statusColor(course.percent)
            p.color = col
            c.drawCircle(pad + 5f, cy, 3f, p)
            val label = if (course.lab && !course.name.contains("lab", true)) "${course.name} Lab" else course.name
            c.textL(label, pad + 14f, cy - (nameP.ascent() + nameP.descent()) / 2f, nameP, barX0 - pad - 22f)

            p.color = 0x1FFFFFFF
            c.drawRoundRect(RectF(barX0, cy - 2.5f, barX1, cy + 2.5f), 2.5f, 2.5f, p)
            p.color = col
            val fill = barX0 + (barX1 - barX0) * (course.percent.coerceIn(3.0, 100.0) / 100.0).toFloat()
            c.drawRoundRect(RectF(barX0, cy - 2.5f, fill, cy + 2.5f), 2.5f, 2.5f, p)
            p.color = 0xE6FFFFFF.toInt()
            val tx = barX0 + (barX1 - barX0) * 0.75f
            c.drawRoundRect(RectF(tx - 0.8f, cy - 5f, tx + 0.8f, cy + 5f), 0.8f, 0.8f, p)

            c.textR("${course.percent.roundToInt()}%", pctRight, cy - (pctP.ascent() + pctP.descent()) / 2f, pctP)
            val hp = tp(9.5f, col, MEDIUM)
            c.textR(hint(course), right, cy - (hp.ascent() + hp.descent()) / 2f, hp)
        }
    }

    // ------------------------------------------------------------------
    // 4. Skip check (4x2) - timetable x attendance
    // ------------------------------------------------------------------

    fun skipCheck(snap: Snapshot?, w: Float, h: Float, density: Float, cal: Calendar): Bitmap {
        val (bmp, c) = begin(w, h, density)
        val accent = snap?.accent ?: DEFAULT_ACCENT
        card(c, w, h, accent)
        if (snap == null) {
            emptyState(c, w, h, accent, "Open VITAP Nexus once to see which classes are safe to skip.")
            return bmp
        }
        val pad = 16f
        val st = WidgetData.today(snap, cal)
        var list = st.upcoming
        var whenLabel = "TODAY"
        if (list.isEmpty()) {
            val next = WidgetData.nextDayWithClasses(snap, cal)
            if (next != null) {
                list = next.second
                whenLabel = dayLabel(cal, next.first).uppercase()
            }
        }
        c.textL("SKIP CHECK", pad, pad + 9f, tp(9.5f, accent, BOLD, 0.14f))
        c.textR(whenLabel, w - pad, pad + 9f, tp(8.5f, MUTED, BOLD, 0.16f))
        if (list.isEmpty()) {
            c.paragraph("Nothing on the timetable to skip.", pad, pad + 22f, w - pad * 2, tp(13f, SOFT, MEDIUM), 2)
            return bmp
        }

        val top = pad + 16f
        val avail = h - top - pad + 6f
        val count = min(list.size, max(1, (avail / 27f).toInt()))
        val rowH = min(36f, avail / count)
        val two = rowH >= 30f
        val bar = Paint(Paint.ANTI_ALIAS_FLAG)

        for (i in 0 until count) {
            val item = list[i]
            val y0 = top + rowH * i
            val cy = y0 + rowH / 2f
            val col = snap.colorFor(item.code)
            bar.color = col
            c.drawRoundRect(RectF(pad, y0 + 5f, pad + 3f, y0 + rowH - 5f), 1.5f, 1.5f, bar)

            // verdict
            val course = snap.courseFor(item)
            val verdict: String
            val vCol: Int
            var detail: String? = null
            if (course == null || course.total <= 0) {
                verdict = "NO DATA"
                vCol = MUTED
            } else {
                val after = course.attended * 100.0 / (course.total + 1)
                detail = "${course.percent.roundToInt()} → ${String.format(Locale.US, "%.1f", after)}%"
                if (after >= 75.0) {
                    verdict = "CAN SKIP"
                    vCol = if (after < 77.0) AMBER else GREEN
                } else {
                    verdict = "ATTEND"
                    vCol = RED
                }
            }
            val vp = tp(9f, vCol, BOLD, 0.08f)
            val pillW = vp.measureText(verdict) + 16f
            val pillX = w - pad - pillW
            c.pill(verdict, pillX, cy, vp, alpha(vCol, 0x2B), padH = 8f, height = 19f)
            var textRight = pillX - 8f
            if (detail != null && w >= 270f) {
                val dp = tp(9.5f, SOFT, REGULAR)
                val dw = c.textR(detail, textRight, cy - (dp.ascent() + dp.descent()) / 2f, dp)
                textRight -= dw + 8f
            }

            val tx = pad + 11f
            val nameP = tp(12.5f, WHITE, BOLD)
            if (two) {
                c.textL(WidgetData.fmtTime(item.start), tx, cy - 4f, tp(9.5f, col, MEDIUM), textRight - tx)
                c.textL(classTitle(item), tx, cy + 10.5f, nameP, textRight - tx)
            } else {
                val tpTime = tp(10f, col, MEDIUM)
                val base = cy - (nameP.ascent() + nameP.descent()) / 2f
                val tw = c.textL(WidgetData.fmtTime(item.start), tx, base, tpTime)
                c.textL(classTitle(item), tx + tw + 7f, base, nameP, textRight - tx - tw - 7f)
            }
        }
        return bmp
    }

    // ------------------------------------------------------------------
    // 5. Exam countdown (2x2)
    // ------------------------------------------------------------------

    fun exam(snap: Snapshot?, w: Float, h: Float, density: Float, cal: Calendar): Bitmap {
        val (bmp, c) = begin(w, h, density)
        val accent = snap?.accent ?: DEFAULT_ACCENT
        card(c, w, h, accent)
        if (snap == null) {
            emptyState(c, w, h, accent, "Open the app once to sync.")
            return bmp
        }
        val pad = if (h < 125f) 14f else 16f
        val day = cal.clone() as Calendar
        day.set(Calendar.HOUR_OF_DAY, 0); day.set(Calendar.MINUTE, 0)
        day.set(Calendar.SECOND, 0); day.set(Calendar.MILLISECOND, 0)
        val todayMs = day.timeInMillis
        val upcoming = snap.exams.filter { it.dayMillis >= todayMs }
        val next = upcoming.firstOrNull()

        c.textL(if (next == null) "EXAMS" else "NEXT EXAM", pad, pad + 9f, tp(9.5f, accent, BOLD, 0.14f))
        if (next == null) {
            c.paragraph("No exams in sight.", pad, pad + 22f, w - pad * 2, tp(15f, WHITE, BOLD), 2)
            c.textL("Enjoy the calm.", pad, h - pad, tp(10.5f, SOFT, REGULAR), w - pad * 2)
            return bmp
        }

        fun daysTo(e: ExamItem) = ((e.dayMillis - todayMs) / 86_400_000.0).roundToInt()
        val days = daysTo(next)
        val small = h < 125f
        val numSize = if (small) 36f else 46f
        val numBase = pad + 14f + numSize * 0.82f
        val word = when (days) {
            0 -> "Today"
            1 -> "Tomorrow"
            else -> null
        }
        val big = tp(if (word != null) numSize * 0.56f else numSize, WHITE, BLACK, -0.02f)
        big.shader = LinearGradient(
            0f, numBase - numSize * 0.8f, 0f, numBase,
            WHITE, alpha(accent, 0xFF), Shader.TileMode.CLAMP,
        )
        val nw = c.textL(word ?: days.toString(), pad, numBase, big, w - pad * 2)
        if (word == null) {
            val unit = tp(9f, SOFT, BOLD, 0.14f)
            c.textL("DAYS", pad + nw + 6f, numBase - 12f, unit)
            c.textL("LEFT", pad + nw + 6f, numBase - 1f, unit)
        }

        val nameP = tp(12.5f, WHITE, BOLD)
        val nameTop = numBase + 7f
        val nh = c.paragraph(next.name, pad, nameTop, w - pad * 2, nameP, if (h >= 165f) 2 else 1)
        val date = SimpleDateFormat("EEE d MMM", Locale.getDefault()).format(Date(next.dayMillis))
        val meta = listOfNotNull(date, next.time.takeIf { it.isNotBlank() && it != "-" }).joinToString("  ·  ")
        val metaBase = nameTop + nh + 12f
        val metaP = tp(10f, SOFT, REGULAR)
        c.textL(if (metaP.measureText(meta) > w - pad * 2) date else meta, pad, metaBase, metaP, w - pad * 2)

        val after = upcoming.getOrNull(1)
        if (after != null && h - pad - 1f > metaBase + 11f) {
            val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = alpha(accent, 0xFF) }
            c.drawCircle(pad + 2.5f, h - pad - 3.5f, 2.5f, dot)
            c.textL(
                "then ${WidgetData.acronym(after.name, after.code)} in ${daysTo(after)}d",
                pad + 10f, h - pad, tp(9.5f, MUTED, MEDIUM), w - pad * 2 - 10f,
            )
        }
        return bmp
    }
}
