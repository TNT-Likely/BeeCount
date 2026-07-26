package com.tntlikely.beecount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * 最近交易小组件(中/大两档)。
 *
 * 对应 `lib/widget/widget_spec.dart` 的 `recentMedium/Large`,渲染管线把
 * 图片分别写入 `widget_recent_medium` / `widget_recent_large` 两个 key。
 *
 * 两档宽度相同(364dp)、高度不同(169dp/382dp),因此只按高度分档,详见
 * [resolveImageKey]。尺寸判定机制同 [BeeCountNetWorthWidgetProvider]:
 * Dart 侧 `matchInstalledAll` 为命中类名渲染该类型全部尺寸的图,任意缩放
 * 档位都有现成图可显。
 */
open class BeeCountRecentWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "BeeCountRecentWidget"

        // 阈值取自 widget_spec.dart 的 logicalSize:medium(364x169) 与
        // large(364x382) 高度的中点,只是粗略分档,不代表精确换算。
        private const val HEIGHT_BREAKPOINT_MEDIUM_LARGE_DP = 275
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
                val imageKey = resolveImageKey(appWidgetManager, widgetId)
                Log.d(TAG, "Widget $widgetId resolved image key: $imageKey")

                val views = RemoteViews(context.packageName, R.layout.recent_widget).apply {
                    val imagePath = widgetData.getString(imageKey, null)
                    Log.d(TAG, "Image path from SharedPreferences: $imagePath")

                    if (imagePath != null) {
                        val file = File(imagePath)
                        Log.d(TAG, "File exists: ${file.exists()}, size: ${if (file.exists()) file.length() else 0}")

                        val bitmap = BitmapFactory.decodeFile(imagePath)
                        if (bitmap != null) {
                            Log.d(TAG, "Bitmap decoded successfully: ${bitmap.width}x${bitmap.height}")
                            setImageViewBitmap(R.id.widget_image, bitmap)
                        } else {
                            Log.e(TAG, "Failed to decode bitmap from file")
                            setImageViewResource(R.id.widget_image, R.mipmap.ic_launcher)
                        }
                    } else {
                        Log.w(TAG, "No image path for key $imageKey, showing placeholder")
                        setImageViewResource(R.id.widget_image, R.mipmap.ic_launcher)
                    }

                    // 整块点击 → 明细页。第一版不分区。
                    // TODO: 点单笔交易跳转到该笔详情是二期优化,需要按行分区深链
                    // 并携带交易 id,例如 beecount://open?page=detail&id=<id>。
                    try {
                        val intent = createLaunchIntentWithDeepLink(context, "beecount://open?page=detail")
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

    /**
     * 按当前 widget 实际尺寸(`OPTION_APPWIDGET_MIN_HEIGHT`)判定 medium/large
     * 档位,选择对应的图片 key。拿不到尺寸信息(选项缺失或为 0)时退化为
     * medium。
     */
    private fun resolveImageKey(appWidgetManager: AppWidgetManager, widgetId: Int): String {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)

        if (minHeight <= 0) {
            return "widget_recent_medium"
        }
        return if (minHeight >= HEIGHT_BREAKPOINT_MEDIUM_LARGE_DP) {
            "widget_recent_large"
        } else {
            "widget_recent_medium"
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
