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
 * 综合仪表盘小组件(仅大)。
 *
 * 对应 `lib/widget/widget_spec.dart` 的 `dashboardLarge`,渲染管线把图片
 * 写入固定 key `widget_dashboard_large`——只有一档尺寸,`onUpdate` 无需像
 * [BeeCountNetWorthWidgetProvider] 那样按 `getAppWidgetOptions` 分档。
 */
class BeeCountDashboardWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "BeeCountDashboardWidget"
        private const val IMAGE_KEY = "widget_dashboard_large"
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

                val views = RemoteViews(context.packageName, R.layout.dashboard_widget).apply {
                    setWidgetArtwork(context, widgetData, IMAGE_KEY)

                    // 分区点击(2026-07 真机反馈:底部画着「记一笔」却整块跳
                    // 明细,点记一笔进了洞察页):上部主体 → 明细,底部快捷
                    // 记账行 → 记支出。
                    try {
                        val detailIntent = createLaunchIntentWithDeepLink(context, "beecount://open?page=detail")
                        val detailPending = PendingIntent.getActivity(
                            context, widgetId * 10 + 1, detailIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        setOnClickPendingIntent(R.id.widget_root, detailPending)
                        setOnClickPendingIntent(R.id.widget_click, detailPending)

                        val expenseIntent = createLaunchIntentWithDeepLink(context, "beecount://new?type=expense")
                        val expensePending = PendingIntent.getActivity(
                            context, widgetId * 10 + 2, expenseIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        setOnClickPendingIntent(R.id.click_quick_add, expensePending)
                        Log.d(TAG, "Set click handlers (detail + quick add)")
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
