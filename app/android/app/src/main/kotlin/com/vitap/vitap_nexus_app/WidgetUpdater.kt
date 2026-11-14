package com.vitap.vitap_nexus_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

// ---------------------------------------------------------------------------
// Providers (one per widget type). They all just ask the updater to redraw.
// ---------------------------------------------------------------------------

abstract class NexusWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) =
        WidgetUpdater.updateAll(context)

    override fun onEnabled(context: Context) = WidgetUpdater.updateAll(context)

    override fun onAppWidgetOptionsChanged(context: Context, mgr: AppWidgetManager, id: Int, newOptions: Bundle?) =
        WidgetUpdater.updateAll(context)

    override fun onDisabled(context: Context) = WidgetUpdater.updateAll(context)
}

class TimetableWidget : NexusWidgetProvider()
class NextClassWidget : NexusWidgetProvider()
class AttendanceWidget : NexusWidgetProvider()
class SkipCheckWidget : NexusWidgetProvider()
class ExamWidget : NexusWidgetProvider()

/** Fires at class boundaries / midnight / after reboot so the widgets stay current. */
class WidgetTickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) = WidgetUpdater.updateAll(context)
}

// ---------------------------------------------------------------------------

object WidgetUpdater {
    private const val BOUNDARY_REQUEST = 7301
    private const val MARKER_REQUEST = 7302

    private class Spec(val cls: Class<*>, val defW: Float, val defH: Float)

    private val specs = listOf(
        Spec(TimetableWidget::class.java, 320f, 150f),
        Spec(NextClassWidget::class.java, 155f, 150f),
        Spec(AttendanceWidget::class.java, 320f, 150f),
        Spec(SkipCheckWidget::class.java, 320f, 150f),
        Spec(ExamWidget::class.java, 155f, 150f),
    )

    fun updateAll(ctx: Context) {
        val app = ctx.applicationContext
        val mgr = AppWidgetManager.getInstance(app)
        val snap = WidgetData.load(app)
        val density = app.resources.displayMetrics.density
        val landscape = app.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        var any = false

        for (spec in specs) {
            val ids = mgr.getAppWidgetIds(ComponentName(app, spec.cls))
            for (id in ids) {
                any = true
                try {
                    val o = mgr.getAppWidgetOptions(id)
                    val wDp = o.getInt(
                        if (landscape) AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH
                        else AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,
                    )
                    val hDp = o.getInt(
                        if (landscape) AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
                        else AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT,
                    )
                    val w = if (wDp > 0) wDp.toFloat() else spec.defW
                    val h = if (hDp > 0) hDp.toFloat() else spec.defH
                    mgr.updateAppWidget(id, build(app, spec.cls, snap, w, h, density))
                } catch (_: Exception) {
                    // A bad frame must never take the other widgets down with it.
                }
            }
        }
        if (any) scheduleTicks(app, snap) else cancelTicks(app)
    }

    private fun build(ctx: Context, cls: Class<*>, snap: Snapshot?, w: Float, h: Float, density: Float): RemoteViews {
        val cal = Calendar.getInstance()
        if (cls == NextClassWidget::class.java) {
            val frame = WidgetRender.nextClass(snap, w, h, density, cal)
            val v = RemoteViews(
                ctx.packageName,
                if (frame.compact) R.layout.widget_canvas_timer_compact else R.layout.widget_canvas_timer,
            )
            v.setImageViewBitmap(R.id.wc_image, frame.bitmap)
            if (frame.remainingMs != null) {
                v.setViewVisibility(R.id.wc_timer, View.VISIBLE)
                v.setChronometerCountDown(R.id.wc_timer, true)
                v.setChronometer(R.id.wc_timer, SystemClock.elapsedRealtime() + frame.remainingMs, null, true)
            } else {
                v.setViewVisibility(R.id.wc_timer, View.GONE)
            }
            v.setContentDescription(R.id.wc_image, "Next class")
            open(ctx)?.let { v.setOnClickPendingIntent(R.id.wc_root, it) }
            return v
        }

        val (bitmap, desc) = when (cls) {
            TimetableWidget::class.java -> WidgetRender.timeline(snap, w, h, density, cal) to "Today's timetable"
            AttendanceWidget::class.java -> WidgetRender.attendance(snap, w, h, density) to "Attendance by subject"
            SkipCheckWidget::class.java -> WidgetRender.skipCheck(snap, w, h, density, cal) to "Skip check"
            else -> WidgetRender.exam(snap, w, h, density, cal) to "Exam countdown"
        }
        val v = RemoteViews(ctx.packageName, R.layout.widget_canvas)
        v.setImageViewBitmap(R.id.wc_image, bitmap)
        v.setContentDescription(R.id.wc_image, desc)
        open(ctx)?.let { v.setOnClickPendingIntent(R.id.wc_root, it) }
        return v
    }

    private fun open(ctx: Context): PendingIntent? {
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return null
        return PendingIntent.getActivity(
            ctx, 0, launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    // ----- Alarm scheduling ------------------------------------------------

    private fun tick(ctx: Context, request: Int): PendingIntent =
        PendingIntent.getBroadcast(
            ctx, request, Intent(ctx, WidgetTickReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    private fun cancelTicks(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        am.cancel(tick(ctx, BOUNDARY_REQUEST))
        am.cancel(tick(ctx, MARKER_REQUEST))
    }

    /**
     * Two alarms: one that wakes at the next class start/end (or midnight) so
     * "now / next" is never wrong, and a cheap non-waking one every few minutes
     * during the college day to nudge the timeline marker and progress rings.
     */
    private fun scheduleTicks(ctx: Context, snap: Snapshot?) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val cal = Calendar.getInstance()
        val nowMs = cal.timeInMillis
        val nowSecs = cal.get(Calendar.HOUR_OF_DAY) * 3600 + cal.get(Calendar.MINUTE) * 60 + cal.get(Calendar.SECOND)

        var nextSecs = 24 * 3600 + 5
        var active = false
        if (snap != null) {
            val list = snap.days[WidgetData.dayIndex(cal)]
            for (c in list) {
                for (b in intArrayOf(c.start * 60, c.end * 60)) if (b > nowSecs && b < nextSecs) nextSecs = b
            }
            if (list.isNotEmpty()) {
                active = nowSecs >= list.first().start * 60 - 2 * 3600 && nowSecs < list.maxOf { it.end } * 60
            }
        }
        val boundaryMs = nowMs + (nextSecs - nowSecs).coerceAtLeast(20) * 1000L
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, boundaryMs, tick(ctx, BOUNDARY_REQUEST))

        if (active) {
            am.set(AlarmManager.RTC, nowMs + 4 * 60 * 1000L, tick(ctx, MARKER_REQUEST))
        } else {
            am.cancel(tick(ctx, MARKER_REQUEST))
        }
    }
}
