package com.vitap.vitap_nexus_app

import android.content.Context
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

data class ClassItem(
    val name: String,
    val code: String,
    val venue: String,
    val start: Int, // minutes since midnight
    val end: Int,
    val lab: Boolean = false,
)

data class CourseItem(
    val name: String,
    val code: String,
    val percent: Double,
    val bunk: Int, // >0 can still miss, <0 must attend
    val attended: Int = 0,
    val total: Int = 0,
    val lab: Boolean = false,
)

data class ExamItem(
    val name: String,
    val code: String,
    val dayMillis: Long,
    val time: String,
    val venue: String,
    val type: String = "", // CAT1, CAT2, FAT...
    val session: String = "", // FN / AN
    val seatLocation: String = "",
    val seatNumber: String = "",
)

class Snapshot(
    val accent: Int,
    val days: List<List<ClassItem>>, // index 0 = Sunday
    val attPercent: Double?,
    val attAttended: Int,
    val attTotal: Int,
    val courses: List<CourseItem>,
    val exams: List<ExamItem>,
    val character: String = "naruto", // naruto | none | custom
    val glass: Int = 0, // 0 = solid, 1..100 = glass
    val tint: Int? = null, // ARGB, -1 = from the picture, null = each widget's own colours
) {
    /** One stable colour per course, shared by every widget. */
    private val colorByCode: Map<String, Int> by lazy {
        val codes = (days.flatten().map { it.code } + courses.map { it.code })
            .filter { it.isNotBlank() }.distinct().sorted()
        codes.withIndex().associate { (i, c) -> c to WidgetData.SUBJECT_COLORS[i % WidgetData.SUBJECT_COLORS.size] }
    }

    fun colorFor(code: String): Int = colorByCode[code] ?: accent

    /** Attendance entry for a timetable class (theory and lab are tracked separately). */
    fun courseFor(c: ClassItem): CourseItem? =
        courses.firstOrNull { it.code == c.code && it.lab == c.lab }
            ?: courses.firstOrNull { it.code == c.code }
}

/** What "today" looks like at a given moment. */
class DayState(
    val ongoing: ClassItem?,
    val upcoming: List<ClassItem>,
    val total: Int,
)

object WidgetData {
    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY = "flutter.nexus_widget_snapshot"
    private const val DEFAULT_ACCENT = 0xFF8FB4FF.toInt()

    val SUBJECT_COLORS = intArrayOf(
        0xFF7C9BFF.toInt(), 0xFF5EEAD4.toInt(), 0xFFFDBA74.toInt(), 0xFFF9A8D4.toInt(),
        0xFF86EFAC.toInt(), 0xFFC4B5FD.toInt(), 0xFFFCD34D.toInt(), 0xFF67E8F9.toInt(),
        0xFFFCA5A5.toInt(), 0xFFBEF264.toInt(),
    )

    fun isLab(type: String): Boolean {
        val t = type.trim().uppercase()
        return t == "ELA" || t == "LO" || t.contains("LAB") || t.contains("PRACTICAL")
    }

    private val STOP = setOf("AND", "OF", "FOR", "TO", "IN", "THE", "WITH", "A", "AN", "ON", "USING")

    /** "Data Structures and Algorithms" -> "DSA". Single-word names are kept as they are. */
    fun acronym(name: String, fallback: String): String {
        val words = name.split(Regex("[^A-Za-z0-9]+")).filter { it.isNotBlank() }
        val main = words.filter { it.uppercase() !in STOP }
        if (main.isEmpty()) return fallback.ifBlank { name }
        if (main.size == 1) return main[0]
        val sb = StringBuilder()
        for (w in main) {
            if (w.all { it.isDigit() } || w.matches(Regex("[IVX]+"))) sb.append(' ').append(w)
            else sb.append(w[0].uppercaseChar())
        }
        return sb.toString().trim().take(7)
    }

    fun load(ctx: Context): Snapshot? {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            ?: return null
        return try {
            parse(JSONObject(raw))
        } catch (_: Exception) {
            null
        }
    }

    private fun parse(o: JSONObject): Snapshot {
        val accentRaw = if (o.isNull("accent")) DEFAULT_ACCENT else o.optLong("accent").toInt()
        val daysObj = o.optJSONObject("days")
        val days = (0..6).map { i ->
            val arr = daysObj?.optJSONArray(i.toString())
            val list = ArrayList<ClassItem>()
            if (arr != null) {
                for (k in 0 until arr.length()) {
                    val c = arr.getJSONObject(k)
                    list.add(
                        ClassItem(
                            name = c.optString("n"),
                            code = c.optString("c"),
                            venue = c.optString("v"),
                            start = c.optInt("s"),
                            end = c.optInt("e"),
                            lab = isLab(c.optString("t")),
                        )
                    )
                }
            }
            mergeAdjacent(list.sortedBy { it.start })
        }

        val att = o.optJSONObject("att")
        val courses = ArrayList<CourseItem>()
        att?.optJSONArray("courses")?.let { arr ->
            for (k in 0 until arr.length()) {
                val c = arr.getJSONObject(k)
                courses.add(
                    CourseItem(
                        c.optString("n"),
                        c.optString("c"),
                        c.optDouble("p"),
                        c.optInt("b"),
                        c.optInt("a"),
                        c.optInt("t"),
                        isLab(c.optString("y")),
                    )
                )
            }
        }

        val exams = ArrayList<ExamItem>()
        o.optJSONArray("exams")?.let { arr ->
            for (k in 0 until arr.length()) {
                val e = arr.getJSONObject(k)
                exams.add(
                    ExamItem(
                        e.optString("n"),
                        e.optString("c"),
                        e.optLong("d"),
                        e.optString("t"),
                        e.optString("v"),
                        e.optString("x"),
                        e.optString("s"),
                        e.optString("l"),
                        e.optString("k"),
                    )
                )
            }
        }

        return Snapshot(
            accent = lighten(accentRaw),
            days = days,
            attPercent = if (att == null || att.isNull("p")) null else att.optDouble("p"),
            attAttended = att?.optInt("a") ?: 0,
            attTotal = att?.optInt("t") ?: 0,
            courses = courses,
            exams = exams,
            character = o.optString("char", "naruto"),
            glass = o.optInt("glass", 0),
            tint = if (o.isNull("tint")) null else o.optLong("tint").toInt(),
        )
    }

    /** Back-to-back slots of the same course (labs) read better as one block. */
    private fun mergeAdjacent(list: List<ClassItem>): List<ClassItem> {
        val out = ArrayList<ClassItem>()
        for (c in list) {
            val last = out.lastOrNull()
            if (last != null && last.code == c.code && last.venue == c.venue && last.lab == c.lab &&
                c.start - last.end in 0..10
            ) {
                out[out.size - 1] = last.copy(end = maxOf(last.end, c.end))
            } else {
                out.add(c)
            }
        }
        return out
    }

    /** Pull the accent towards white so it stays readable on the dark card. */
    private fun lighten(color: Int): Int {
        val t = 0.35f
        fun ch(shift: Int): Int {
            val v = (color shr shift) and 0xFF
            return (v + (255 - v) * t).toInt().coerceIn(0, 255)
        }
        return (0xFF shl 24) or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
    }

    fun minutesNow(cal: Calendar): Int = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

    fun dayIndex(cal: Calendar): Int = cal.get(Calendar.DAY_OF_WEEK) - 1

    fun today(snap: Snapshot, cal: Calendar): DayState {
        val list = snap.days[dayIndex(cal)]
        val now = minutesNow(cal)
        val ongoing = list.firstOrNull { it.start <= now && now < it.end }
        val upcoming = list.filter { it.start > now }
        return DayState(ongoing, upcoming, list.size)
    }

    /** First day after today (within a week) that has classes, with its list. */
    fun nextDayWithClasses(snap: Snapshot, cal: Calendar): Pair<Int, List<ClassItem>>? {
        val idx = dayIndex(cal)
        for (offset in 1..7) {
            val d = (idx + offset) % 7
            if (snap.days[d].isNotEmpty()) return offset to snap.days[d]
        }
        return null
    }

    fun fmtTime(mins: Int): String {
        val h = (mins / 60) % 24
        val m = mins % 60
        val h12 = if (h % 12 == 0) 12 else h % 12
        val suffix = if (h < 12) "am" else "pm"
        return String.format(Locale.US, "%d:%02d %s", h12, m, suffix)
    }

    fun fmtRange(c: ClassItem): String = "${fmtTime(c.start)} – ${fmtTime(c.end)}"

    fun fmtDuration(mins: Int): String {
        val m = mins.coerceAtLeast(0)
        return if (m >= 60) "${m / 60}h ${m % 60}m" else "${m}m"
    }

    fun dayName(index: Int): String =
        arrayOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")[index]
}
