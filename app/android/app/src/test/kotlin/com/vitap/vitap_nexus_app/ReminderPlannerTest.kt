package com.vitap.vitap_nexus_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class ReminderPlannerTest {
    private val tz = TimeZone.getTimeZone("Asia/Kolkata")

    private fun at(y: Int, mo: Int, d: Int, h: Int, mi: Int): Long =
        Calendar.getInstance(tz).apply { clear(); set(y, mo - 1, d, h, mi, 0) }.timeInMillis

    private fun hhmm(ms: Long): String {
        val c = Calendar.getInstance(tz).apply { timeInMillis = ms }
        return String.format("%02d:%02d", c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
    }

    private fun cls(name: String, code: String, sh: Int, sm: Int, eh: Int, em: Int) =
        ClassItem(name, code, "AB1-201", sh * 60 + sm, eh * 60 + em)

    // 19 Nov 2026 is a Thursday (index 4).
    private fun snapshot(exams: List<ExamItem> = emptyList()): Snapshot {
        val thu = listOf(
            cls("Operating Systems", "CSE2005", 9, 0, 9, 50),
            cls("Databases", "CSE2004", 9, 55, 10, 45), // starts 5 min after the previous one ends
            cls("Statistics", "MAT2001", 14, 0, 14, 50),
        )
        val days = List(7) { if (it == 4) thu else emptyList() }
        return Snapshot(0xFF8FB4FF.toInt(), days, null, 0, 0, emptyList(), exams)
    }

    private val on15 = ReminderSettings(enabled = true, classMinutes = 15, exams = true)

    @Test
    fun remindsBeforeEachClassButNotWhileAlreadyInClass() {
        val plan = ReminderPlanner.plan(snapshot(), on15, at(2026, 11, 19, 8, 0), tz)
        // 08:45 for the first class. The 09:40 reminder for the second would arrive during the
        // first class, so it is skipped. 13:45 for the third.
        assertEquals(listOf("08:45", "13:45"), plan.map { hhmm(it.timeMs) })
        assertTrue(plan[0].title.contains("Operating Systems"))
        assertTrue(plan[0].title.contains("15 min"))
    }

    @Test
    fun nothingWhenTurnedOffOrNoClassReminders() {
        val now = at(2026, 11, 19, 8, 0)
        assertTrue(ReminderPlanner.plan(snapshot(), on15.copy(enabled = false), now, tz).isEmpty())
        assertTrue(ReminderPlanner.plan(snapshot(), on15.copy(classMinutes = 0, exams = false), now, tz).isEmpty())
        assertTrue(ReminderPlanner.plan(null, on15, now, tz).isEmpty())
    }

    @Test
    fun skipsRemindersThatAreAlreadyInThePast() {
        val plan = ReminderPlanner.plan(snapshot(), on15, at(2026, 11, 19, 13, 50), tz)
        assertTrue(plan.none { hhmm(it.timeMs) == "08:45" || hhmm(it.timeMs) == "13:45" })
    }

    @Test
    fun reminderExpiresWhenTheClassStarts() {
        val plan = ReminderPlanner.plan(snapshot(), on15, at(2026, 11, 19, 8, 0), tz)
        assertEquals("09:00", hhmm(plan[0].expiresMs))
    }

    @Test
    fun examGetsAnEveningAndAMorningReminder() {
        val examDay = at(2026, 11, 20, 0, 0)
        val exam = ExamItem("Operating Systems", "CSE2005", examDay, "09:30 - 11:00", "AB1", "FAT", "FN", "Room 304", "A-17")
        val plan = ReminderPlanner.plan(snapshot(listOf(exam)), on15.copy(classMinutes = 0), at(2026, 11, 19, 8, 0), tz)
        assertEquals(listOf("20:00", "07:30"), plan.map { hhmm(it.timeMs) })
        assertTrue(plan[0].title.startsWith("Exam tomorrow"))
        assertTrue(plan[1].title.startsWith("Exam today"))
        assertTrue(plan[0].text.contains("Seat A-17"))
    }

    @Test
    fun onlyLooksAboutAnAndAHalfDaysAhead() {
        val farExam = ExamItem("Far", "X1", at(2026, 12, 25, 0, 0), "", "", "FAT", "FN")
        val plan = ReminderPlanner.plan(snapshot(listOf(farExam)), on15.copy(classMinutes = 0), at(2026, 11, 19, 8, 0), tz)
        assertTrue(plan.isEmpty())
    }
}
