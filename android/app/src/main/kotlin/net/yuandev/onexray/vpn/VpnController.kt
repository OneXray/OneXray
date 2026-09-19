package net.yuandev.onexray.vpn

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutManager
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.TileService
import android.widget.Toast
import androidx.core.content.ContextCompat
import com.elvishew.xlog.XLog
import net.yuandev.onexray.MainActivity
import net.yuandev.onexray.R
import net.yuandev.onexray.pigeon.PlatformPermissionKind
import net.yuandev.onexray.pigeon.PlatformPermissionResult
import net.yuandev.onexray.pigeon.PlatformPermissionState
import net.yuandev.onexray.tile.OneQuickSettingsTileService
import java.io.File
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.SocketException

object VpnController {
    enum class SavedStartResult { STARTED, OPEN_APP, FAILED }

    var lastError: String? = null
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
        // Missing configuration or permission still goes through the App coordinator.
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

    fun queryPermission(context: Context): PlatformPermissionResult {
        val kind = when {
            VpnService.prepare(context) != null -> PlatformPermissionKind.ANDROID_VPN
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.CINNAMON_BUN &&
                context.checkSelfPermission(Manifest.permission.ACCESS_LOCAL_NETWORK) !=
                PackageManager.PERMISSION_GRANTED -> PlatformPermissionKind.ANDROID_LOCAL_NETWORK
            else -> return PlatformPermissionResult(
                PlatformPermissionKind.ANDROID_VPN, PlatformPermissionState.GRANTED, null,
            )
        }
        return PlatformPermissionResult(kind, PlatformPermissionState.NOT_DETERMINED, null)
    }

    fun startFile(context: Context): File = File(context.filesDir, "run/start.json")

    fun startSavedVpn(context: Context): SavedStartResult {
        try {
            if (queryPermission(context).state != PlatformPermissionState.GRANTED) {
                return SavedStartResult.OPEN_APP
            }
            SavedVpnConfig.read(startFile(context))
        } catch (_: Exception) {
            return SavedStartResult.OPEN_APP
        }
        return if (startVpn(context, reuseConfiguration = true)) SavedStartResult.STARTED
            else SavedStartResult.FAILED
    }

    fun startVpn(context: Context, reuseConfiguration: Boolean = false): Boolean {
        lastError = null
        if (!clearStopRequest(context)) {
            lastError = "Unable to clear the VPN stop marker."
            return false
        }
        return try {
            val intent = buildStartIntent(context).putExtra(OneVpnService.EXTRA_REUSE_CONFIGURATION, reuseConfiguration)
            ContextCompat.startForegroundService(context, intent)
            true
        } catch (error: RuntimeException) {
            XLog.e("VpnController: failed to start VPN service", error)
            lastError = error.message ?: error.toString()
            false
        }
    }

    fun reportStartFailure(context: Context, reason: String?) {
        val title = context.getString(R.string.notification_vpn_start_failed)
        val text = reason?.takeIf { it.isNotBlank() } ?: title
        Toast.makeText(context, text, Toast.LENGTH_SHORT).show()
        try {
            val manager = context.getSystemService(NotificationManager::class.java)
            val channel = "net.yuandev.onexray"
            manager.createNotificationChannel(NotificationChannel(
                channel, context.getString(R.string.quick_settings_tile_label), NotificationManager.IMPORTANCE_DEFAULT,
            ))
            val openApp = PendingIntent.getActivity(
                context, 3, Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            manager.notify(OneVpnService.NOTIFICATION_ID, Notification.Builder(context, channel)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setContentIntent(openApp)
                .setAutoCancel(true)
                .build())
        } catch (error: Exception) {
            // Notification permission must not change the VPN result or open the App.
            XLog.e("Unable to show VPN start failure", error)
        }
    }

    fun stopVpn(context: Context): Boolean {
        lastError = null
        val markerWritten = writeStopRequest(context)
        val broadcastSent = try {
            context.sendBroadcast(
                Intent(OneVpnService.ACTION_STOP_REQUEST).setPackage(context.packageName)
            )
            true
        } catch (error: RuntimeException) {
            XLog.e("VpnController: failed to broadcast VPN stop", error)
            lastError = error.message ?: error.toString()
            false
        }
        if (!markerWritten && lastError == null) lastError = "Unable to write the VPN stop marker."
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
