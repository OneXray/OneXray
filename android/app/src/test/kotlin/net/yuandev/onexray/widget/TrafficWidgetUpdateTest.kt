package net.yuandev.onexray.widget

import android.app.Application
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.view.View
import android.widget.TextView
import net.yuandev.onexray.R
import net.yuandev.onexray.pigeon.VpnStatus
import net.yuandev.onexray.vpn.OneVpnService
import net.yuandev.onexray.vpn.TrafficSample
import net.yuandev.onexray.vpn.VpnController
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowVpnService
import org.robolectric.util.ReflectionHelpers
import java.util.concurrent.atomic.AtomicBoolean

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 34], application = Application::class, qualifiers = "en-rUS-notnight")
class TrafficWidgetUpdateTest {
    @Test fun localeBroadcastRefreshesIdleWidgetAndPreservesConnectedSample() {
        val context = RuntimeEnvironment.getApplication()
        val manager = shadowOf(AppWidgetManager.getInstance(context))
        val id = manager.createWidget(TrafficWidgetProvider::class.java, R.layout.traffic_widget)
        for (status in listOf(VpnStatus.DISCONNECTED, VpnStatus.CONNECTED)) {
            val sample = if (status == VpnStatus.CONNECTED) TrafficSample(1024, 2048, 64, 128) else null
            TrafficWidgetProvider.publish(context, status, sample)
            for (locale in listOf("zh-rCN", "b+zh+Hant", "ru", "fa", "en-rUS")) {
                RuntimeEnvironment.setQualifiers("$locale-notnight")
                context.sendBroadcast(Intent(Intent.ACTION_LOCALE_CHANGED))
                shadowOf(Looper.getMainLooper()).idle()
                manager.reconstructWidgetViewAsIfPhoneWasRotated(id)
                val view = manager.getViewFor(id)
                view.measure(
                    View.MeasureSpec.makeMeasureSpec(400, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(300, View.MeasureSpec.EXACTLY),
                )
                view.layout(0, 0, view.measuredWidth, view.measuredHeight)
                val action = if (status == VpnStatus.CONNECTED) R.string.traffic_stop_vpn else R.string.traffic_start_vpn
                assertEquals(context.getString(action), view.findViewById<TextView>(R.id.traffic_action_label).text.toString())
                assertEquals(context.getString(R.string.traffic_download), view.findViewById<TextView>(R.id.traffic_download_label).text.toString())
                assertEquals(context.resources.configuration.layoutDirection, view.layoutDirection)
                if (sample != null) {
                    assertTrue(view.findViewById<TextView>(R.id.traffic_download_session).text.contains("2 KB"))
                }
                assertNull(shadowOf(context).nextStartedService)
                assertNull(shadowOf(context).nextStartedActivity)
            }
        }
    }

    @Test fun startDelegatesToOwnServiceRegardlessOfStaleWidgetPresentation() {
        val context = RuntimeEnvironment.getApplication()
        ShadowVpnService.setPrepareResult(null)
        val file = VpnController.startFile(context)
        file.parentFile!!.mkdirs()
        file.writeText("""{
            "tun":{"tunDnsIPv4":"8.8.8.8"},
            "metricsPort":"19400",
            "coreInvokeText":"{\"apiVersion\":3,\"method\":\"runXray\",\"payload\":{\"xrayJson\":\"{}\"}}"
        }""")
        val provider = TrafficWidgetProvider()
        for (status in VpnStatus.entries) {
            TrafficWidgetProvider.publish(context, status)
            provider.onReceive(context, Intent(context, TrafficWidgetProvider::class.java)
                .setAction("net.yuandev.onexray.widget.START_VPN"))
            val started = shadowOf(context).nextStartedService
            assertNotNull("The service, not the cached $status presentation, handles start", started)
            assertEquals(ComponentName(context, OneVpnService::class.java), started.component)
            assertEquals(OneVpnService.ACTION_START, started.action)
            assertTrue(started.getBooleanExtra(OneVpnService.EXTRA_REUSE_CONFIGURATION, false))
            assertNull(shadowOf(context).nextStartedActivity)
        }
    }

    @Test fun repeatedStartPublishesActualServiceResourceStateWithoutRestarting() {
        val context = RuntimeEnvironment.getApplication()
        val manager = shadowOf(AppWidgetManager.getInstance(context))
        val id = manager.createWidget(TrafficWidgetProvider::class.java, R.layout.traffic_widget)
        shadowOf(context).grantPermissions("${context.packageName}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION")
        val controller = Robolectric.buildService(OneVpnService::class.java).create()
        val service = controller.get()
        val released = ReflectionHelpers.getField<AtomicBoolean>(service, "released")
        val pipe = ParcelFileDescriptor.createPipe()
        try {
            for (status in listOf(VpnStatus.CONNECTED, VpnStatus.DISCONNECTING)) {
                ReflectionHelpers.setField(service, "tunnel", pipe[0])
                ReflectionHelpers.setField(service, "running", status == VpnStatus.CONNECTED)
                released.set(status == VpnStatus.DISCONNECTING)
                TrafficWidgetProvider.publish(context, VpnStatus.CONNECTING)
                service.onStartCommand(Intent(context, OneVpnService::class.java)
                    .setAction(OneVpnService.ACTION_START), 0, 1)
                val view = manager.getViewFor(id)
                val label = if (status == VpnStatus.CONNECTED) R.string.traffic_stop_vpn
                    else R.string.quick_settings_tile_status_disconnecting
                assertEquals(context.getString(label), view.findViewById<TextView>(R.id.traffic_action_label).text.toString())
                assertEquals(status == VpnStatus.CONNECTED, view.findViewById<View>(R.id.traffic_action).isEnabled)
            }
        } finally {
            // The fixture represents resource state only; never call the native Core.
            released.set(true)
            ReflectionHelpers.setField(service, "tunnel", null)
            ReflectionHelpers.setField(service, "running", false)
            pipe.forEach { it.close() }
            controller.destroy()
        }
    }
}
