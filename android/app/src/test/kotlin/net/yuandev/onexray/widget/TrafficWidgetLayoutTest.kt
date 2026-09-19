package net.yuandev.onexray.widget

import android.app.Application
import android.appwidget.AppWidgetManager
import android.content.res.Configuration
import android.graphics.Rect
import android.util.Xml
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import net.yuandev.onexray.R
import net.yuandev.onexray.pigeon.VpnStatus
import net.yuandev.onexray.vpn.TrafficSample
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.xmlpull.v1.XmlPullParser

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class, qualifiers = "notnight-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TrafficWidgetLayoutTest {
    @Test fun dataFitsDeclaredMinimumSize() = assertMinimumSize(fontScale = 1f)

    @Test fun dataFitsDeclaredMinimumSizeWithLargerText() = assertMinimumSize(fontScale = 1.3f)

    private fun assertMinimumSize(fontScale: Float) {
        val context = RuntimeEnvironment.getApplication()
        val manager = shadowOf(AppWidgetManager.getInstance(context))
        val id = manager.createWidget(TrafficWidgetProvider::class.java, R.layout.traffic_widget)
        for (locale in listOf("en-rUS", "zh-rCN", "b+zh+Hant", "ru", "fa")) {
            RuntimeEnvironment.setQualifiers("$locale-notnight-mdpi")
            val configuration = Configuration(context.resources.configuration).apply {
                this.fontScale = fontScale
            }
            @Suppress("DEPRECATION")
            context.resources.updateConfiguration(configuration, context.resources.displayMetrics)
            val dimensions = context.resources.getXml(R.xml.traffic_widget_info).use { parser ->
                while (parser.next() != XmlPullParser.START_TAG) { }
                val attributes = context.obtainStyledAttributes(Xml.asAttributeSet(parser), intArrayOf(
                    android.R.attr.minResizeWidth, android.R.attr.minResizeHeight,
                    android.R.attr.targetCellWidth, android.R.attr.targetCellHeight,
                ))
                try {
                    assertEquals(4, attributes.getInt(2, 0))
                    assertEquals(2, attributes.getInt(3, 0))
                    attributes.getDimensionPixelSize(0, 0) to attributes.getDimensionPixelSize(1, 0)
                } finally {
                    attributes.recycle()
                }
            }
            // Keep the compact contract independent of provider metadata, so
            // increasing the minimum size cannot hide a clipping regression.
            assertEquals(280 to 180, dimensions)
            for (status in listOf(
                VpnStatus.DISCONNECTED, VpnStatus.CONNECTING,
                VpnStatus.CONNECTED, VpnStatus.DISCONNECTING,
            )) {
                val sample = if (status == VpnStatus.CONNECTED)
                    TrafficSample(104_752_742_400L, 104_752_742_400L, 1_048_471_142, 1_048_471_142) else null
                TrafficWidgetProvider.publish(context, status, sample)
                manager.reconstructWidgetViewAsIfPhoneWasRotated(id)
                val view = manager.getViewFor(id)
                view.measure(
                    View.MeasureSpec.makeMeasureSpec(dimensions.first, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(dimensions.second, View.MeasureSpec.EXACTLY),
                )
                view.layout(0, 0, view.measuredWidth, view.measuredHeight)
                val action = view.findViewById<View>(R.id.traffic_action)
                assertEquals(48, action.width)
                assertEquals(48, action.height)
                assertTrue(action.contentDescription.isNotEmpty())
                val busy = status == VpnStatus.CONNECTING || status == VpnStatus.DISCONNECTING
                assertEquals(!busy, action.isEnabled)
                assertEquals(if (busy) View.VISIBLE else View.GONE,
                    view.findViewById<View>(R.id.traffic_action_progress).visibility)
                for (textId in listOf(
                    R.id.traffic_title, R.id.traffic_status,
                    R.id.traffic_download_label, R.id.traffic_download_speed, R.id.traffic_download_session,
                    R.id.traffic_upload_label, R.id.traffic_upload_speed, R.id.traffic_upload_session,
                )) {
                    val text = view.findViewById<TextView>(textId)
                    val message = "$locale fontScale=$fontScale $status ${context.resources.getResourceEntryName(textId)}"
                    val required = text.layout.height + text.compoundPaddingTop + text.compoundPaddingBottom
                    assertTrue("$message height=${text.height}, required=$required", text.height >= required)
                    val contentWidth = text.width - text.compoundPaddingLeft - text.compoundPaddingRight
                    for (line in 0 until text.lineCount) {
                        assertTrue("$message line $line exceeds width $contentWidth",
                            text.layout.getLineWidth(line) <= contentWidth + 1)
                        assertEquals("$message must not ellipsize", 0, text.layout.getEllipsisCount(line))
                    }
                    assertEquals("$message must show all text", text.text.length,
                        text.layout.getLineEnd(text.lineCount - 1))
                    val container = view.findViewById<ViewGroup>(
                        if (textId == R.id.traffic_title || textId == R.id.traffic_status)
                            R.id.traffic_header else R.id.traffic_data,
                    )
                    val bounds = Rect(0, 0, text.width, text.height)
                    container.offsetDescendantRectToMyCoords(text, bounds)
                    assertTrue("$message exceeds its section: $bounds",
                        Rect(0, 0, container.width, container.height).contains(bounds))
                }
            }
        }
    }
}
