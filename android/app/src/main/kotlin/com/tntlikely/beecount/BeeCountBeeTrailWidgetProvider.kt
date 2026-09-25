package com.tntlikely.beecount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/** 小号记账连续蜂迹组件，展示 Flutter 离屏渲染的 `widget_beeTrail_small`。 */
class BeeCountBeeTrailWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.bee_trail_widget)
            val path = data.getString("widget_beeTrail_small", null)
            val bitmap = path?.let { if (File(it).exists()) BitmapFactory.decodeFile(it) else null }
            if (bitmap != null) views.setImageViewBitmap(R.id.widget_image, bitmap)
            else views.setImageViewResource(R.id.widget_image, R.mipmap.ic_launcher)
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
