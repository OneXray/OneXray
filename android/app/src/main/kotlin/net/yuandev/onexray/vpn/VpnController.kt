package net.yuandev.onexray.vpn

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.service.quicksettings.TileService
import androidx.core.content.ContextCompat
import net.yuandev.onexray.tile.OneQuickSettingsTileService
import java.io.File
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.SocketException

object VpnController {
    private const val startSnapshotRelativePath = "run/start.json"
    private val vpnAddresses by lazy {
        setOf(
            InetAddress.getByName(OneVpnService.IPV4_ADDRESS),
            InetAddress.getByName(OneVpnService.IPV6_ADDRESS),
        )
    }

    enum class StartResult {
        STARTED,
        MISSING_START_SNAPSHOT,
        NEED_PERMISSION,
    }

    fun readVpnRunning(context: Context): Boolean {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return false
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                if (!isVpnInterfaceName(networkInterface.name) || !networkInterface.isUp) {
                    continue
                }
                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    if (matchesVpnAddress(addresses.nextElement())) {
                        return true
                    }
                }
            }
        } catch (_: SocketException) {
            return false
        }

        return false
    }

    fun hasStartSnapshot(context: Context): Boolean =
        File(context.filesDir, startSnapshotRelativePath).isFile

    fun buildStartIntent(context: Context): Intent =
        Intent(context, OneVpnService::class.java).apply {
            action = OneVpnService.ACTION_START
        }

    fun buildStopIntent(context: Context): Intent =
        Intent(context, OneVpnService::class.java).apply {
            action = OneVpnService.ACTION_STOP
        }

    fun startVpnWithLastProfile(context: Context): StartResult {
        if (!hasStartSnapshot(context)) {
            return StartResult.MISSING_START_SNAPSHOT
        }
        if (VpnService.prepare(context) != null) {
            return StartResult.NEED_PERMISSION
        }
        ContextCompat.startForegroundService(context, buildStartIntent(context))
        return StartResult.STARTED
    }

    fun stopVpn(context: Context) {
        context.startService(buildStopIntent(context))
    }

    fun requestTileRefresh(context: Context) {
        TileService.requestListeningState(
            context,
            ComponentName(context, OneQuickSettingsTileService::class.java)
        )
    }

    private fun isVpnInterfaceName(name: String?): Boolean =
        !name.isNullOrBlank() && name.startsWith("tun")

    private fun matchesVpnAddress(address: InetAddress?): Boolean =
        address != null && vpnAddresses.any { it == address }
}
