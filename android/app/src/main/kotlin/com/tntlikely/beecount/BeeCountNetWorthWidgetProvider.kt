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
 * 净资产小组件(小/中/大三档)。
 *
 * 对应 `lib/widget/widget_spec.dart` 的 `netWorthSmall/Medium/Large`,渲染
 * 管线把图片分别写入 `widget_netWorth_small` / `widget_netWorth_medium` /
 * `widget_netWorth_large` 三个 key。
 *
 * Android 没有 iOS WidgetKit 那种按 family 自动分发 TimelineProvider 的机制,
 * 本 provider 类名同时覆盖三档尺寸,`onUpdate` 里按
 * `AppWidgetManager.getAppWidgetOptions` 读到的当前实际尺寸,自行判定该用
 * 哪个图片 key(见 [resolveImageKey])。
 *
 * 已知局限(见 `widget_spec.dart` `WidgetSpec.matchInstalled` 文档):目前
 * `matchInstalled` 按 androidClassName 匹配、不感知具体尺寸,同一 provider
 * 类名对应多个 spec 时只会匹配到 catalog 里排在最前的那个尺寸
 * (`netWorthSmall`)。也就是说 Dart 侧「渲染管线只渲已安装 spec」这一步,
 * 在 Android 上目前对本类型可能只会渲染 small 这一档的图片,即便用户实际
 * 把 widget 拉到了 medium/large 尺寸——`resolveImageKey` 仍按真实尺寸取
 * key、为后续修复 `matchInstalled` 做好准备,但在修复前,用户拉大尺寸后
 * 桌面上显示的可能还是 small 档渲染出的图片内容。
 */
open class BeeCountNetWorthWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "BeeCountNetWorthWidget"

        // 阈值取自 widget_spec.dart 的 logicalSize:
        // small(155x155) / medium(364x169) / large(364x382)。
        // 下面两个数是 small↔medium 宽度中点、medium↔large 高度中点,
        // 只是粗略分档,不代表精确换算。
        private const val WIDTH_BREAKPOINT_SMALL_MEDIUM_DP = 260
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

                val views = RemoteViews(context.packageName, R.layout.net_worth_widget).apply {
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

                    // 整块点击 → 资产页。第一版不分区。
                    // TODO: 大号有账户明细列表时,考虑按行分区深链到具体账户。
                    try {
                        val intent = createLaunchIntentWithDeepLink(context, "beecount://open?page=assets")
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
     * 按当前 widget 实际尺寸(`OPTION_APPWIDGET_MIN_WIDTH/HEIGHT`)判定
     * small/medium/large 档位,选择对应的图片 key。拿不到尺寸信息(选项
     * 缺失或为 0)时退化为 medium。
     */
    private fun resolveImageKey(appWidgetManager: AppWidgetManager, widgetId: Int): String {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)

        if (minWidth <= 0 && minHeight <= 0) {
            return "widget_netWorth_medium"
        }
        return when {
            minWidth < WIDTH_BREAKPOINT_SMALL_MEDIUM_DP -> "widget_netWorth_small"
            minHeight >= HEIGHT_BREAKPOINT_MEDIUM_LARGE_DP -> "widget_netWorth_large"
            else -> "widget_netWorth_medium"
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
