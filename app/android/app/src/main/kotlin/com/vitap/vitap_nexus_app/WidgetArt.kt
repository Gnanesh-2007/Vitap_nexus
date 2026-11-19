package com.vitap.vitap_nexus_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import java.io.File

/** Character art for the widgets. Names: fight, peace, run, eye. */
interface WidgetArt {
    fun bitmap(name: String): Bitmap?

    /** Colour to tint every card with (null = each widget's own palette). */
    val tint: Int? get() = null

    /** 0 = solid cards, 1..100 = glass (higher = more see-through). */
    val glass: Int get() = 0
}

/** Adds a colour theme to any art source. */
class Themed(private val inner: WidgetArt, override val tint: Int?, override val glass: Int = 0) : WidgetArt {
    override fun bitmap(name: String): Bitmap? = inner.bitmap(name)
}

/** Production loader: PNGs shipped as Android drawables (res/drawable-nodpi). */
class ResArt(private val ctx: Context) : WidgetArt {
    private val cache = HashMap<String, Bitmap?>()

    @Synchronized
    override fun bitmap(name: String): Bitmap? = cache.getOrPut(name) {
        val id = ctx.resources.getIdentifier("widget_art_$name", "drawable", ctx.packageName)
        if (id == 0) {
            null
        } else {
            BitmapFactory.decodeResource(ctx.resources, id, BitmapFactory.Options().apply { inScaled = false })
        }
    }
}

/** Used when there is nothing to draw (and in tests that do not care about art). */
object NoArt : WidgetArt {
    override fun bitmap(name: String): Bitmap? = null
}

/**
 * The user's own picture (files/widget_art/custom.png, written by the app).
 * It is used for every pose, cut into a circle with a white ring like a sticker.
 */
class CustomArt(private val file: File) : WidgetArt {
    val stamp: Long = file.lastModified()

    /** Most colourful average of the picture, for the "match my picture" theme. */
    val dominant: Int? by lazy { sticker?.let { dominantColor(it) } }
    private val sticker: Bitmap? by lazy { load() }

    override fun bitmap(name: String): Bitmap? = sticker

    private fun load(): Bitmap? {
        if (!file.exists()) return null
        val src = BitmapFactory.decodeFile(file.path) ?: return null
        val d = 300
        val out = Bitmap.createBitmap(d, d, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val ring = 10f
        val r = d / 2f
        val p = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        c.drawCircle(r, r, r - ring, p)
        p.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        val side = minOf(src.width, src.height)
        val sx = (src.width - side) / 2
        val sy = (src.height - side) / 2
        c.drawBitmap(
            src,
            android.graphics.Rect(sx, sy, sx + side, sy + side),
            android.graphics.RectF(ring, ring, d - ring, d - ring),
            p,
        )
        p.xfermode = null
        p.style = Paint.Style.STROKE
        p.strokeWidth = ring
        p.color = 0xFFFFFFFF.toInt()
        c.drawCircle(r, r, r - ring / 2f, p)
        return out
    }
}

/** Average colour of the saturated, mid-bright pixels (so white rings and black outlines don't win). */
internal fun dominantColor(b: Bitmap): Int? {
    var r = 0L; var g = 0L; var bl = 0L; var n = 0L
    val hsv = FloatArray(3)
    val step = maxOf(1, b.width / 60)
    var y = 0
    while (y < b.height) {
        var x = 0
        while (x < b.width) {
            val px = b.getPixel(x, y)
            if ((px ushr 24) > 200) {
                android.graphics.Color.colorToHSV(px, hsv)
                if (hsv[1] > 0.35f && hsv[2] > 0.3f) {
                    r += (px shr 16) and 0xFF; g += (px shr 8) and 0xFF; bl += px and 0xFF; n++
                }
            }
            x += step
        }
        y += step
    }
    if (n < 5) return null
    return (0xFF shl 24) or ((r / n).toInt() shl 16) or ((g / n).toInt() shl 8) or (bl / n).toInt()
}
