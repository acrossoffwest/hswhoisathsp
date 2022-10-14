package com.appwidgetflutter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AppWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context,
                    Uri.parse("myAppWidget://updatecounter"))
                setOnClickPendingIntent(R.id.widget_root, backgroundIntent)
                val isLoading = widgetData.getBoolean("_isLoading", false)
                val counter = widgetData.getInt("_counter", 0)
                val carbonLife = widgetData.getString("_carbonLife", "")
                var counterText = "There are $counter carbon-based lifeforms in HS according to our measurements.\n$carbonLife"
                if (isLoading) {
                    counterText = "Loading..."
                }
                setTextViewText(R.id.tv_counter, counterText)
                setOnClickPendingIntent(R.id.bt_update, backgroundIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}