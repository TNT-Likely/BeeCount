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
 * 快速记账小组件(小/中两档)。
 *
 * 对应 `lib/widget/widget_spec.dart` 的 `quickAddSmall/Medium`,渲染管线把
 * 图片分别写入 `widget_quickAdd_small` / `widget_quickAdd_medium` 两个 key。
 *
 * 尺寸判定机制与已知局限同 [BeeCountNetWorthWidgetProvider]:本 provider
 * 类名同时覆盖两档尺寸,`onUpdate` 按 `AppWidgetManager.getAppWidgetOptions`
 * 读到的实际尺寸选择图片 key(见 [resolveImageKey]);但 `widget_spec.dart`
 * 的 `WidgetSpec.matchInstalled` 目前按 androidClassName 匹配、不感知尺寸,
 * 只会匹配到 catalog 里排在最前的 `quickAddSmall`,渲染管线在 Android 上
 * 对本类型可能只渲染 small 档的图片。
 */
class BeeCountQuickAddWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "BeeCountQuickAddWidget"

        // 阈值取自 widget_spec.dart 的 logicalSize:small(155x155) 与
        // medium(364x169) 宽度的中点,只是粗略分档,不代表精确换算。
        private const val WIDTH_BREAKPOINT_SMALL_MEDIUM_DP = 260
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

                val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
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

                    // 整块点击 → 新建支出。第一版不分区。
                    // TODO: 常用分类格拆分点击区域后,改为按分类深链
                    // beecount://new?type=expense&category=<id>。
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

    /**
     * 按当前 widget 实际尺寸(`OPTION_APPWIDGET_MIN_WIDTH`)判定 small/medium
     * 档位,选择对应的图片 key。拿不到尺寸信息(选项缺失或为 0)时退化为
     * medium。
     */
    private fun resolveImageKey(appWidgetManager: AppWidgetManager, widgetId: Int): String {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)

        if (minWidth <= 0) {
            return "widget_quickAdd_medium"
        }
        return if (minWidth < WIDTH_BREAKPOINT_SMALL_MEDIUM_DP) {
            "widget_quickAdd_small"
        } else {
            "widget_quickAdd_medium"
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
