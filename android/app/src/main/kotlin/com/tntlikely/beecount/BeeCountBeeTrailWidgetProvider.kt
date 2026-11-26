package com.tntlikely.beecount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** 小号记账连续蜂迹组件，展示 Flutter 离屏渲染的 `widget_beeTrail_small`。 */
class BeeCountBeeTrailWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.bee_trail_widget)
            views.setWidgetArtwork(context, data, "widget_beeTrail_small")
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(Intent.ACTION_VIEW, Uri.parse("beecount://open?page=transactions"))
            intent.data = Uri.parse("beecount://open?page=transactions")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            views.setOnClickPendingIntent(
                R.id.widget_click,
                PendingIntent.getActivity(context, id, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            )
            manager.updateAppWidget(id, views)
        }
    }
}
