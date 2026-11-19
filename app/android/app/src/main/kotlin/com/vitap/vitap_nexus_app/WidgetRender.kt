package com.vitap.vitap_nexus_app

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * The live countdown is a real Chronometer laid over the picture, so the seconds
 * tick without the app. These numbers (in dp / sp) tell the layout where to put it.
 */
class NextFrame(
    val bitmap: Bitmap,
    val remainingMs: Long?,
    val timerX: Float,
    val timerY: Float,
    val timerSp: Float,
)

/**
 * Draws every widget as a bitmap. Coordinates are in dp (the canvas is scaled by
 * the screen density), so layouts read like a design spec. Nothing here touches
 * a Context, which keeps it renderable in plain JVM tests: artwork comes in
 * through [WidgetArt].
 *
 * Personality rules: each widget has its own bold colour, labels are stickers,
 * and a character reacts to what is happening (in class, free, running late,
 * exam coming).
 */
object WidgetRender {
    private const val WHITE = 0xFFFFFFFF.toInt()
    private const val W80 = 0xCCFFFFFF.toInt()
    private const val W60 = 0x99FFFFFF.toInt()
    private const val W25 = 0x40FFFFFF
    private const val W14 = 0x24FFFFFF
    private const val INK = 0xFF1B1433.toInt()
    private const val GREEN = 0xFF4ADE80.toInt()
    private const val AMBER = 0xFFFFC53D.toInt()
    private const val ROSE = 0xFFFB7185.toInt()
    private const val MINT = 0xFF5EEAD4.toInt()

    private class Palette(val top: Int, val bottom: Int, val glass: Int = 0)

    /** The user's colour theme (if any) replaces the widget's own palette. */
    private fun themed(pal: Palette, art: WidgetArt): Palette {
        val t = art.tint ?: return Palette(pal.top, pal.bottom, art.glass)
        val hsv = FloatArray(3)
        android.graphics.Color.colorToHSV(t, hsv)
        val top = floatArrayOf(hsv[0], (hsv[1] * 0.95f).coerceIn(0.55f, 0.95f), 0.95f)
        val bottom = floatArrayOf(hsv[0], (hsv[1] * 0.95f).coerceIn(0.6f, 1f), 0.28f)
        return Palette(android.graphics.Color.HSVToColor(top), android.graphics.Color.HSVToColor(bottom), art.glass)
    }

    private val INDIGO = Palette(0xFF6D4DFF.toInt(), 0xFF281A82.toInt())
    private val SUNSET = Palette(0xFFFF9A1F.toInt(), 0xFFFF3D81.toInt())
    private val TEAL = Palette(0xFF15857A.toInt(), 0xFF0A2438.toInt())
    private val PLUM = Palette(0xFF4A2F9E.toInt(), 0xFF130E2B.toInt())
    private val CRIMSON = Palette(0xFFD02A3A.toInt(), 0xFF220610.toInt())

    private val BLACK: Typeface by lazy { Typeface.create("sans-serif-black", Typeface.NORMAL) }
    private val BOLD: Typeface by lazy { Typeface.create("sans-serif", Typeface.BOLD) }
    private val MEDIUM: Typeface by lazy { Typeface.create("sans-serif-medium", Typeface.NORMAL) }
    private val REGULAR: Typeface by lazy { Typeface.create("sans-serif", Typeface.NORMAL) }

    // ------------------------------------------------------------------
    // Toolkit
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

    /** Largest size (up to [size]) at which [text] still fits in [maxW]. */
    private fun fitSize(text: String, face: Typeface, size: Float, maxW: Float, spacing: Float = 0f): Float {
        val w = tp(size, WHITE, face, spacing).measureText(text)
        return if (w <= maxW || w == 0f) size else size * maxW / w
    }

    private fun tp(size: Float, color: Int, face: Typeface, spacing: Float = 0f) =
        TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            textSize = size
            this.color = color
            typeface = face
            letterSpacing = spacing
        }

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

    private fun Canvas.paragraph(s: String, x: Float, top: Float, width: Float, p: TextPaint, maxLines: Int): Float {
        val sl = StaticLayout.Builder.obtain(s, 0, s.length, p, max(1, width.toInt()))
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .setIncludePad(false)
            .setLineSpacing(0f, 0.95f)
            .build()
        save()
        translate(x, top)
        sl.draw(this)
        restore()
        return sl.height.toFloat()
    }

    /** The bold coloured card every widget sits on. */
    private fun card(c: Canvas, w: Float, h: Float, pal: Palette) {
        val r = min(30f, min(w, h) / 2f)
        val rect = RectF(0f, 0f, w, h)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        // Glass: the colours become translucent (wallpaper shows through), the bottom a bit
        // more solid so white text stays readable.
        val g = pal.glass.coerceIn(0, 100) / 100f
        val topA = if (g == 0f) 255 else (240 - 100 * g).toInt()
        val botA = if (g == 0f) 255 else (252 - 70 * g).toInt()
        p.shader = LinearGradient(0f, 0f, w * 0.7f, h, alpha(pal.top, topA), alpha(pal.bottom, botA), Shader.TileMode.CLAMP)
        c.drawRoundRect(rect, r, r, p)
        if (g > 0f) {
            // Glossy sheen across the upper half plus a bright rim, like a glass pane.
            c.save()
            c.clipPath(Path().apply { addRoundRect(rect, r, r, Path.Direction.CW) })
            p.shader = LinearGradient(0f, 0f, 0f, h * 0.62f, 0x66FFFFFF, 0x00FFFFFF, Shader.TileMode.CLAMP)
            val sheen = Path().apply {
                moveTo(0f, 0f); lineTo(w, 0f); lineTo(w, h * 0.30f)
                quadTo(w * 0.5f, h * 0.62f, 0f, h * 0.34f); close()
            }
            c.drawPath(sheen, p)
            c.restore()
            p.shader = null
            p.style = Paint.Style.STROKE
            p.strokeWidth = 2.2f
            p.color = 0x80FFFFFF.toInt()
            c.drawRoundRect(RectF(1.1f, 1.1f, w - 1.1f, h - 1.1f), r, r, p)
            p.style = Paint.Style.FILL
        }

        // Soft bubbles, clipped to the card: a little playfulness without gloss.
        c.save()
        c.clipPath(Path().apply { addRoundRect(rect, r, r, Path.Direction.CW) })
        p.shader = null
        p.color = 0x1FFFFFFF
        c.drawCircle(w * 0.96f, -h * 0.14f, h * 0.74f, p)
        p.color = 0x14FFFFFF
        c.drawCircle(w * 0.02f, h * 1.06f, h * 0.6f, p)
        p.color = 0x0EFFFFFF
        c.drawCircle(w * 0.64f, h * 1.18f, h * 0.4f, p)
        c.restore()

        p.style = Paint.Style.STROKE
        p.strokeWidth = 1.4f
        p.color = 0x40FFFFFF
        c.drawRoundRect(RectF(0.7f, 0.7f, w - 0.7f, h - 0.7f), r, r, p)
    }

    /** A little slightly-tilted label, like a sticker on a notebook. Returns its width. */
    private fun sticker(
        c: Canvas, text: String, x: Float, cy: Float, bg: Int, fg: Int,
        size: Float = 10f, rot: Float = -2.5f, maxW: Float = 10_000f,
    ): Float {
        val p = tp(size, fg, BLACK, 0.05f)
        val t = fit(text, p, maxW - 18f)
        val tw = p.measureText(t)
        val hh = size + 11f
        val box = RectF(x, cy - hh / 2, x + tw + 18f, cy + hh / 2)
        c.save()
        c.rotate(rot, x, cy)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = 0x38000000
        c.drawRoundRect(RectF(box.left, box.top + 1.8f, box.right, box.bottom + 1.8f), hh / 2, hh / 2, paint)
        paint.color = bg
        c.drawRoundRect(box, hh / 2, hh / 2, paint)
        c.drawText(t, x + 9f, cy - (p.ascent() + p.descent()) / 2f, p)
        c.restore()
        return tw + 18f
    }

    /** Height that keeps [bmp] no wider than [maxW] (the sprinting pose is much wider than the others). */
    private fun artHeight(bmp: Bitmap?, wanted: Float, maxW: Float): Float =
        if (bmp == null) 0f else min(wanted, maxW * bmp.height / bmp.width)

    /** Stands [bmp] with its bottom-right corner at (right, bottom). Returns the drawn width. */
    private fun art(c: Canvas, bmp: Bitmap?, right: Float, bottom: Float, height: Float): Float {
        if (bmp == null || height <= 0f) return 0f
        val w = height * bmp.width / bmp.height
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        val shadow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0x38000000
            maskFilter = BlurMaskFilter(3f, BlurMaskFilter.Blur.NORMAL)
        }
        c.drawOval(RectF(right - w * 0.92f, bottom - 3f, right - w * 0.08f, bottom + 5f), shadow)
        c.drawBitmap(bmp, null, RectF(right - w, bottom - height, right, bottom), paint)
        return w
    }

    /** A speech bubble whose tail points down at (right - 18, bottom + 7). */
    private fun bubble(c: Canvas, text: String, right: Float, bottom: Float, maxW: Float) {
        val p = tp(10.5f, INK, BLACK)
        val t = fit(text, p, maxW - 20f)
        val bw = p.measureText(t) + 20f
        val bh = 24f
        val box = RectF(right - bw, bottom - bh, right, bottom)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = 0x33000000
        c.drawRoundRect(RectF(box.left, box.top + 1.6f, box.right, box.bottom + 1.6f), 12f, 12f, paint)
        paint.color = WHITE
        c.drawRoundRect(box, 12f, 12f, paint)
        c.drawPath(
            Path().apply {
                moveTo(right - 26f, bottom - 1f)
                lineTo(right - 17f, bottom + 8f)
                lineTo(right - 11f, bottom - 1f)
                close()
            },
            paint,
        )
        c.drawText(t, box.left + 10f, box.centerY() - (p.ascent() + p.descent()) / 2f, p)
    }

    private fun emptyState(c: Canvas, w: Float, h: Float, art: Bitmap?, message: String) {
        val pad = 16f
        val artH = artHeight(art, min(h * 0.62f, 100f), w * 0.36f)
        val aw = art(c, art, w - pad + 4f, h - pad + 4f, artH)
        sticker(c, "VITAP NEXUS", pad, pad + 10f, AMBER, INK)
        c.paragraph(message, pad, pad + 32f, w - pad * 2 - aw - 4f, tp(15f, WHITE, BLACK), 4)
    }

    private fun statusColor(p: Double) = when {
        p < 75.0 -> ROSE
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
    // 1. Day timeline (4x2): indigo, the character reacts to your day
    // ------------------------------------------------------------------

    fun timeline(snap: Snapshot?, w: Float, h: Float, density: Float, cal: Calendar, art: WidgetArt): Bitmap {
        val (bmp, c) = begin(w, h, density)
        card(c, w, h, themed(INDIGO, art))
        if (snap == null) {
            emptyState(c, w, h, art.bitmap("peace"), "Open the app once and your whole day shows up here.")
            return bmp
        }

        val small = h < 125f
        val pad = if (small) 14f else 16f
        val now = WidgetData.minutesNow(cal)
        val st = WidgetData.today(snap, cal)
        val today = snap.days[WidgetData.dayIndex(cal)]
        val hero = st.ongoing ?: st.upcoming.firstOrNull()

        var track = today
        var live = true
        val tag: String
        val title: String
        var venue: String? = null
        val sub: String
        val mood: String
        val line: String

        if (hero != null) {
            val ongoing = st.ongoing != null
            val minsTo = if (ongoing) hero.end - now else hero.start - now
            tag = if (ongoing) "NOW" else "NEXT"
            title = classTitle(hero)
            venue = hero.venue.takeIf { it.isNotBlank() }
            sub = if (ongoing) "ends in ${WidgetData.fmtDuration(minsTo)}"
            else "in ${WidgetData.fmtDuration(minsTo)}  ·  ${WidgetData.fmtTime(hero.start)}"
            mood = when {
                ongoing -> "fight"
                minsTo <= 15 -> "run"
                else -> "peace"
            }
            line = when {
                ongoing -> "In the zone!"
                minsTo <= 15 -> "Hurry up!"
                else -> "Free till ${WidgetData.fmtTime(hero.start)}"
            }
        } else {
            val next = WidgetData.nextDayWithClasses(snap, cal)
            tag = if (st.total == 0) "FREE DAY" else "ALL DONE"
            title = if (st.total == 0) "No classes today" else "That's a wrap!"
            sub = next?.let { "${dayLabel(cal, it.first)} from ${WidgetData.fmtTime(it.second.first().start)}" }
                ?: SimpleDateFormat("EEEE d MMM", Locale.getDefault()).format(cal.time)
            mood = "peace"
            line = if (st.total == 0) "Sleep in!" else "Ramen time?"
            if (next != null) {
                track = next.second
                live = false
            }
        }

        val pic = art.bitmap(mood)
        val artH = artHeight(pic, min(h * 0.64f, 110f), w * 0.34f)
        val artBottom = h - pad + 5f
        val artW = if (pic != null) artH * pic.width / pic.height else 0f
        art(c, pic, w - pad + 6f, artBottom, artH)
        if (!small && pic != null) bubble(c, line, w - pad, artBottom - artH + 4f, 170f)

        val leftW = w - pad * 2 - artW * 0.8f - 6f

        // Row 1: the sticker and how long.
        val sw = sticker(c, tag, pad, pad + 10f, AMBER, INK, size = 10f)
        c.textL(sub, pad + sw + 9f, pad + 14f, tp(11f, W80, MEDIUM), leftW - sw - 9f)

        // Title.
        val titleTop = pad + 28f
        val th = c.paragraph(title, pad, titleTop, leftW, tp(if (small) 17f else 21f, WHITE, BLACK, -0.01f), if (h >= 140f) 2 else 1)

        // Where, and when.
        val stripTop = h - pad - 22f
        val cy = titleTop + th + 14f
        if (cy + 10f < stripTop - 4f && hero != null) {
            var sx = pad
            if (venue != null) sx += sticker(c, venue, pad, cy, W25, WHITE, size = 10f, rot = 0f, maxW = leftW * 0.55f) + 7f
            val p = tp(11f, W80, MEDIUM)
            c.textL(WidgetData.fmtRange(hero), sx, cy - (p.ascent() + p.descent()) / 2f, p, pad + leftW - sx)
        }

        // The strip stops short of the character so nothing is drawn through their feet.
        drawDayTrack(c, snap, track, live, now, pad, (w - pad - artW - 8f).coerceAtLeast(pad + 80f), stripTop, h - pad + 1f)
        return bmp
    }

    /** The whole day as one strip: a block per class, a marker for "now". */
    private fun drawDayTrack(
        c: Canvas, snap: Snapshot, list: List<ClassItem>, live: Boolean, now: Int,
        x0: Float, x1: Float, top: Float, labelBase: Float,
    ) {
        if (list.isEmpty() || x1 - x0 < 40f) return
        val trackH = 9f
        val startMin = (list.first().start / 60) * 60
        val endMin = ((list.maxOf { it.end } + 59) / 60) * 60
        val span = max(60, endMin - startMin).toFloat()
        fun x(m: Int) = x0 + (m - startMin) / span * (x1 - x0)

        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.color = W14
        c.drawRoundRect(RectF(x0, top, x1, top + trackH), trackH / 2, trackH / 2, p)

        for (item in list) {
            val col = snap.colorFor(item.code)
            val rect = RectF(x(item.start), top, max(x(item.start) + 3f, x(item.end) - 1.5f), top + trackH)
            val ongoing = live && item.start <= now && now < item.end
            val past = live && item.end <= now
            p.color = alpha(col, if (past) 0x55 else 0xFF)
            c.drawRoundRect(rect, 4.5f, 4.5f, p)
            if (ongoing) {
                p.style = Paint.Style.STROKE
                p.strokeWidth = 2f
                p.color = WHITE
                c.drawRoundRect(rect, 4.5f, 4.5f, p)
                p.style = Paint.Style.FILL
            }
        }

        val hours = (endMin - startMin) / 60
        val step = if (hours > 7) 2 else 1
        val hp = tp(8.5f, W60, MEDIUM)
        var m = startMin
        while (m <= endMin) {
            val h24 = (m / 60) % 24
            val txt = (if (h24 % 12 == 0) 12 else h24 % 12).toString()
            val tw = hp.measureText(txt)
            c.drawText(txt, (x(m) - tw / 2f).coerceIn(x0, x1 - tw), labelBase, hp)
            m += step * 60
        }

        if (live && now in startMin..endMin) {
            val nx = x(now)
            p.color = WHITE
            c.drawRoundRect(RectF(nx - 1.5f, top - 5f, nx + 1.5f, top + trackH + 5f), 1.5f, 1.5f, p)
            c.drawCircle(nx, top - 5f, 3.2f, p)
        }
    }

    // ------------------------------------------------------------------
    // 2. Next class (2x2): sunset, a giant live countdown
    // ------------------------------------------------------------------

    fun nextClass(
        snap: Snapshot?, w: Float, h: Float, density: Float, cal: Calendar, art: WidgetArt,
        previewTimer: String? = null, // only for static picker previews: the real one is a Chronometer
    ): NextFrame {
        val (bmp, c) = begin(w, h, density)
        card(c, w, h, themed(SUNSET, art))
        val s = min(w / 155f, h / 150f).coerceIn(0.8f, 1.5f)
        val pad = 14f * s

        if (snap == null) {
            emptyState(c, w, h, art.bitmap("peace"), "Open the app once to sync.")
            return NextFrame(bmp, null, 0f, 0f, 0f)
        }

        val st = WidgetData.today(snap, cal)
        val item = st.ongoing ?: st.upcoming.firstOrNull()

        if (item == null) {
            val next = WidgetData.nextDayWithClasses(snap, cal)
            sticker(c, if (st.total == 0) "FREE DAY" else "ALL DONE", pad, pad + 10f, WHITE, INK, size = 10f * s)
            c.paragraph(
                if (st.total == 0) "No class today!" else "Done for today!",
                pad, pad + 34f * s, w - pad * 2, tp(22f * s, WHITE, BLACK, -0.01f), 2,
            )
            val pic = art.bitmap("peace")
            val artH = artHeight(pic, min(h * 0.46f, 76f * s), w * 0.4f)
            val aw = art(c, pic, w - pad + 6f, h - pad + 6f, artH)
            next?.let {
                val room = w - pad * 2 - aw
                c.textL(dayLabel(cal, it.first), pad, h - pad - 17f * s, tp(11f * s, W80, MEDIUM), room)
                c.textL(WidgetData.fmtTime(it.second.first().start), pad, h - pad - 3f, tp(13f * s, WHITE, BLACK), room)
            }
            return NextFrame(bmp, null, 0f, 0f, 0f)
        }

        val ongoing = st.ongoing != null
        val nowSecs = secondsNow(cal)
        val targetSecs = (if (ongoing) item.end else item.start) * 60
        val remainingMs = (targetSecs - nowSecs).coerceAtLeast(0) * 1000L
        val minsTo = (targetSecs - nowSecs) / 60
        val mood = when {
            ongoing -> "fight"
            minsTo <= 15 -> "run"
            else -> "peace"
        }

        sticker(c, if (ongoing) "ENDS IN" else "STARTS IN", pad, pad + 10f * s, WHITE, 0xFFB4234A.toInt(), size = 9.5f * s)

        // Character top-right, clear of the countdown on the left.
        val pic = art.bitmap(mood)
        val artH = artHeight(pic, min(h * 0.34f, 50f * s), w * 0.3f)
        art(c, pic, w - pad + 4f, pad + artH + 2f, artH)

        // The Chronometer sits here; leave the space empty.
        val artBox = if (pic != null) artH * pic.width / pic.height else 0f
        val digits = if (remainingMs >= 3_600_000L) 7 else 5 // 1:19:40 vs 24:35
        var timerSp = 34f * s
        val room = w - pad * 2 - artBox - 6f
        while (timerSp > 18f && digits * timerSp * 0.6f > room) timerSp -= 1f
        val timerY = pad + 28f * s
        val nameTop = timerY + timerSp * 1.22f + 2f
        val nameW = w - pad * 2
        val nameP = tp(13.5f * s, WHITE, BLACK)
        val th = c.paragraph(classTitle(item), pad, nameTop, nameW, nameP, if (h >= 140f) 2 else 1)
        val base = nameTop + th + 12f * s
        if (base < h - 6f) {
            val where = listOfNotNull(
                item.venue.takeIf { it.isNotBlank() },
                if (ongoing) "to ${WidgetData.fmtTime(item.end)}" else WidgetData.fmtTime(item.start),
            ).joinToString("  ·  ")
            c.textL(where, pad, base, tp(10.5f * s, W80, MEDIUM), nameW)
        }
        if (previewTimer != null) {
            val tpTimer = tp(timerSp, WHITE, BLACK)
            c.drawText(previewTimer, pad, timerY + timerSp * 0.86f, tpTimer)
        }
        return NextFrame(bmp, remainingMs, pad, timerY, timerSp)
    }

    // ------------------------------------------------------------------
    // 3. Attendance: a ring per subject on deep teal
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

    fun attendance(snap: Snapshot?, w: Float, h: Float, density: Float, art: WidgetArt): Bitmap {
        val (bmp, c) = begin(w, h, density)
        card(c, w, h, themed(TEAL, art))
        val courses = snap?.courses.orEmpty()
        if (snap == null || courses.isEmpty()) {
            emptyState(c, w, h, art.bitmap("peace"), "Open the app once to load your attendance.")
            return bmp
        }

        val pad = 14f
        val header = h >= 138f
        val low = courses.count { it.percent < 75.0 }
        var top = pad - 2f

        if (header) {
            val pic = art.bitmap(if (low > 0) "fight" else "peace")
            val artH = artHeight(pic, 42f, 60f)
            val aw = art(c, pic, w - pad + 4f, pad + artH + 4f, artH)
            val sw = sticker(c, "ATTENDANCE", pad, pad + 11f, MINT, 0xFF053B36.toInt(), size = 10f)
            if (w >= 230f) {
                val label = if (low > 0) "$low below 75%" else "all above 75%"
                val col = if (low > 0) ROSE else GREEN
                val tp = tp(10.5f, col, BLACK, 0.04f)
                val tw = tp.measureText(label)
                val px = w - pad - aw - tw - 22f
                if (px > pad + sw + 8f) {
                    val box = RectF(px, pad + 1f, px + tw + 18f, pad + 21f)
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = alpha(col, 0x2E) }
                    c.drawRoundRect(box, 10f, 10f, paint)
                    c.drawText(label, px + 9f, box.centerY() - (tp.ascent() + tp.descent()) / 2f, tp)
                }
            }
            top = if (h >= 200f) pad + 48f else pad + 26f
        }

        val listRow = (h - top - pad + 4f) / courses.size
        if (h >= 200f && listRow >= 17f && w >= 220f) {
            attendanceList(c, courses, w, pad, top, min(28f, listRow))
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
        val d = bestD.coerceIn(18f, 60f)
        val rows = bestRows
        val cols = ceil(n / rows.toFloat()).toInt()
        val cellW = availW / cols
        val cellH = d + textH
        val gap = ((availH - rows * cellH) / (rows + 1)).coerceAtLeast(0f)
        val stroke = max(4f, d * 0.15f)

        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        val pctP = tp(d * 0.32f, WHITE, BLACK)
        val nameP = tp(if (d < 30f) 9f else 10f, WHITE, BOLD)

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

            ring.color = W25
            c.drawOval(rect, ring)
            ring.color = col
            c.drawArc(rect, -90f, (course.percent.coerceIn(2.0, 100.0) * 3.6).toFloat(), false, ring)

            c.textC(course.percent.roundToInt().toString(), cx, cy - (pctP.ascent() + pctP.descent()) / 2f, pctP)
            c.textC(courseLabel(course), cx, y0 + d + 12f, nameP, cellW - 4f)
            c.textC(hint(course), cx, y0 + d + 23f, tp(8.5f, col, BLACK), cellW - 2f)
        }
    }

    private fun attendanceList(c: Canvas, courses: List<CourseItem>, w: Float, pad: Float, top: Float, rowH: Float) {
        val nameP = tp(11.5f, WHITE, BOLD)
        val pctP = tp(11.5f, WHITE, BLACK)
        val right = w - pad - 2f
        val hintW = 50f
        val pctRight = right - hintW - 6f
        val barX1 = pctRight - 34f
        val barX0 = pad + (w - pad * 2) * 0.46f
        val p = Paint(Paint.ANTI_ALIAS_FLAG)

        courses.forEachIndexed { i, course ->
            val cy = top + rowH * i + rowH / 2f
            val col = statusColor(course.percent)
            p.color = col
            c.drawCircle(pad + 5f, cy, 3.4f, p)
            val label = if (course.lab && !course.name.contains("lab", true)) "${course.name} Lab" else course.name
            c.textL(label, pad + 14f, cy - (nameP.ascent() + nameP.descent()) / 2f, nameP, barX0 - pad - 22f)

            p.color = W25
            c.drawRoundRect(RectF(barX0, cy - 3f, barX1, cy + 3f), 3f, 3f, p)
            p.color = col
            val fill = barX0 + (barX1 - barX0) * (course.percent.coerceIn(3.0, 100.0) / 100.0).toFloat()
            c.drawRoundRect(RectF(barX0, cy - 3f, fill, cy + 3f), 3f, 3f, p)
            p.color = WHITE
            val tx = barX0 + (barX1 - barX0) * 0.75f
            c.drawRoundRect(RectF(tx - 0.8f, cy - 5.5f, tx + 0.8f, cy + 5.5f), 0.8f, 0.8f, p)

            c.textR("${course.percent.roundToInt()}%", pctRight, cy - (pctP.ascent() + pctP.descent()) / 2f, pctP)
            val hp = tp(9.5f, col, BLACK)
            c.textR(hint(course), right, cy - (hp.ascent() + hp.descent()) / 2f, hp)
        }
    }

    // ------------------------------------------------------------------
    // 4. Skip check (4x2): plum, a verdict per class
    // ------------------------------------------------------------------

    fun skipCheck(snap: Snapshot?, w: Float, h: Float, density: Float, cal: Calendar, art: WidgetArt): Bitmap {
        val (bmp, c) = begin(w, h, density)
        card(c, w, h, themed(PLUM, art))
        if (snap == null) {
            emptyState(c, w, h, art.bitmap("peace"), "Open the app once to see which classes are safe to skip.")
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
        val pic = art.bitmap("peace")
        val artH = artHeight(pic, 34f, 50f)
        val aw = art(c, pic, w - pad + 4f, pad + artH + 1f, artH)
        sticker(c, "SKIP CHECK", pad, pad + 10f, AMBER, INK, size = 10f)
        c.textR(whenLabel, w - pad - aw - 8f, pad + 14f, tp(9f, W60, BLACK, 0.12f))
        if (list.isEmpty()) {
            c.paragraph("Nothing on the timetable to skip.", pad, pad + 36f, w - pad * 2 - aw, tp(14f, WHITE, BLACK), 2)
            return bmp
        }

        val top = pad + 34f
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
            c.drawRoundRect(RectF(pad, y0 + 5f, pad + 4f, y0 + rowH - 5f), 2f, 2f, bar)

            val course = snap.courseFor(item)
            val verdict: String
            val vBg: Int
            var detail: String? = null
            if (course == null || course.total <= 0) {
                verdict = "NO DATA"
                vBg = W25
            } else {
                val after = course.attended * 100.0 / (course.total + 1)
                detail = "${course.percent.roundToInt()} → ${String.format(Locale.US, "%.1f", after)}%"
                if (after >= 75.0) {
                    verdict = "CAN SKIP"
                    vBg = if (after < 77.0) AMBER else GREEN
                } else {
                    verdict = "ATTEND"
                    vBg = ROSE
                }
            }
            val vp = tp(9f, if (vBg == W25) WHITE else INK, BLACK, 0.06f)
            val pillW = vp.measureText(verdict) + 18f
            val pillX = w - pad - pillW
            bar.color = vBg
            c.drawRoundRect(RectF(pillX, cy - 10f, pillX + pillW, cy + 10f), 10f, 10f, bar)
            c.drawText(verdict, pillX + 9f, cy - (vp.ascent() + vp.descent()) / 2f, vp)
            var textRight = pillX - 8f
            if (detail != null && w >= 270f) {
                val dp = tp(9.5f, W80, MEDIUM)
                val dw = c.textR(detail, textRight, cy - (dp.ascent() + dp.descent()) / 2f, dp)
                textRight -= dw + 8f
            }

            val tx = pad + 12f
            val nameP = tp(12.5f, WHITE, BLACK)
            if (two) {
                c.textL(WidgetData.fmtTime(item.start), tx, cy - 4f, tp(9.5f, alpha(col, 0xFF), BLACK), textRight - tx)
                c.textL(classTitle(item), tx, cy + 10.5f, nameP, textRight - tx)
            } else {
                val tpTime = tp(10f, alpha(col, 0xFF), BLACK)
                val base = cy - (nameP.ascent() + nameP.descent()) / 2f
                val tw = c.textL(WidgetData.fmtTime(item.start), tx, base, tpTime)
                c.textL(classTitle(item), tx + tw + 7f, base, nameP, textRight - tx - tw - 7f)
            }
        }
        return bmp
    }

    // ------------------------------------------------------------------
    // 5. Exam countdown (2x2): crimson, the Sharingan is watching
    // ------------------------------------------------------------------

    fun exam(snap: Snapshot?, w: Float, h: Float, density: Float, cal: Calendar, art: WidgetArt): Bitmap {
        val (bmp, c) = begin(w, h, density)
        card(c, w, h, themed(CRIMSON, art))
        val s = min(w / 155f, h / 150f).coerceIn(0.8f, 1.5f)
        val pad = 14f * s
        if (snap == null) {
            emptyState(c, w, h, art.bitmap("peace"), "Open the app once to sync your exams.")
            return bmp
        }

        val day = cal.clone() as Calendar
        day.set(Calendar.HOUR_OF_DAY, 0); day.set(Calendar.MINUTE, 0)
        day.set(Calendar.SECOND, 0); day.set(Calendar.MILLISECOND, 0)
        val todayMs = day.timeInMillis
        val upcoming = snap.exams.filter { it.dayMillis >= todayMs }
        val next = upcoming.firstOrNull()

        if (next == null) {
            sticker(c, "EXAMS", pad, pad + 10f, AMBER, INK, size = 10f * s)
            val pic = art.bitmap("peace")
            val artH = artHeight(pic, min(h * 0.46f, 76f * s), w * 0.4f)
            val aw = art(c, pic, w - pad + 6f, h - pad + 6f, artH)
            c.paragraph("No exams in sight!", pad, pad + 34f * s, w - pad * 2, tp(22f * s, WHITE, BLACK, -0.01f), 2)
            c.textL("Go relax.", pad, h - pad - 4f, tp(11.5f * s, W80, MEDIUM), w - pad * 2 - aw)
            return bmp
        }

        if (w >= 230f || h >= 240f) {
            examList(c, w, h, s, pad, upcoming, todayMs, art)
            return bmp
        }

        // The Sharingan, big and half out of the top-right corner, behind the number.
        val days = ((next.dayMillis - todayMs) / 86_400_000.0).roundToInt()
        c.save()
        c.clipPath(Path().apply { addRoundRect(RectF(0f, 0f, w, h), 30f, 30f, Path.Direction.CW) })
        val eye = art.bitmap("eye")
        if (eye != null) {
            val r = min(w, h) * (if (days >= 2) 0.36f else 0.3f)
            val cx = w - r * 0.5f
            val cy = r * 0.72f
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { this.alpha = 235 }
            c.drawBitmap(eye, null, RectF(cx - r, cy - r, cx + r, cy + r), paint)
        }
        c.restore()

        val typeText = when {
            next.type.isBlank() -> "NEXT EXAM"
            else -> next.type.uppercase(Locale.ROOT).replace(Regex("^(CAT|FAT)(\\d)"), "$1 $2")
        }
        sticker(c, typeText, pad, pad + 10f * s, AMBER, INK, size = 10f * s, maxW = w - pad * 2)

        val label = when (days) {
            0 -> "TODAY"
            1 -> "TOMORROW"
            else -> days.toString()
        }
        val numSize = fitSize(label, BLACK, if (days <= 1) 28f * s else 54f * s, w - pad * 2, -0.02f)
        val numBase = pad + 26f * s + numSize * 0.9f
        val numP = tp(numSize, WHITE, BLACK, -0.02f)
        val nw = c.textL(label, pad, numBase, numP, w - pad * 2)
        if (days >= 2) {
            val u = tp(10f * s, W80, BLACK, 0.14f)
            c.drawText("DAYS", pad + nw + 6f, numBase - 17f * s, u)
            c.drawText("TO GO", pad + nw + 6f, numBase - 5f * s, u)
        } else if (days == 0) {
            c.textL("Good luck!", pad, numBase + 14f * s, tp(11.5f * s, W80, BLACK), w - pad * 2)
        }

        val nameTop = numBase + (if (days == 0) 24f else 14f) * s
        val textW = w - pad * 2
        val nh = c.paragraph(next.name, pad, nameTop, textW, tp(12.5f * s, WHITE, BLACK), if (h >= 138f) 2 else 1)
        val date = SimpleDateFormat("EEE d MMM", Locale.getDefault()).format(Date(next.dayMillis))
        val meta = listOfNotNull(date, next.time.takeIf { it.isNotBlank() && it != "-" }).joinToString("  ·  ")
        val metaBase = nameTop + nh + 12f * s
        if (metaBase < h - 4f) c.textL(meta, pad, metaBase, tp(10.5f * s, W80, MEDIUM), textW)
        val extra = listOf(next.venue, next.seatLocation, seatText(next)).filter { it.isNotBlank() && it != "-" }.joinToString("  ·  ")
        val extraBase = metaBase + 13f * s
        if (extra.isNotEmpty() && extraBase < h - 4f) c.textL(extra, pad, extraBase, tp(10f * s, W80, MEDIUM), textW)
        return bmp
    }

    private fun seatText(e: ExamItem) = if (e.seatNumber.isBlank() || e.seatNumber == "-") "" else "Seat ${e.seatNumber}"

    /** Wide / tall exam widget: every upcoming exam with its full details. */
    private fun examList(
        c: Canvas, w: Float, h: Float, s: Float, pad: Float,
        upcoming: List<ExamItem>, todayMs: Long, art: WidgetArt,
    ) {
        sticker(c, "EXAM SCHEDULE", pad, pad + 10f * s, AMBER, INK, size = 10f * s, maxW = w - pad * 2)
        val eye = art.bitmap("eye")
        if (eye != null) {
            c.save()
            c.clipPath(Path().apply { addRoundRect(RectF(0f, 0f, w, h), 30f, 30f, Path.Direction.CW) })
            val r = 34f * s
            c.drawBitmap(eye, null, RectF(w - r * 1.3f, -r * 0.3f, w - r * 1.3f + r * 2, r * 1.7f),
                Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { alpha = 220 })
            c.restore()
        }
        val rowH = 46f * s
        var y = pad + 30f * s
        val fmt = SimpleDateFormat("EEE d MMM", Locale.getDefault())
        val maxRows = ((h - y - pad * 0.5f) / rowH).toInt().coerceAtLeast(1)
        for (e in upcoming.take(maxRows)) {
            val days = ((e.dayMillis - todayMs) / 86_400_000.0).roundToInt()
            val bw = 46f * s
            val bh = rowH - 8f * s
            c.drawRoundRect(RectF(pad, y, pad + bw, y + bh), 12f, 12f,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = alpha(WHITE, 38) })
            val big = if (days <= 0) "NOW" else days.toString()
            val small = if (days <= 0) "TODAY" else if (days == 1) "DAY" else "DAYS"
            val bigSize = fitSize(big, BLACK, 17f * s, bw - 8f * s)
            val cx = pad + bw / 2f
            val bigP = tp(bigSize, WHITE, BLACK).apply { textAlign = Paint.Align.CENTER }
            val smP = tp(7.5f * s, W80, BLACK, 0.1f).apply { textAlign = Paint.Align.CENTER }
            c.drawText(big, cx, y + bh * 0.52f, bigP)
            c.drawText(small, cx, y + bh * 0.52f + 9f * s, smP)
            val tx = pad + bw + 10f * s
            val tw = w - tx - pad
            val type = e.type.uppercase(Locale.ROOT).replace(Regex("^(CAT|FAT)(\\d)"), "$1 $2")
            val title = if (type.isNotBlank()) "${e.name}" else e.name
            c.textL(title, tx, y + 11f * s, tp(12f * s, WHITE, BLACK), tw)
            val sub = listOf(type, fmt.format(Date(e.dayMillis)), e.time, e.session)
                .filter { it.isNotBlank() && it != "-" }.joinToString(" · ")
            c.textL(sub, tx, y + 23f * s, tp(9.5f * s, W80, MEDIUM), tw)
            val where = listOf(e.venue, e.seatLocation, seatText(e))
                .filter { it.isNotBlank() && it != "-" }.joinToString(" · ")
            if (where.isNotEmpty()) c.textL(where, tx, y + 34f * s, tp(9.5f * s, AMBER, BLACK), tw)
            y += rowH
        }
    }
}
