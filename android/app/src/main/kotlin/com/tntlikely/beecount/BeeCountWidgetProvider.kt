package com.tntlikely.beecount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

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
                    // Load the rendered widget image
                    val imagePath = widgetData.getString("widgetImage", null)
                    Log.d(TAG, "Image path from SharedPreferences: $imagePath")

                    if (imagePath != null) {
                        val file = File(imagePath)
                        Log.d(TAG, "File exists: ${file.exists()}, size: ${if(file.exists()) file.length() else 0}")

                        val bitmap = loadWidgetBitmap(imagePath)
                        if (bitmap != null) {
                            Log.d(TAG, "Bitmap decoded successfully: ${bitmap.width}x${bitmap.height}")
                            setImageViewBitmap(R.id.widget_image, bitmap)
                        } else {
                            Log.e(TAG, "Failed to decode bitmap from file")
                            setImageViewResource(R.id.widget_image, R.mipmap.ic_launcher)
                        }
                    } else {
                        Log.w(TAG, "No image path in SharedPreferences, showing placeholder")
                        setImageViewResource(R.id.widget_image, R.mipmap.ic_launcher)
                    }

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

    private fun loadWidgetBitmap(imagePath: String): Bitmap? {
        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(imagePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val maxWidth = 600
        val maxHeight = 300
        var sampleSize = 1
        while (bounds.outWidth / sampleSize > maxWidth ||
            bounds.outHeight / sampleSize > maxHeight
        ) {
            sampleSize *= 2
        }

        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
        }
        return BitmapFactory.decodeFile(imagePath, options)
    }
}
