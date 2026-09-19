package net.yuandev.onexray.widget

import android.app.Application
import android.appwidget.AppWidgetManager
import android.graphics.PorterDuffColorFilter
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import net.yuandev.onexray.R
import net.yuandev.onexray.pigeon.VpnStatus
import net.yuandev.onexray.vpn.TrafficSample
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 34], application = Application::class, qualifiers = "notnight")
class TrafficWidgetThemeTest {
    @Test
    fun cachedWidgetFollowsThemeWithoutAnotherProviderUpdate() {
        val context = RuntimeEnvironment.getApplication()
        val manager = shadowOf(AppWidgetManager.getInstance(context))
        val id = manager.createWidget(TrafficWidgetProvider::class.java, R.layout.traffic_widget)
        for (status in listOf(
            VpnStatus.DISCONNECTED, VpnStatus.CONNECTING,
            VpnStatus.CONNECTED, VpnStatus.DISCONNECTING,
        )) {
            val sample = if (status == VpnStatus.CONNECTED)
                TrafficSample(1024, 2048, 64, 128) else null
            TrafficWidgetProvider.publish(context, status, sample)
            assertPalette(manager.getViewFor(id), status)

            // Launcher reapplies its cached RemoteViews after a theme change.
            // Do not publish again: disconnected widgets have no live sampler.
            RuntimeEnvironment.setQualifiers("+night")
            manager.reconstructWidgetViewAsIfPhoneWasRotated(id)
            assertPalette(manager.getViewFor(id), status)

            RuntimeEnvironment.setQualifiers("+notnight")
            manager.reconstructWidgetViewAsIfPhoneWasRotated(id)
            assertPalette(manager.getViewFor(id), status)
        }
    }

    private fun assertPalette(view: View, status: VpnStatus) {
        val context = view.context
        val busy = status == VpnStatus.CONNECTING || status == VpnStatus.DISCONNECTING
        val connected = status == VpnStatus.CONNECTED
        val actionColor = context.getColor(
            if (connected || busy) R.color.traffic_foreground else R.color.traffic_on_action,
        )
        assertEquals(actionColor, view.findViewById<TextView>(R.id.traffic_action_label).currentTextColor)
        assertEquals(actionColor, imageColor(view.findViewById(R.id.traffic_action_icon)))
        assertEquals(!busy, view.findViewById<View>(R.id.traffic_action).isEnabled)
        val rateColor = context.getColor(
            if (connected) R.color.traffic_primary else R.color.traffic_secondary,
        )
        assertEquals(rateColor, view.findViewById<TextView>(R.id.traffic_download_speed).currentTextColor)
        assertEquals(rateColor, view.findViewById<TextView>(R.id.traffic_upload_speed).currentTextColor)
        val statusColor = context.getColor(when {
            connected -> R.color.traffic_status_connected
            busy -> R.color.traffic_primary
            else -> R.color.traffic_status_idle
        })
        assertEquals(statusColor, imageColor(view.findViewById(R.id.traffic_status_dot)))
    }

    private fun imageColor(view: ImageView): Int? =
        (view.colorFilter as? PorterDuffColorFilter)?.let { shadowOf(it).color }
            ?: view.imageTintList?.getColorForState(view.drawableState, 0)
            ?: (view.drawable.current as? GradientDrawable)?.color?.defaultColor
}
