package com.vitap.vitap_nexus_app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.util.Calendar

/**
 * Renders every widget in many situations to PNG files so the designs can be
 * reviewed (and used as widget-picker previews) without a phone.
 * Output: <flutter project>/build/widget_previews
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], manifest = Config.NONE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WidgetRenderTest {
    private val out = File("../../build/widget_previews").apply { mkdirs() }
    private val density = 3f

    /** Same PNGs the app ships in res/drawable-nodpi. */
    private fun fileArt(prefix: String = "") = object : WidgetArt {
        private val dir = File("src/main/res/drawable-nodpi")
        private val cache = HashMap<String, Bitmap?>()
        override fun bitmap(name: String): Bitmap? = cache.getOrPut(name) {
            File(dir, "widget_art_$prefix$name.png").takeIf { it.exists() }?.let { BitmapFactory.decodeFile(it.path) }
        }
    }

    private val art = fileArt()

    private fun save(name: String, bmp: Bitmap) {
        File(out, "$name.png").outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    private fun at(hour: Int, minute: Int, dayOfWeek: Int = Calendar.THURSDAY): Calendar =
        Calendar.getInstance().apply {
            set(2026, Calendar.NOVEMBER, 12, hour, minute, 20)
            set(Calendar.DAY_OF_WEEK, dayOfWeek)
        }

    private fun sample(examsInDays: List<Pair<Int, String>> = listOf(9 to "CAT2", 12 to "FAT")): Snapshot {
        fun c(n: String, code: String, v: String, s: Int, e: Int, lab: Boolean = false) =
            ClassItem(n, code, v, s, e, lab)
        val thu = listOf(
            c("Data Structures and Algorithms", "CSE2001", "AB1-301", 9 * 60, 9 * 60 + 50),
            c("Operating Systems", "CSE2005", "AB1-204", 10 * 60, 10 * 60 + 50),
            c("Database Management Systems", "CSE2004", "CB-G12", 11 * 60, 11 * 60 + 50),
            c("Probability and Statistics", "MAT2001", "AB2-105", 14 * 60, 14 * 60 + 50),
            c("Operating Systems", "CSE2005", "LAB-4", 15 * 60, 16 * 60 + 40, lab = true),
        )
        val fri = listOf(
            c("Computer Networks", "CSE3003", "AB1-110", 8 * 60, 8 * 60 + 50),
            c("Database Management Systems", "CSE2004", "CB-G12", 10 * 60, 10 * 60 + 50),
            c("Technical English", "ENG1002", "AB2-301", 12 * 60, 12 * 60 + 50),
        )
        val days = listOf(emptyList(), thu, fri, thu, thu, fri, emptyList())
        fun k(n: String, code: String, a: Int, t: Int, lab: Boolean = false): CourseItem {
            val p = a * 100.0 / t
            val bunk = if (p >= 75) ((a - 0.75 * t) / 0.75).toInt() else -Math.ceil((0.75 * t - a) / 0.25).toInt()
            return CourseItem(n, code, p, bunk, a, t, lab)
        }
        val courses = listOf(
            k("Operating Systems", "CSE2005", 26, 38),
            k("Probability and Statistics", "MAT2001", 28, 38),
            k("Database Management Systems", "CSE2004", 29, 38),
            k("Data Structures and Algorithms", "CSE2001", 33, 40),
            k("Computer Networks", "CSE3003", 31, 36),
            k("Operating Systems", "CSE2005", 11, 12, lab = true),
            k("Technical English", "ENG1002", 22, 23),
        )
        val base = at(0, 0).apply { set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
        val names = listOf("Database Management Systems", "Operating Systems", "Statistics")
        val exams = examsInDays.mapIndexed { i, (d, type) ->
            ExamItem(names[i % names.size], "CSE200${i + 1}", base + d * 86_400_000L, "09:30 - 11:00", "AB1", type, "FN", "Room 304", "A-17")
        }
        return Snapshot(0xFF8FB4FF.toInt(), days, 80.0, 180, 225, courses, exams)
    }

    private fun allGood(s: Snapshot) = Snapshot(
        s.accent, s.days, 90.0, 200, 220,
        s.courses.map { it.copy(percent = 88.0, bunk = 4) }, s.exams,
    )

    @Test
    fun renderAll() {
        val s = sample()

        // Timetable: in class, running late, a long break, done, free day.
        save("timeline_inclass", WidgetRender.timeline(s, 330f, 150f, density, at(10, 25), art))
        save("timeline_run", WidgetRender.timeline(s, 330f, 150f, density, at(10, 55), art))
        save("timeline_free", WidgetRender.timeline(s, 330f, 150f, density, at(12, 40), art))
        save("timeline_done", WidgetRender.timeline(s, 330f, 150f, density, at(18, 5), art))
        save("timeline_sunday", WidgetRender.timeline(s, 330f, 150f, density, at(11, 0, Calendar.SUNDAY), art))
        save("timeline_min", WidgetRender.timeline(s, 250f, 110f, density, at(10, 25), art))
        save("timeline_null", WidgetRender.timeline(null, 330f, 150f, density, at(10, 25), art))

        // Next class.
        save("next_inclass", WidgetRender.nextClass(s, 155f, 150f, density, at(10, 25), art, previewTimer = "24:35").bitmap)
        save("next_soon", WidgetRender.nextClass(s, 155f, 150f, density, at(10, 55), art, previewTimer = "04:35").bitmap)
        save("next_wait", WidgetRender.nextClass(s, 155f, 150f, density, at(12, 40), art, previewTimer = "1:19:40").bitmap)
        save("next_done", WidgetRender.nextClass(s, 155f, 150f, density, at(18, 5), art).bitmap)
        save("next_min", WidgetRender.nextClass(s, 110f, 110f, density, at(10, 25), art, previewTimer = "24:35").bitmap)

        // Attendance.
        save("attendance", WidgetRender.attendance(s, 330f, 150f, density, art))
        save("attendance_good", WidgetRender.attendance(allGood(s), 330f, 150f, density, art))
        save("attendance_tall", WidgetRender.attendance(s, 330f, 250f, density, art))
        save("attendance_min", WidgetRender.attendance(s, 250f, 110f, density, art))

        // Skip check.
        save("skip", WidgetRender.skipCheck(s, 330f, 150f, density, at(9, 55), art))
        save("skip_min", WidgetRender.skipCheck(s, 250f, 110f, density, at(9, 55), art))

        // Exams: a few days away, tomorrow, today, none.
        save("exam", WidgetRender.exam(s, 155f, 150f, density, at(10, 25), art))
        save("exam_tomorrow", WidgetRender.exam(sample(listOf(1 to "FAT")), 155f, 150f, density, at(10, 25), art))
        save("exam_today", WidgetRender.exam(sample(listOf(0 to "FAT")), 155f, 150f, density, at(10, 25), art))
        save("exam_none", WidgetRender.exam(sample(emptyList()), 155f, 150f, density, at(10, 25), art))
        save("exam_wide", WidgetRender.exam(s, 330f, 150f, density, at(10, 25), art))
        save("exam_tall", WidgetRender.exam(sample(listOf(9 to "CAT2", 12 to "FAT", 15 to "FAT")), 330f, 250f, density, at(10, 25), art))
        save("exam_min", WidgetRender.exam(s, 110f, 110f, density, at(10, 25), art))

        // The other bundled characters.
        for (pack in listOf("ds", "tr")) {
            val a = fileArt("${pack}_")
            save("${pack}_timeline", WidgetRender.timeline(s, 330f, 150f, density, at(10, 25), a))
            save("${pack}_timeline_run", WidgetRender.timeline(s, 330f, 150f, density, at(10, 55), a))
            save("${pack}_next", WidgetRender.nextClass(s, 155f, 150f, density, at(10, 55), a, previewTimer = "04:35").bitmap)
            save("${pack}_exam", WidgetRender.exam(s, 155f, 150f, density, at(10, 25), a))
            save("${pack}_attendance", WidgetRender.attendance(s, 330f, 150f, density, a))
        }

        // A user-chosen picture (here a plain gradient standing in for any character).
        val pic = File(out, "_custom_src.png")
        Bitmap.createBitmap(300, 300, Bitmap.Config.ARGB_8888).also { b ->
            val cv = android.graphics.Canvas(b)
            cv.drawColor(0xFF22C55E.toInt())
            cv.drawCircle(150f, 130f, 70f, android.graphics.Paint().apply { color = 0xFFFFE0B2.toInt() })
        }.let { b -> pic.outputStream().use { b.compress(Bitmap.CompressFormat.PNG, 100, it) } }
        val mine = CustomArt(pic)
        save("custom_next", WidgetRender.nextClass(s, 155f, 150f, density, at(10, 25), mine, previewTimer = "24:35").bitmap)
        save("custom_timeline", WidgetRender.timeline(s, 330f, 150f, density, at(10, 25), mine))
        save("custom_exam", WidgetRender.exam(s, 155f, 150f, density, at(10, 25), mine))
        val orange = Themed(mine, 0xFFFF7A1A.toInt())
        val blue = Themed(mine, 0xFF2F6BFF.toInt())
        val auto = Themed(mine, mine.dominant)
        save("theme_orange", WidgetRender.timeline(s, 330f, 150f, density, at(10, 25), orange))
        save("theme_blue", WidgetRender.attendance(s, 330f, 150f, density, blue))
        save("theme_auto", WidgetRender.nextClass(s, 155f, 150f, density, at(10, 25), auto, previewTimer = "24:35").bitmap)
        save("theme_exam", WidgetRender.exam(s, 155f, 150f, density, at(10, 25), blue))
        // Glass over a bright wallpaper-like backdrop.
        fun onWall(name: String, bmp: Bitmap) {
            val bg = Bitmap.createBitmap(bmp.width + 40, bmp.height + 40, Bitmap.Config.ARGB_8888)
            val cv = android.graphics.Canvas(bg)
            cv.drawColor(0xFFF2D9A8.toInt())
            val pt = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
            pt.color = 0xFF4FA3E0.toInt(); cv.drawCircle(80f, 60f, 120f, pt)
            pt.color = 0xFFE86A8A.toInt(); cv.drawCircle(bg.width - 60f, bg.height - 40f, 150f, pt)
            cv.drawBitmap(bmp, 20f, 20f, null)
            save(name, bg)
        }
        onWall("glass_timeline", WidgetRender.timeline(s, 330f, 150f, density, at(10, 25), Themed(art, null, 45)))
        onWall("glass_next", WidgetRender.nextClass(s, 155f, 150f, density, at(10, 25), Themed(art, null, 45), previewTimer = "24:35").bitmap)
        onWall("glass_exam", WidgetRender.exam(s, 155f, 150f, density, at(10, 25), Themed(art, null, 80)))
        onWall("glass_attendance", WidgetRender.attendance(s, 330f, 150f, density, Themed(art, 0xFF2F6BFF.toInt(), 60)))
        save("none_exam", WidgetRender.exam(s, 155f, 150f, density, at(10, 25), NoArt))
        save("none_next", WidgetRender.nextClass(s, 155f, 150f, density, at(10, 25), NoArt, previewTimer = "24:35").bitmap)

        // Widget-picker previews (checked in under res/drawable-nodpi).
        val res = File("src/main/res/drawable-nodpi").apply { mkdirs() }
        fun preview(name: String, bmp: Bitmap) =
            File(res, "widget_preview_$name.png").outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        preview("timetable", WidgetRender.timeline(s, 330f, 150f, 2f, at(10, 25), art))
        preview("next_class", WidgetRender.nextClass(s, 155f, 150f, 2f, at(10, 25), art, previewTimer = "24:35").bitmap)
        preview("attendance", WidgetRender.attendance(s, 330f, 150f, 2f, art))
        preview("skip_check", WidgetRender.skipCheck(s, 330f, 150f, 2f, at(9, 55), art))
        preview("exam", WidgetRender.exam(s, 155f, 150f, 2f, at(10, 25), art))
    }
}
