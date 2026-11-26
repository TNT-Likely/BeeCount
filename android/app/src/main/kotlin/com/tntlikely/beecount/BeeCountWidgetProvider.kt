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

class BeeCountWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "BeeCountWidget"
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

                val views = RemoteViews(context.packageName, R.layout.beecount_widget).apply {
                    setWidgetArtwork(context, widgetData, "widgetImage")

                    // 左侧区域 → 打开支出记账
                    try {
                        val expenseIntent = createLaunchIntentWithDeepLink(context, "beecount://new?type=expense")
                        val expensePending = PendingIntent.getActivity(
                            context, widgetId * 10 + 1, expenseIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        setOnClickPendingIntent(R.id.click_expense, expensePending)
                        Log.d(TAG, "Set expense click handler")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to set expense click", e)
                    }

                    // 右侧区域 → 打开收入记账
                    try {
                        val incomeIntent = createLaunchIntentWithDeepLink(context, "beecount://new?type=income")
                        val incomePending = PendingIntent.getActivity(
                            context, widgetId * 10 + 2, incomeIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        setOnClickPendingIntent(R.id.click_income, incomePending)
                        Log.d(TAG, "Set income click handler")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to set income click", e)
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
