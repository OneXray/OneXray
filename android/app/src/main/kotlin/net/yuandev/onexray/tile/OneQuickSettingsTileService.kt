package net.yuandev.onexray.tile

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import net.yuandev.onexray.MainActivity
import net.yuandev.onexray.R
import net.yuandev.onexray.vpn.VpnController
import net.yuandev.onexray.vpn.OneVpnService

class OneQuickSettingsTileService : TileService() {
    private var vpnStatusReceiver: BroadcastReceiver? = null

    override fun onTileAdded() {
        super.onTileAdded()
        refreshTile()
    }

    @SuppressLint("UnspecifiedRegisterReceiverFlag")
    override fun onStartListening() {
        super.onStartListening()
        if (vpnStatusReceiver == null) {
            vpnStatusReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action != OneVpnService.ACTION_VPN_STATUS) {
                        return
                    }
                    val running = intent.getBooleanExtra(OneVpnService.EXTRA_RUNNING, false)
                    updateTileForVpnStatus(running)
                }
            }
        }
        val filter = IntentFilter(OneVpnService.ACTION_VPN_STATUS)
        vpnStatusReceiver?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(it, filter, RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(it, filter)
            }
        }
        refreshTile()
    }

    override fun onStopListening() {
        vpnStatusReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        if (VpnController.readVpnRunning(this)) {
            updateTileState(
                state = Tile.STATE_UNAVAILABLE,
                subtitle = getString(R.string.quick_settings_tile_status_disconnecting),
                iconRes = R.drawable.pause_light,
            )
            VpnController.stopVpn(this)
            VpnController.requestTileRefresh(this)
            return
        }

        when (VpnController.startVpnWithLastProfile(this)) {
            VpnController.StartResult.STARTED -> {
                updateTileState(
                    state = Tile.STATE_UNAVAILABLE,
                    subtitle = getString(R.string.quick_settings_tile_status_connecting),
                    iconRes = R.drawable.play_light,
                )
                VpnController.requestTileRefresh(this)
            }
            VpnController.StartResult.MISSING_START_SNAPSHOT,
            VpnController.StartResult.NEED_PERMISSION -> launchMainActivity()
        }
    }

    private fun refreshTile() {
        val running = VpnController.readVpnRunning(this)
        updateTileForVpnStatus(running)
    }

    private fun launchMainActivity() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun updateTileState(
        state: Int,
        subtitle: String,
        iconRes: Int,
    ) {
        val tile = qsTile ?: return
        tile.label = getString(R.string.quick_settings_tile_label)
        tile.subtitle = subtitle
        tile.state = state
        tile.icon = Icon.createWithResource(this, iconRes)
        tile.updateTile()
    }

    private fun updateTileForVpnStatus(running: Boolean) {
        val hasStartSnapshot = VpnController.hasStartSnapshot(this)
        updateTileState(
            state = if (running) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE,
            subtitle = when {
                running -> getString(R.string.quick_settings_tile_status_connected)
                hasStartSnapshot -> getString(R.string.quick_settings_tile_status_disconnected)
                else -> getString(R.string.quick_settings_tile_status_open_app)
            },
            iconRes = if (running) R.drawable.pause_light else R.drawable.play_light,
        )
    }
}
