package net.yuandev.onexray.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import net.yuandev.onexray.MainActivity
import net.yuandev.onexray.R
import net.yuandev.onexray.pigeon.VpnStatus
import net.yuandev.onexray.vpn.TrafficSample

class TrafficWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) = render(context, appWidgetManager, appWidgetIds)

    companion object {
        // The provider and VPN service share :native. No counters are written to
        // SharedPreferences, and the stopped Flutter process is not a producer.
        private var status = VpnStatus.DISCONNECTED
        private var sample: TrafficSample? = null

        fun publish(context: Context, status: VpnStatus, sample: TrafficSample? = null) {
            this.status = status
            this.sample = sample
            val manager = AppWidgetManager.getInstance(context)
            render(context, manager, manager.getAppWidgetIds(ComponentName(context, TrafficWidgetProvider::class.java)))
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            if (ids.isEmpty()) return
            val label = when (status) {
                VpnStatus.CONNECTED -> R.string.quick_settings_tile_status_connected
                VpnStatus.CONNECTING -> R.string.quick_settings_tile_status_connecting
                VpnStatus.DISCONNECTING -> R.string.quick_settings_tile_status_disconnecting
                else -> R.string.quick_settings_tile_status_disconnected
            }
            val views = RemoteViews(context.packageName, R.layout.traffic_widget).apply {
                setTextViewText(R.id.traffic_status, context.getString(label))
                setTextViewText(R.id.traffic_speed, TrafficSample.speedText(sample))
                setTextViewText(R.id.traffic_session, TrafficSample.sessionText(sample))
                setOnClickPendingIntent(R.id.traffic_widget, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            manager.updateAppWidget(ids, views)
        }
    }
}
