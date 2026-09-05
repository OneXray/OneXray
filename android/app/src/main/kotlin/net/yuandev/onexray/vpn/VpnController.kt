package net.yuandev.onexray.vpn

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutManager
import android.service.quicksettings.TileService
import androidx.core.content.ContextCompat
import com.elvishew.xlog.XLog
import net.yuandev.onexray.MainActivity
import net.yuandev.onexray.tile.OneQuickSettingsTileService
import java.io.File
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.SocketException

object VpnController {
    private const val stopRequestRelativePath = "run/vpn.stop"
    private val vpnAddresses by lazy {
        setOf(
            InetAddress.getByName(OneVpnService.IPV4_ADDRESS),
            InetAddress.getByName(OneVpnService.IPV6_ADDRESS),
        )
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

    fun buildShortcutStartIntent(context: Context): Intent {
        // Reuse the plugin-created Intent so the App's coordinator handles
        // connection preparation; do not replay a previously saved plan.
        val shortcutIntent = try {
            context.getSystemService(ShortcutManager::class.java)
                ?.dynamicShortcuts?.firstOrNull { it.id == "startVpn" }
                ?.intent?.let { Intent(it) }
        } catch (_: RuntimeException) {
            XLog.w("VpnController: unable to read start shortcut; opening App")
            null
        }
        return (shortcutIntent ?: Intent(context, MainActivity::class.java)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
    }

    fun buildStartIntent(context: Context): Intent =
        Intent(context, OneVpnService::class.java).apply {
            action = OneVpnService.ACTION_START
        }

    fun startVpn(context: Context): Boolean {
        if (!clearStopRequest(context)) {
            return false
        }
        return try {
            ContextCompat.startForegroundService(context, buildStartIntent(context))
            true
        } catch (error: RuntimeException) {
            XLog.e("VpnController: failed to start VPN service", error)
            false
        }
    }

    fun stopVpn(context: Context): Boolean {
        val markerWritten = writeStopRequest(context)
        val broadcastSent = try {
            context.sendBroadcast(
                Intent(OneVpnService.ACTION_STOP_REQUEST).setPackage(context.packageName)
            )
            true
        } catch (error: RuntimeException) {
            XLog.e("VpnController: failed to broadcast VPN stop", error)
            false
        }
        return markerWritten && broadcastSent
    }

    fun consumeStopRequest(context: Context): Boolean {
        val file = stopRequestFile(context)
        return try {
            if (!file.isFile) {
                false
            } else {
                if (!file.delete()) {
                    XLog.w("VpnController: failed to consume VPN stop marker")
                }
                true
            }
        } catch (error: Exception) {
            XLog.e("VpnController: failed to read VPN stop marker", error)
            true
        }
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

    private fun stopRequestFile(context: Context): File =
        File(context.filesDir, stopRequestRelativePath)

    private fun writeStopRequest(context: Context): Boolean = try {
        val file = stopRequestFile(context)
        val parent = file.parentFile
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            XLog.e("VpnController: failed to create VPN run directory")
            false
        } else {
            file.writeText("stop")
            true
        }
    } catch (error: Exception) {
        XLog.e("VpnController: failed to write VPN stop marker", error)
        false
    }

    private fun clearStopRequest(context: Context): Boolean = try {
        val file = stopRequestFile(context)
        !file.exists() || file.delete().also { deleted ->
            if (!deleted) {
                XLog.e("VpnController: failed to clear VPN stop marker")
            }
        }
    } catch (error: Exception) {
        XLog.e("VpnController: failed to clear VPN stop marker", error)
        false
    }
}
