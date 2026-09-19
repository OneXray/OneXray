package net.yuandev.onexray.widget

import android.app.Application
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.res.Configuration
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.util.Xml
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.RemoteViews
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
import org.robolectric.shadows.ShadowAppWidgetManager
import org.robolectric.util.ReflectionHelpers
import org.robolectric.util.ReflectionHelpers.ClassParameter
import org.xmlpull.v1.XmlPullParser
import kotlin.math.ceil

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 30, 34], application = Application::class, qualifiers = "notnight-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TrafficWidgetLayoutTest {
    @Test fun legacyLauncherCanPlaceAndResizeToFourByTwo() {
        val context = RuntimeEnvironment.getApplication()
        val padding = AppWidgetHostView.getDefaultPaddingForWidget(
            context, ComponentName(context, TrafficWidgetProvider::class.java), null,
        )
        context.resources.getXml(R.xml.traffic_widget_info).use { parser ->
            while (parser.next() != XmlPullParser.START_TAG) { }
            val attributes = context.obtainStyledAttributes(Xml.asAttributeSet(parser), intArrayOf(
                android.R.attr.minWidth, android.R.attr.minHeight,
                android.R.attr.minResizeWidth, android.R.attr.minResizeHeight,
                android.R.attr.targetCellWidth, android.R.attr.targetCellHeight,
            ))
            try {
                assertEquals(4, attributes.getInt(4, 0))
                assertEquals(2, attributes.getInt(5, 0))
                // Android 11 Launcher3 uses the smallest cell in either orientation
                // plus host padding. Pixel 4 cells are 73dp wide / 66dp high:
                // https://developer.android.com/develop/ui/views/appwidgets/layouts
                for (offset in listOf(0, 2)) {
                    val width = attributes.getDimensionPixelSize(offset, 0)
                    val height = attributes.getDimensionPixelSize(offset + 1, 0)
                    assertEquals("legacy columns ($width dp)", 4,
                        ceil((width + padding.left + padding.right) / 73.0).toInt())
                    assertEquals("legacy rows ($height dp)", 2,
                        ceil((height + padding.top + padding.bottom) / 66.0).toInt())
                }
            } finally {
                attributes.recycle()
            }
        }
    }

    @Test fun dataFitsDeclaredMinimumSize() = assertMinimumSize(fontScale = 1f)

    @Test fun dataFitsDeclaredMinimumSizeWithLargerText() = assertMinimumSize(fontScale = 1.3f)

    @Test fun cachedLayoutsFollowRotationAndResizeIndependently() {
        val context = RuntimeEnvironment.getApplication()
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val manager = shadowOf(appWidgetManager)
        val id = manager.createWidget(TrafficWidgetProvider::class.java, R.layout.traffic_widget_compact)
        val otherId = manager.createWidget(TrafficWidgetProvider::class.java, R.layout.traffic_widget_compact)
        appWidgetManager.updateAppWidgetOptions(id, widgetSizes(300, 116, 554, 220))
        appWidgetManager.updateAppWidgetOptions(otherId, widgetSizes(260, 116, 260, 116))
        TrafficWidgetProvider.publish(context, VpnStatus.CONNECTED, TrafficSample(1024, 2048, 64, 128))
        for ((orientation, size, compact) in listOf(
            Triple("port", 300 to 220, false), Triple("land", 554 to 116, true),
            Triple("port", 300 to 220, false),
        )) {
            RuntimeEnvironment.setQualifiers("en-rUS-$orientation-notnight-mdpi")
            val view = applyCachedViews(context, manager, id, size)
            assertEquals(if (compact) View.GONE else View.VISIBLE,
                view.findViewById<View>(R.id.traffic_download_label).visibility)
            assertEquals(context.getString(R.string.traffic_stop_vpn),
                view.findViewById<View>(R.id.traffic_action).contentDescription)
        }
        // No new sample: the size callback must render the current content.
        appWidgetManager.updateAppWidgetOptions(id, widgetSizes(260, 116, 260, 116))
        var view = applyCachedViews(context, manager, id, 260 to 116)
        assertEquals(View.GONE, view.findViewById<View>(R.id.traffic_download_label).visibility)
        assertTrue(view.findViewById<TextView>(R.id.traffic_download_session).text.contains("2 KB"))
        appWidgetManager.updateAppWidgetOptions(id, widgetSizes(300, 220, 300, 220))
        view = applyCachedViews(context, manager, id, 300 to 220)
        assertEquals(View.VISIBLE, view.findViewById<View>(R.id.traffic_download_label).visibility)
        val other = applyCachedViews(context, manager, otherId, 260 to 116)
        assertEquals(View.GONE, other.findViewById<View>(R.id.traffic_download_label).visibility)
    }

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
            // Keep the compact contract independent of provider metadata, so
            // increasing the minimum size cannot hide a clipping regression.
            for (dimensions in listOf(260 to 116, 276 to 220, 280 to 180, 400 to 220, 554 to 117)) {
                AppWidgetManager.getInstance(context).updateAppWidgetOptions(id, widgetSizes(
                    dimensions.first, dimensions.second, dimensions.first, dimensions.second,
                ))
                for (status in listOf(
                    VpnStatus.DISCONNECTED, VpnStatus.CONNECTING,
                    VpnStatus.CONNECTED, VpnStatus.DISCONNECTING,
                )) {
                    val speeds = if (status == VpnStatus.CONNECTED)
                        listOf(1_048_471_142L, 1_048_566L) else listOf(0L)
                    for (speed in speeds) {
                        val sample = if (status == VpnStatus.CONNECTED)
                            TrafficSample(104_752_742_400L, 104_752_742_400L, speed, speed) else null
                        TrafficWidgetProvider.publish(context, status, sample)
                        val view = applyCachedViews(context, manager, id, dimensions)
                        view.measure(
                            View.MeasureSpec.makeMeasureSpec(dimensions.first, View.MeasureSpec.EXACTLY),
                            View.MeasureSpec.makeMeasureSpec(dimensions.second, View.MeasureSpec.EXACTLY),
                        )
                        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
                        assertContentFits(view, status, "$locale fontScale=$fontScale $dimensions speed=$speed")
                    }
                }
            }
        }
    }

    private fun assertContentFits(view: View, status: VpnStatus, scenario: String) {
        val context = view.context
        val action = view.findViewById<View>(R.id.traffic_action)
        assertEquals(48, action.width)
        assertEquals(48, action.height)
        assertTrue(action.contentDescription.isNotEmpty())
        val busy = status == VpnStatus.CONNECTING || status == VpnStatus.DISCONNECTING
        assertEquals(!busy, action.isEnabled)
        assertEquals(if (busy) View.VISIBLE else View.GONE,
            view.findViewById<View>(R.id.traffic_action_progress).visibility)
        assertTrue(view.findViewById<View>(R.id.traffic_download_speed).contentDescription
            .startsWith(context.getString(R.string.traffic_download)))
        assertTrue(view.findViewById<View>(R.id.traffic_upload_speed).contentDescription
            .startsWith(context.getString(R.string.traffic_upload)))
        for (textId in listOf(
            R.id.traffic_title, R.id.traffic_status,
            R.id.traffic_download_label, R.id.traffic_download_speed, R.id.traffic_download_session,
            R.id.traffic_upload_label, R.id.traffic_upload_speed, R.id.traffic_upload_session,
        )) {
            val text = view.findViewById<TextView>(textId)
            if (text.visibility == View.GONE) {
                assertTrue(textId == R.id.traffic_download_label || textId == R.id.traffic_upload_label)
                continue
            }
            val message = "$scenario $status ${context.resources.getResourceEntryName(textId)}"
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

    private fun widgetSizes(minWidth: Int, minHeight: Int, maxWidth: Int, maxHeight: Int) = Bundle().apply {
        putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, minWidth)
        putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, minHeight)
        putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, maxWidth)
        putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, maxHeight)
    }

    private fun applyCachedViews(context: Context, manager: ShadowAppWidgetManager, id: Int, size: Pair<Int, Int>): View {
        // The Robolectric manager's getViewFor() has no host size and always
        // selects the smallest API 31+ variant. Exercise Android's real size
        // selector on the published RemoteViews, just as AppWidgetHostView does.
        val widgets = ReflectionHelpers.getField<Map<Int, Any>>(manager, "widgetInfos")
        val views = ReflectionHelpers.getField<RemoteViews>(widgets.getValue(id), "lastRemoteViews")
        val selected = if (Build.VERSION.SDK_INT >= 31) {
            ReflectionHelpers.callInstanceMethod<RemoteViews>(views, "getRemoteViewsToApply",
                ClassParameter.from(Context::class.java, context),
                ClassParameter.from(SizeF::class.java, SizeF(size.first.toFloat(), size.second.toFloat())),
            )
        } else views
        return selected.apply(context, FrameLayout(context))
    }
}
