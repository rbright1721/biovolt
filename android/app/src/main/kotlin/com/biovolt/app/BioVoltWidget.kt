package com.biovolt.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class BioVoltWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val widgetData = HomeWidgetPlugin.getData(context)

            val fastingTime = widgetData.getString(
                "fasting_time", "--:--") ?: "--:--"
            val protocol = widgetData.getString(
                "protocol_text", "No active protocols") ?: "No active protocols"
            val hrv = widgetData.getString(
                "hrv_text", "") ?: ""

            val views = RemoteViews(
                context.packageName,
                R.layout.biovolt_widget
            )

            views.setTextViewText(R.id.widget_fasting_time, fastingTime)
            views.setTextViewText(R.id.widget_protocol, protocol)
            views.setTextViewText(R.id.widget_hrv, hrv)

            // Tap widget to open app
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(
                android.R.id.background, pendingIntent
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
