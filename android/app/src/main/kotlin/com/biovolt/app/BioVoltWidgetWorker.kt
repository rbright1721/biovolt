package com.biovolt.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Calendar

/**
 * Periodic background worker that keeps the home-screen widget current
 * without requiring the Flutter app to be open.
 *
 * Runs at ~15-minute intervals (Android may batch longer under Doze).
 * Recomputes the fasting timer from the stored `last_meal_epoch_ms`
 * and the eat-window status from `eat_window_start`/`eat_window_end`,
 * then triggers a RemoteViews redraw on every installed widget
 * instance.
 */
class BioVoltWidgetWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    override fun doWork(): Result {
        return try {
            refreshWidget()
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    private fun refreshWidget() {
        val data = HomeWidgetPlugin.getData(context)

        // ── Recompute fasting time from stored epoch ─────────────────
        val lastMealEpoch = data.getLong("last_meal_epoch_ms", -1L)
        if (lastMealEpoch > 0) {
            val elapsedMs = System.currentTimeMillis() - lastMealEpoch
            val hours = (elapsedMs / 3600000).toInt()
            val minutes = ((elapsedMs % 3600000) / 60000).toInt()
            val fastingText =
                "${hours}h ${minutes.toString().padStart(2, '0')}m"
            data.edit()
                .putString("fasting_time", fastingText)
                .apply()
        }

        // ── Recompute eating window status ───────────────────────────
        val eatStart = data.getInt("eat_window_start", -1)
        val eatEnd = data.getInt("eat_window_end", -1)
        if (eatStart in 0..23 && eatEnd in 0..24) {
            val now = Calendar.getInstance()
            val currentMins = now.get(Calendar.HOUR_OF_DAY) * 60 +
                    now.get(Calendar.MINUTE)
            val startMins = eatStart * 60
            val endMins = eatEnd * 60
            val inWindow = currentMins in startMins until endMins

            val status = if (inWindow) {
                val h = if (eatEnd % 12 == 0) 12 else eatEnd % 12
                val p = if (eatEnd < 12 || eatEnd == 24) "am" else "pm"
                "EAT \u00B7 closes ${h}:00${p}"
            } else {
                val h = if (eatStart % 12 == 0) 12 else eatStart % 12
                val p = if (eatStart < 12) "am" else "pm"
                "FAST \u00B7 opens ${h}:00${p}"
            }
            data.edit().putString("window_status_computed", status).apply()
        }

        // ── Trigger widget redraw ────────────────────────────────────
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, BioVoltWidget::class.java)
        )
        for (id in ids) {
            BioVoltWidget.updateWidget(context, manager, id)
        }
    }
}
