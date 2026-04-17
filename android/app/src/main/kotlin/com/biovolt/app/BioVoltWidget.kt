package com.biovolt.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class BioVoltWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        private const val TAG = "BioVoltWidget"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            Log.d(TAG, "updateWidget called for id=$appWidgetId")

            try {
                val views = RemoteViews(
                    context.packageName,
                    R.layout.biovolt_widget
                )

                // ── Safe data read ─────────────────────────────────────
                // These are `var` (not `val`) because if getString() in
                // the try block succeeds for the first field but a later
                // getInt() throws, the catch reassigns — Kotlin's flow
                // analysis flags that correctly as a val reassignment.
                var fastingText: String
                var protocolText: String
                var windowStatus: String
                var dataSlot: String

                try {
                    val data = HomeWidgetPlugin.getData(context)
                    fastingText = data.getString(
                        "fasting_time", "--h --m") ?: "--h --m"
                    protocolText = data.getString(
                        "protocol_text", "No active protocols")
                        ?: "No active protocols"
                    dataSlot = data.getString("data_slot", "") ?: ""

                    // Eating window status
                    val eatStart = data.getInt("eat_window_start", -1)
                    val eatEnd = data.getInt("eat_window_end", -1)

                    windowStatus = if (eatStart >= 0 && eatEnd >= 0) {
                        val cal = java.util.Calendar.getInstance()
                        val currentMins = cal.get(
                            java.util.Calendar.HOUR_OF_DAY) * 60 +
                            cal.get(java.util.Calendar.MINUTE)
                        val inWindow = currentMins in
                            (eatStart * 60) until (eatEnd * 60)
                        if (inWindow) {
                            val h = if (eatEnd % 12 == 0) 12 else eatEnd % 12
                            val p = if (eatEnd < 12) "am" else "pm"
                            "EAT \u00B7 closes ${h}:00${p}"
                        } else {
                            val h = if (eatStart % 12 == 0) 12
                                else eatStart % 12
                            val p = if (eatStart < 12) "am" else "pm"
                            "FAST \u00B7 opens ${h}:00${p}"
                        }
                    } else ""

                } catch (e: Exception) {
                    // Data not yet written by Flutter — show defaults.
                    // This happens on first install before app opens.
                    Log.w(TAG, "Data read failed, showing defaults: ${e.message}")
                    fastingText = "Open app"
                    protocolText = "Tap to set up"
                    windowStatus = "BIOVOLT"
                    dataSlot = ""
                }

                // ── Set all text views safely ──────────────────────────
                try {
                    views.setTextViewText(
                        R.id.widget_fasting_time, fastingText)
                } catch (_: Exception) {}

                try {
                    views.setTextViewText(
                        R.id.widget_window_status, windowStatus)
                } catch (_: Exception) {}

                try {
                    views.setTextViewText(
                        R.id.widget_protocol, protocolText)
                } catch (_: Exception) {}

                try {
                    views.setTextViewText(
                        R.id.widget_data_slot, dataSlot)
                } catch (_: Exception) {}

                try {
                    views.setTextViewText(
                        R.id.widget_fasting_label,
                        if (fastingText == "Open app") "" else "FASTING")
                } catch (_: Exception) {}

                // ── Button intents ─────────────────────────────────────
                try {
                    val ateIntent = Intent(
                        context,
                        BioVoltWidgetReceiver::class.java
                    ).apply {
                        action = BioVoltWidgetReceiver.ACTION_I_ATE
                    }
                    val atePending = PendingIntent.getBroadcast(
                        context, 1, ateIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(
                        R.id.widget_btn_ate, atePending)
                } catch (_: Exception) {}

                try {
                    val openIntent = Intent(
                        context,
                        MainActivity::class.java
                    ).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val openPending = PendingIntent.getActivity(
                        context, 0, openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(
                        R.id.widget_btn_note, openPending)
                    views.setOnClickPendingIntent(
                        R.id.widget_btn_session, openPending)
                } catch (_: Exception) {}

                // ── Apply to widget ────────────────────────────────────
                Log.d(TAG, "Applying RemoteViews to widget $appWidgetId")
                appWidgetManager.updateAppWidget(appWidgetId, views)

            } catch (e: Exception) {
                // Last resort — apply minimal RemoteViews so widget
                // shows dark background with placeholder text instead
                // of the "Couldn't add widget" error.
                Log.e(TAG, "updateWidget outer failure, applying fallback", e)
                try {
                    val fallback = RemoteViews(
                        context.packageName,
                        R.layout.biovolt_widget
                    )
                    fallback.setTextViewText(
                        R.id.widget_fasting_time, "BIOVOLT")
                    fallback.setTextViewText(
                        R.id.widget_protocol, "Open app to sync")
                    appWidgetManager.updateAppWidget(appWidgetId, fallback)
                } catch (_: Exception) {
                    // Nothing more we can do.
                }
            }
        }
    }
}
