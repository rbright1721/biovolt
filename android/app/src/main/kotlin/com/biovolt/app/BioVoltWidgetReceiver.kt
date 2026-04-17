package com.biovolt.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin

class BioVoltWidgetReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_I_ATE -> {
                // Save current timestamp to home_widget shared prefs.
                // Flutter reads this on next widget update and syncs
                // it back into Hive via WidgetService.updateWidget().
                HomeWidgetPlugin.getData(context)
                    .edit()
                    .putLong("last_meal_epoch_ms", System.currentTimeMillis())
                    .apply()

                // Refresh the widget immediately so the user sees 0h 0m.
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, BioVoltWidget::class.java)
                )
                for (id in ids) {
                    BioVoltWidget.updateWidget(context, appWidgetManager, id)
                }
            }
        }
    }

    companion object {
        const val ACTION_I_ATE = "com.biovolt.app.ACTION_I_ATE"
    }
}
