package com.tntlikely.beecount

import android.graphics.Bitmap
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.RemoteViews
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DashboardWidgetLayoutTest {
    @Test fun hitRegionsFollowTheVisibleArtworkInResizedCells() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val artwork = Bitmap.createBitmap(364, 382, Bitmap.Config.ARGB_8888)
        instrumentation.runOnMainSync {
            for ((width, height) in listOf(364 to 382, 300 to 700, 700 to 300)) {
                val root = RemoteViews(context.packageName, R.layout.dashboard_widget)
                    .apply(context, FrameLayout(context))
                val image = checkNotNull(root.findViewById<ImageView>(R.id.widget_image)
                    ?: root.findViewById<ImageView>(R.id.widget_image_dark))
                image.setImageBitmap(artwork)
                root.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
                root.layout(0, 0, width, height)
                val bounds = root.findViewById<View>(R.id.dashboard_artwork_bounds)
                val quickAdd = root.findViewById<View>(R.id.click_quick_add)
                val hitGroup = quickAdd.parent as View
                val visibleHeight = minOf(height, (width * 382f / 364f).roundToInt())
                assertEquals(visibleHeight.toFloat(), bounds.height.toFloat(), 1f)
                assertEquals((height - visibleHeight) / 2f, hitGroup.top.toFloat(), 1f)
                assertEquals(bounds.top + bounds.height, hitGroup.top + quickAdd.bottom)
                assertEquals(visibleHeight * .18f, quickAdd.height.toFloat(), 1f)
            }
        }
    }

}
