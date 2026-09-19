package net.yuandev.onexray.widget

import android.app.Application
import android.appwidget.AppWidgetManager
import android.content.res.Configuration
import android.util.Xml
import android.view.View
import android.widget.TextView
import net.yuandev.onexray.R
import net.yuandev.onexray.pigeon.VpnStatus
import net.yuandev.onexray.vpn.TrafficSample
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
                ))
                try {
                    attributes.getDimensionPixelSize(0, 0) to attributes.getDimensionPixelSize(1, 0)
                } finally {
                    attributes.recycle()
                }
            }
            TrafficWidgetProvider.publish(context, VpnStatus.CONNECTED,
                TrafficSample(104_752_742_400L, 104_752_742_400L, 1_310_720, 1_310_720))
            manager.reconstructWidgetViewAsIfPhoneWasRotated(id)
            val view = manager.getViewFor(id)
            view.measure(
                View.MeasureSpec.makeMeasureSpec(dimensions.first, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(dimensions.second, View.MeasureSpec.EXACTLY),
            )
            view.layout(0, 0, view.measuredWidth, view.measuredHeight)
            for (textId in listOf(
                R.id.traffic_status, R.id.traffic_download_label, R.id.traffic_download_speed,
                R.id.traffic_download_session, R.id.traffic_upload_label, R.id.traffic_upload_speed,
                R.id.traffic_upload_session, R.id.traffic_action_label,
            )) {
                val text = view.findViewById<TextView>(textId)
                val required = text.layout.height + text.compoundPaddingTop + text.compoundPaddingBottom
                assertTrue("$locale fontScale=$fontScale ${context.resources.getResourceEntryName(textId)}: " +
                    "height=${text.height}, required=$required at $dimensions", text.height >= required)
            }
        }
    }
}
