package net.yuandev.onexray.vpn

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.service.quicksettings.TileService
import androidx.core.content.ContextCompat
import com.elvishew.xlog.XLog
import net.yuandev.onexray.tile.OneQuickSettingsTileService
import java.io.File
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.SocketException

object VpnController {
    private const val startSnapshotRelativePath = "run/start.json"
    private const val stopRequestRelativePath = "run/vpn.stop"
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
        FAILED,
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

    fun startVpnWithLastProfile(context: Context): StartResult {
        if (!hasStartSnapshot(context)) {
            return StartResult.MISSING_START_SNAPSHOT
        }
        if (VpnService.prepare(context) != null) {
            return StartResult.NEED_PERMISSION
        }
        return if (startVpn(context)) StartResult.STARTED else StartResult.FAILED
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
