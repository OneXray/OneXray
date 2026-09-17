package net.yuandev.onexray.widget

import android.app.ActivityOptions
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.text.SpannableString
import android.text.Spanned
import android.text.style.RelativeSizeSpan
import android.view.View
import android.widget.RemoteViews
import androidx.core.text.BidiFormatter
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import net.yuandev.onexray.MainActivity
import net.yuandev.onexray.R
import net.yuandev.onexray.pigeon.VpnStatus
import net.yuandev.onexray.vpn.OneVpnService
import net.yuandev.onexray.vpn.TrafficSample
import net.yuandev.onexray.vpn.VpnController

class TrafficWidgetProvider : HomeWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_START) {
            super.onReceive(context, intent)
            return
        }
        if (status == VpnStatus.CONNECTING || status == VpnStatus.DISCONNECTING) return
        if (VpnController.readVpnRunning(context)) {
            publish(context, VpnStatus.CONNECTED, sample)
            return
        }
        when (VpnController.startSavedVpn(context)) {
            VpnController.SavedStartResult.STARTED -> publish(context, VpnStatus.CONNECTING)
            VpnController.SavedStartResult.OPEN_APP -> {
                try {
                    openAppForStart(context)
                } catch (error: Exception) {
                    VpnController.reportStartFailure(context, error.message)
                }
            }
            VpnController.SavedStartResult.FAILED -> {
                publish(context, VpnStatus.DISCONNECTED)
                VpnController.reportStartFailure(context, VpnController.lastError)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) = render(context, appWidgetManager, appWidgetIds)

    companion object {
        private const val ACTION_START = "net.yuandev.onexray.widget.START_VPN"
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
                else -> R.string.traffic_widget_disconnected
            }
            val connected = status == VpnStatus.CONNECTED
            val busy = status == VpnStatus.CONNECTING || status == VpnStatus.DISCONNECTING
            val actionLabel = context.getString(when {
                busy -> label
                connected -> R.string.traffic_stop_vpn
                else -> R.string.traffic_start_vpn
            })
            val actionColor = context.getColor(
                if (connected || busy) R.color.traffic_foreground else R.color.traffic_on_action
            )
            val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            val views = RemoteViews(context.packageName, R.layout.traffic_widget).apply {
                setInt(R.id.traffic_widget, "setLayoutDirection", context.resources.configuration.layoutDirection)
                setTextViewText(R.id.traffic_download_label, context.getString(R.string.traffic_download))
                setTextViewText(R.id.traffic_upload_label, context.getString(R.string.traffic_upload))
                setTextViewText(R.id.traffic_status, context.getString(label))
                setInt(R.id.traffic_status_dot, "setColorFilter", context.getColor(when {
                    connected -> R.color.traffic_status_connected
                    busy -> R.color.traffic_primary
                    else -> R.color.traffic_status_idle
                }))
                setRate(context, R.id.traffic_download_speed, sample?.downloadSpeed)
                setRate(context, R.id.traffic_upload_speed, sample?.uploadSpeed)
                setTextViewText(R.id.traffic_download_session, sessionText(context, sample?.downlink))
                setTextViewText(R.id.traffic_upload_session, sessionText(context, sample?.uplink))
                setOnClickPendingIntent(R.id.traffic_header, openApp)
                setOnClickPendingIntent(R.id.traffic_data, openApp)
                setTextViewText(R.id.traffic_action_label, actionLabel)
                setTextColor(R.id.traffic_action_label, actionColor)
                setContentDescription(R.id.traffic_action, actionLabel)
                setInt(R.id.traffic_action_icon, "setColorFilter", actionColor)
                setInt(R.id.traffic_action, "setBackgroundResource",
                    if (connected || busy) R.drawable.traffic_action_stop else R.drawable.traffic_action_start)
                setViewVisibility(R.id.traffic_action_icon, if (busy) View.GONE else View.VISIBLE)
                setViewVisibility(R.id.traffic_action_progress, if (busy) View.VISIBLE else View.GONE)
                setBoolean(R.id.traffic_action, "setEnabled", !busy)
                setOnClickPendingIntent(R.id.traffic_action, when {
                    busy -> null
                    connected -> PendingIntent.getService(
                        context, 102,
                        Intent(context, OneVpnService::class.java).setAction(OneVpnService.ACTION_STOP),
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    )
                    else -> startIntent(context)
                })
            }
            manager.updateAppWidget(ids, views)
        }

        private fun startIntent(context: Context): PendingIntent {
            return PendingIntent.getBroadcast(
                context, 101, Intent(context, TrafficWidgetProvider::class.java).setAction(ACTION_START),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        private fun openAppForStart(context: Context) {
            val creationOptions = ActivityOptions.makeBasic()
            if (Build.VERSION.SDK_INT >= 35) {
                creationOptions.setPendingIntentCreatorBackgroundActivityStartMode(
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                )
            }
            val openApp = PendingIntent.getActivity(
                context, 101, VpnController.buildShortcutStartIntent(context),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                creationOptions.toBundle(),
            )
            val sendOptions = ActivityOptions.makeBasic()
            if (Build.VERSION.SDK_INT >= 34) {
                sendOptions.setPendingIntentBackgroundActivityStartMode(
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                )
            }
            openApp.send(context, 0, null, null, null, null, sendOptions.toBundle())
        }

        private fun RemoteViews.setRate(context: Context, viewId: Int, bytes: Long?) {
            val text = bytes?.let { "${TrafficSample.formatBytes(it)}/s" } ?: "—"
            val styled = SpannableString(text)
            val unit = text.indexOf(' ')
            if (unit >= 0) styled.setSpan(RelativeSizeSpan(0.5f), unit, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            setTextViewText(viewId, styled)
            setTextColor(viewId, context.getColor(
                if (bytes == null) R.color.traffic_secondary else R.color.traffic_primary
            ))
        }

        private fun sessionText(context: Context, bytes: Long?): String {
            val amount = bytes?.let(TrafficSample::formatBytes) ?: "—"
            return context.getString(R.string.traffic_session_value, BidiFormatter.getInstance().unicodeWrap(amount))
        }
    }
}
