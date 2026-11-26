package com.tntlikely.beecount

import android.appwidget.AppWidgetManager
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import android.widget.RemoteViews
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DashboardWidgetLayoutTest {
    @Test fun keepsArtworkFullSizeAndAlignsTheButtonWhenTheHostReportsItsSize() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val density = context.resources.displayMetrics.density
        instrumentation.runOnMainSync {
            for ((widthDp, heightDp) in listOf(364 to 382, 300 to 700, 700 to 300, 0 to 0)) {
                val options = Bundle().apply {
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, widthDp)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, widthDp)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, heightDp)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, heightDp)
                }
                val root = RemoteViews(context.packageName, R.layout.dashboard_widget).apply {
                    addView(R.id.dashboard_action_container, dashboardActions(context, options, null, null))
                }.apply(context, FrameLayout(context))
                val width = ((if (widthDp == 0) 320 else widthDp) * density).roundToInt()
                val height = ((if (heightDp == 0) 600 else heightDp) * density).roundToInt()
                root.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
                root.layout(0, 0, width, height)
                val image = checkNotNull(root.findViewById<View>(R.id.widget_image)
                    ?: root.findViewById<View>(R.id.widget_image_dark))
                assertEquals(width, image.width)
                assertEquals(height, image.height)
                val visibleHeight = if (widthDp == 0) height.toFloat() else minOf(height.toFloat(), width * 382f / 364f)
                val detail = root.findViewById<View>(R.id.widget_click)
                val button = root.findViewById<View>(R.id.click_quick_add)
                assertEquals((height - visibleHeight) / 2f, detail.top.toFloat(), 1.5f)
                assertEquals(detail.bottom, button.top)
                assertEquals(visibleHeight * .18f, button.height.toFloat(), 1.5f)
            }
        }
    }
}
