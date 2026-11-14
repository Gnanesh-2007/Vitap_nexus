package com.vitap.vitap_nexus_app

import android.graphics.Bitmap
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.util.Calendar

/**
 * Renders every widget with sample data to PNG files so the designs can be
 * reviewed (and used as widget-picker previews) without a phone.
 * Output: <flutter project>/build/widget_previews
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], manifest = Config.NONE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WidgetRenderTest {
    private val out = File("../../build/widget_previews").apply { mkdirs() }
    private val density = 3f

    private fun save(name: String, bmp: Bitmap) {
        File(out, "$name.png").outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    private fun at(hour: Int, minute: Int, dayOfWeek: Int = Calendar.THURSDAY): Calendar =
        Calendar.getInstance().apply {
            set(2026, Calendar.NOVEMBER, 12, hour, minute, 20)
            set(Calendar.DAY_OF_WEEK, dayOfWeek)
        }

    private fun sample(): Snapshot {
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
        val exams = listOf(
            ExamItem("Database Management Systems", "CSE2004", base + 9 * 86_400_000L, "09:30 AM", "AB1"),
            ExamItem("Operating Systems", "CSE2005", base + 12 * 86_400_000L, "02:00 PM", "AB2"),
        )
        return Snapshot(0xFF8FB4FF.toInt(), days, 80.0, 180, 225, courses, exams)
    }

    @Test
    fun renderAll() {
        val s = sample()
        // Typical 4x2 / 2x2 sizes on a modern phone, plus the minimum sizes.
        save("timeline_now", WidgetRender.timeline(s, 330f, 150f, density, at(10, 25)))
        save("timeline_break", WidgetRender.timeline(s, 330f, 150f, density, at(12, 40)))
        save("timeline_done", WidgetRender.timeline(s, 330f, 150f, density, at(18, 5)))
        save("timeline_free", WidgetRender.timeline(s, 330f, 150f, density, at(11, 0, Calendar.SUNDAY)))
        save("timeline_min", WidgetRender.timeline(s, 250f, 110f, density, at(10, 25)))
        save("timeline_null", WidgetRender.timeline(null, 330f, 150f, density, at(10, 25)))

        save("next_now", WidgetRender.nextClass(s, 155f, 150f, density, at(10, 25)).bitmap)
        save("next_wait", WidgetRender.nextClass(s, 155f, 150f, density, at(13, 20)).bitmap)
        save("next_done", WidgetRender.nextClass(s, 155f, 150f, density, at(18, 5)).bitmap)
        save("next_min", WidgetRender.nextClass(s, 110f, 110f, density, at(10, 25)).bitmap)

        save("attendance", WidgetRender.attendance(s, 330f, 150f, density))
        save("attendance_min", WidgetRender.attendance(s, 250f, 110f, density))
        save("attendance_tall", WidgetRender.attendance(s, 330f, 250f, density))
        save("attendance_2x2", WidgetRender.attendance(s, 155f, 150f, density))

        save("skip", WidgetRender.skipCheck(s, 330f, 150f, density, at(9, 55)))
        save("skip_min", WidgetRender.skipCheck(s, 250f, 110f, density, at(9, 55)))
        save("skip_tomorrow", WidgetRender.skipCheck(s, 330f, 150f, density, at(18, 5)))

        save("exam", WidgetRender.exam(s, 155f, 150f, density, at(10, 25)))
        save("exam_min", WidgetRender.exam(s, 110f, 110f, density, at(10, 25)))

        // Widget-picker previews (checked in under res/drawable-nodpi).
        val res = File("src/main/res/drawable-nodpi").apply { mkdirs() }
        fun preview(name: String, bmp: Bitmap) =
            File(res, "widget_preview_$name.png").outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        preview("timetable", WidgetRender.timeline(s, 330f, 150f, 2f, at(10, 25)))
        preview("next_class", WidgetRender.nextClass(s, 155f, 150f, 2f, at(10, 25), previewTimer = "24:40").bitmap)
        preview("attendance", WidgetRender.attendance(s, 330f, 150f, 2f))
        preview("skip_check", WidgetRender.skipCheck(s, 330f, 150f, 2f, at(9, 55)))
        preview("exam", WidgetRender.exam(s, 155f, 150f, 2f, at(10, 25)))
        save("next_now", WidgetRender.nextClass(s, 155f, 150f, density, at(10, 25), previewTimer = "24:40").bitmap)
        save("next_min", WidgetRender.nextClass(s, 110f, 110f, density, at(10, 25), previewTimer = "24:40").bitmap)
    }
}
