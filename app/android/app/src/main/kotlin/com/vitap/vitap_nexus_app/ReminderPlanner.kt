package com.vitap.vitap_nexus_app

import java.util.Calendar
import java.util.Locale

/** What the user switched on in Profile → Reminders. */
data class ReminderSettings(
    val enabled: Boolean,
    val classMinutes: Int, // 0 = no class reminders
    val exams: Boolean,
)

class Reminder(
    val timeMs: Long,
    /** After this moment the reminder is pointless (the class has started, the exam has begun). */
    val expiresMs: Long,
    val key: String,
    val title: String,
    val text: String,
)

/** Works out which reminders should fire and when. Pure: no Android services, so it can be tested. */
object ReminderPlanner {
    const val HORIZON_MS = 36L * 60 * 60 * 1000
    private const val EXAM_EVENING_HOUR = 20
    private const val EXAM_MORNING_HOUR = 7
    private const val EXAM_MORNING_MINUTE = 30

    private fun midnight(base: Calendar, plusDays: Int): Calendar =
        (base.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, plusDays)
        }

    fun plan(snap: Snapshot?, settings: ReminderSettings, nowMs: Long, tz: java.util.TimeZone = java.util.TimeZone.getDefault()): List<Reminder> {
        if (snap == null || !settings.enabled) return emptyList()
        val out = ArrayList<Reminder>()
        val now = Calendar.getInstance(tz).apply { timeInMillis = nowMs }
        val limit = nowMs + HORIZON_MS

        if (settings.classMinutes > 0) {
            for (d in 0..2) {
                val day = midnight(now, d)
                val list = snap.days[day.get(Calendar.DAY_OF_WEEK) - 1]
                var prev: ClassItem? = null
                for (c in list) {
                    val startMs = day.timeInMillis + c.start * 60_000L
                    val at = startMs - settings.classMinutes * 60_000L
                    val inClassAlready = prev != null && day.timeInMillis + prev.end * 60_000L > at
                    prev = c
                    if (inClassAlready || at <= nowMs || at > limit) continue
                    val label = if (c.lab) "${c.name} (lab)" else c.name
                    val where = c.venue.takeIf { it.isNotBlank() }?.let { " in $it" } ?: ""
                    out.add(
                        Reminder(
                            timeMs = at,
                            expiresMs = startMs,
                            key = "c-${day.get(Calendar.DAY_OF_YEAR)}-${c.code}-${c.start}",
                            title = "$label starts in ${settings.classMinutes} min",
                            text = "${WidgetData.fmtTime(c.start)}$where",
                        ),
                    )
                }
            }
        }

        if (settings.exams) {
            for (e in snap.exams) {
                val examDay = Calendar.getInstance(tz).apply { timeInMillis = e.dayMillis }
                val detail = listOf(e.type, e.time, e.venue, e.seatLocation.takeIf { it.isNotBlank() }?.let { "Room $it" }, e.seatNumber.takeIf { it.isNotBlank() }?.let { "Seat $it" })
                    .filterNotNull().filter { it.isNotBlank() && it != "-" }.joinToString(" · ")

                val evening = (examDay.clone() as Calendar).apply {
                    add(Calendar.DAY_OF_YEAR, -1)
                    set(Calendar.HOUR_OF_DAY, EXAM_EVENING_HOUR); set(Calendar.MINUTE, 0)
                }
                val morning = (examDay.clone() as Calendar).apply {
                    set(Calendar.HOUR_OF_DAY, EXAM_MORNING_HOUR); set(Calendar.MINUTE, EXAM_MORNING_MINUTE)
                }
                val endOfExamDay = e.dayMillis + 23L * 60 * 60 * 1000
                if (evening.timeInMillis in (nowMs + 1)..limit) {
                    out.add(Reminder(evening.timeInMillis, endOfExamDay, "e-${e.code}-${e.dayMillis}-eve", "Exam tomorrow: ${e.name}", detail.ifBlank { "Good luck" }))
                }
                if (morning.timeInMillis in (nowMs + 1)..limit) {
                    out.add(Reminder(morning.timeInMillis, endOfExamDay, "e-${e.code}-${e.dayMillis}-am", "Exam today: ${e.name}", detail.ifBlank { "Good luck" }))
                }
            }
        }
        return out.sortedBy { it.timeMs }
    }

    fun describe(r: Reminder): String =
        String.format(Locale.US, "%d %s", r.timeMs, r.title)
}
