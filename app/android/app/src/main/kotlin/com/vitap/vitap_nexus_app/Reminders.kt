package com.vitap.vitap_nexus_app

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * Class and exam reminders. Everything is local: an alarm wakes the app shortly before each
 * reminder, a notification is posted, and the next alarm is set. Reminders are off until the
 * user turns them on in Profile → Reminders.
 */
object Reminders {
    private const val PREFS = "FlutterSharedPreferences"
    private const val FIRED = "nexus.reminders_last_fired"
    private const val CHANNEL = "nexus_reminders"
    private const val ALARM_REQUEST = 7311
    private const val RESCAN_MS = 6L * 60 * 60 * 1000

    fun settings(ctx: Context): ReminderSettings {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val minutes = try { p.getLong("flutter.reminders_class_min", 15L).toInt() } catch (_: ClassCastException) { 15 }
        return ReminderSettings(
            enabled = p.getBoolean("flutter.reminders_enabled", false),
            classMinutes = minutes,
            exams = p.getBoolean("flutter.reminders_exam", true),
        )
    }

    fun canNotify(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        return NotificationManagerCompat.from(ctx).areNotificationsEnabled()
    }

    private fun alarmIntent(ctx: Context): PendingIntent =
        PendingIntent.getBroadcast(
            ctx, ALARM_REQUEST, Intent(ctx, ReminderReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    /** Recomputes the plan and sets one alarm for the next reminder (or a later re-check). */
    fun reschedule(ctx: Context) {
        val app = ctx.applicationContext
        val am = app.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val cfg = settings(app)
        if (!cfg.enabled) {
            am.cancel(alarmIntent(app))
            return
        }
        val now = System.currentTimeMillis()
        val lastFired = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(FIRED, 0L)
        val next = ReminderPlanner.plan(WidgetData.load(app), cfg, now)
            .firstOrNull { it.timeMs > now + 5_000 && it.timeMs > lastFired }
        val at = minOf(next?.timeMs ?: Long.MAX_VALUE, now + RESCAN_MS)
        val pi = alarmIntent(app)
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
        try {
            if (exact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    /** Posts whatever is due now, then plans the next one. */
    fun fireDue(ctx: Context) {
        val app = ctx.applicationContext
        val cfg = settings(app)
        if (cfg.enabled && canNotify(app)) {
            val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val lastFired = prefs.getLong(FIRED, 0L)
            // Look back a few minutes so a slightly late alarm still delivers its reminder.
            val due = ReminderPlanner.plan(WidgetData.load(app), cfg, now - 10 * 60_000L)
                .filter { it.timeMs <= now + 20_000 && it.timeMs > lastFired && now < it.expiresMs }
            for (r in due) post(app, r.key.hashCode(), r.title, r.text)
            if (due.isNotEmpty()) prefs.edit().putLong(FIRED, due.maxOf { it.timeMs }).apply()
        }
        reschedule(app)
    }

    fun post(ctx: Context, id: Int, title: String, text: String) {
        if (!canNotify(ctx)) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Class and exam reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Heads-up before a class starts and around your exams"
                },
            )
        }
        val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.let {
            PendingIntent.getActivity(ctx, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        val n = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_nexus)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            NotificationManagerCompat.from(ctx).notify(id, n)
        } catch (_: SecurityException) {
        }
    }
}

/** Fires when a reminder is due, and after a reboot, a package update or a clock change. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> Reminders.reschedule(context)
            else -> Reminders.fireDue(context)
        }
    }
}
