package com.tntlikely.beecount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 收支速览小组件·小号(1×1 方形,仅一档)。
 *
 * 对应 `lib/widget/widget_spec.dart` 的 `glanceSmall`,渲染管线把图片写入
 * 固定 key `widget_glance_small`。之所以是独立 provider 而不是给历史的
 * [BeeCountWidgetProvider](中号)加尺寸分档:老 provider 承载着存量用户
 * 已放置的组件(D2 back-compat,零改动原则),小号作为补全新增单独成类,
 * 互不影响。
 */
class BeeCountGlanceSmallWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "BeeCountGlanceSmall"
        private const val IMAGE_KEY = "widget_glance_small"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")
        appWidgetIds.forEach { widgetId ->
            try {
                Log.d(TAG, "Updating widget $widgetId")

                val views = RemoteViews(context.packageName, R.layout.glance_small_widget).apply {
                    setWidgetArtwork(context, widgetData, IMAGE_KEY)

                    // 整块点击 → 记支出(小号主视觉是今日支出大数,没有中号的
                    // 左右分区语义;与 iOS 小号 family 的整卡 Link 行为一致)。
                    try {
                        val intent = createLaunchIntentWithDeepLink(context, "beecount://new?type=expense")
                        val pending = PendingIntent.getActivity(
                            context, widgetId, intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        setOnClickPendingIntent(R.id.widget_click, pending)
                        Log.d(TAG, "Set click handler")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to set click", e)
                    }
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                Log.d(TAG, "Widget $widgetId updated successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", e)
            }
        }
    }

    private fun createLaunchIntentWithDeepLink(context: Context, url: String): Intent {
        // 使用 launch intent 确保能打开 App，同时携带 deep link 数据
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                setPackage(context.packageName)
            }
        intent.data = Uri.parse(url)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return intent
    }
}
