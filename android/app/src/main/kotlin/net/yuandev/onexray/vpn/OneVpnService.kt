package net.yuandev.onexray.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Base64
import com.elvishew.xlog.XLog
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import libXray.DialerController
import libXray.LibXray
import net.yuandev.onexray.MainActivity
import net.yuandev.onexray.R
import net.yuandev.onexray.pigeon.PerAppVPNMode
import net.yuandev.onexray.pigeon.StartVpnRequest
import net.yuandev.onexray.pigeon.TunJson
import org.json.JSONObject
import java.io.File
import java.util.concurrent.atomic.AtomicInteger


class OneVpnService : VpnService() {
    companion object {
        const val ACTION_START: String = "vpn_start"
        const val ACTION_STOP: String = "vpn_stop"

        const val IPV4_ADDRESS = "198.18.0.1"
        const val IPV6_ADDRESS = "fc00::1"
        const val ACTION_VPN_STATUS: String = "net.yuandev.onexray.VPN_STATUS"
        const val EXTRA_RUNNING: String = "running"
        const val NOTIFICATION_OPEN_REQUEST_CODE = 1
        const val NOTIFICATION_STOP_REQUEST_CODE = 2
    }

    @Volatile
    private var tunnel: ParcelFileDescriptor? = null

    private val tunMtu = 1500
    @Volatile
    private var running = false
    private val startGeneration = AtomicInteger(0)

    private fun sendStatusBroadcast(running: Boolean) {
        val intent = Intent(ACTION_VPN_STATUS).apply {
            setPackage(packageName) // 限定仅本包接收
            putExtra(EXTRA_RUNNING, running)
        }
        sendBroadcast(intent)
        VpnController.requestTileRefresh(this)
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    class VPNController : DialerController {
        var vpn: OneVpnService? = null
        override fun protectFd(p0: Long): Boolean {
            val socket = p0.toInt()
            vpn?.protect(socket)
            return true
        }
    }

    private var controllerInit = false
    private val controller = VPNController()
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        initService()
        XLog.d("OneVpnService: onStartCommand ${intent?.action}")
        if (intent != null && intent.action == ACTION_STOP) {
            XLog.d("OneVpnService: onStartCommand $ACTION_STOP running=$running")
            if (running || tunnel != null) {
                stopTun()
            } else {
                stopForeground(STOP_FOREGROUND_REMOVE)
                sendStatusBroadcast(false)
                stopSelf()
            }
            return START_NOT_STICKY
        }
        if (intent != null && intent.action == ACTION_START) {
            XLog.d("OneVpnService: onStartCommand $ACTION_START running=$running")
            if (!running && tunnel == null) {
                startTun(startId)
            }
            return START_NOT_STICKY
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }

    private fun initService() {
        XLog.init()
    }

    private fun startTun(startId: Int) {
        XLog.d("OneVpnService: startTun $startId")
        if (tunnel != null) {
            XLog.d("OneVpnService: startTun ignored because tunnel already exists")
            return
        }
        val generation = startGeneration.incrementAndGet()

        showNotification(startId)

        val model = try {
            readStartRequest()
        } catch (e: Exception) {
            failStart("OneVpnService: startTun failed to read/parse start.json", e, generation)
            return
        }

        try {
            runTun(model, generation)
        } catch (e: Exception) {
            failStart("OneVpnService: startTun failed to establish tunnel", e, generation)
        }
    }

    private fun readStartRequest(): StartVpnRequest {
        val runPath = File(this.filesDir.path, "run")
        val file = File(runPath.path, "start.json")
        val data = file.readText()
        val decoder = Json {
            explicitNulls = false
            ignoreUnknownKeys = true
        }
        return decoder.decodeFromString<StartVpnRequest>(data)
    }

    private fun stopTun() {
        startGeneration.incrementAndGet()
        if (tunnel == null) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            controller.vpn = null
            running = false
            sendStatusBroadcast(false)
            stopSelf()
            return
        }
        XLog.d("OneVpnService: stopTun")
        stopForeground(STOP_FOREGROUND_REMOVE)
        LibXray.stopXray()
        try {
            tunnel?.close()
        } catch (e: Exception) {
            XLog.d("OneVpnService: stopTun close tunnel exception")
            XLog.d(e)
        }
        tunnel = null
        controller.vpn = null
        running = false
        sendStatusBroadcast(false)
    }

    private fun failStart(message: String, error: Exception, generation: Int? = null) {
        if (generation != null && generation != startGeneration.get()) {
            XLog.d("$message ignored for stale start generation=$generation")
            XLog.d(error)
            return
        }
        startGeneration.incrementAndGet()
        XLog.e(message, error)
        stopForeground(STOP_FOREGROUND_REMOVE)
        try {
            LibXray.stopXray()
        } catch (e: Exception) {
            XLog.d("OneVpnService: failStart stopXray exception")
            XLog.d(e)
        }
        try {
            tunnel?.close()
        } catch (e: Exception) {
            XLog.d("OneVpnService: failStart close tunnel exception")
            XLog.d(e)
        }
        tunnel = null
        controller.vpn = null
        running = false
        sendStatusBroadcast(false)
        stopSelf()
    }

    private fun showNotification(startId: Int) {
        val notification = makeNotification()
        var notificationId = startId
        if (notificationId <= 0) {
            notificationId = 1
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(notificationId, notification)
        }
    }

    private fun makeNotification(): Notification {
        val appName = getString(R.string.quick_settings_tile_label)
        val channelId = "net.yuandev.onexray"
        val channel = NotificationChannel(
            channelId,
            appName,
            NotificationManager.IMPORTANCE_DEFAULT
        )
        channel.description = appName
        val notificationManager = getSystemService(
            NotificationManager::class.java
        )
        notificationManager.createNotificationChannel(channel)

        val openPendingIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_OPEN_REQUEST_CODE,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stopPendingIntent = PendingIntent.getService(
            this,
            NOTIFICATION_STOP_REQUEST_CODE,
            Intent(this, OneVpnService::class.java).apply {
                action = ACTION_STOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return Notification.Builder(this, channelId)
            .setContentTitle(appName)
            .setContentText(getString(R.string.notification_vpn_connected))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(openPendingIntent)
            .setTicker(appName)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, R.mipmap.ic_launcher),
                    getString(R.string.notification_action_open),
                    openPendingIntent
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, R.drawable.pause_light),
                    getString(R.string.notification_action_disconnect),
                    stopPendingIntent
                ).build()
            )
            .build()
    }

    private fun runTun(
        request: StartVpnRequest,
        generation: Int,
    ) {
        if (generation != startGeneration.get() || tunnel != null) {
            return
        }
        XLog.d("OneVpnService: runTun tunnel = null")
        val builder = Builder()
        val tun = requireNotNull(request.tun) { "missing TUN config" }
        setPerAppVpn(tun, builder)
        setIPAndDns(tun, builder)

        val establishedTunnel = builder.establish()
            ?: throw IllegalStateException("failed to establish VPN tunnel")
        if (generation != startGeneration.get()) {
            establishedTunnel.close()
            return
        }
        tunnel = establishedTunnel

        XLog.d("OneVpnService: runTun tunnel = ${tunnel?.fd}")

        val coreBase64Text = requireNotNull(request.coreBase64Text) {
            "missing Xray run request"
        }
        controller.vpn = this
        runXray(coreBase64Text, establishedTunnel, generation)
    }

    private fun setIPAndDns(tun: TunJson, builder: Builder) {
        builder.addAddress(IPV4_ADDRESS, 32)
            .addRoute("0.0.0.0", 0)
            .setMtu(tunMtu)
        tun.tunDnsIPv4?.let {
            builder.addDnsServer(it)
        }

        tun.enableIPv6?.let {
            if (it) {
                builder.addAddress(IPV6_ADDRESS, 128)
                    .addRoute("::", 0)
                tun.tunDnsIPv6?.let { dnsIPv6 ->
                    builder.addDnsServer(dnsIPv6)
                }
            }
        }
    }

    private fun setPerAppVpn(tun: TunJson, builder: Builder) {
        tun.perAppVPNMode?.let {
            when (it) {
                PerAppVPNMode.ALLOW -> addAllowedApplication(tun.allowAppList, builder)
                PerAppVPNMode.DISALLOW -> addDisallowedApplication(tun.disallowAppList, builder)
            }
        }
    }

    private fun addAllowedApplication(appList: List<String>?, builder: Builder) {
        appList?.let {
            if (it.isNotEmpty()) {
                for (appPackage in it) {
                    try {
                        packageManager.getPackageInfo(appPackage, 0)
                        builder.addAllowedApplication(appPackage)
                    } catch (_: PackageManager.NameNotFoundException) {
                    }
                }
            }
        }
    }

    private fun addDisallowedApplication(appList: List<String>?, builder: Builder) {
        appList?.let {
            if (it.isNotEmpty()) {
                for (appPackage in it) {
                    try {
                        packageManager.getPackageInfo(appPackage, 0)
                        builder.addDisallowedApplication(appPackage)
                    } catch (_: PackageManager.NameNotFoundException) {
                    }
                }
            }
        }
    }

    private fun initController() {
        if (controllerInit) {
            return
        }
        LibXray.registerDialerController(controller)
        LibXray.registerListenerController(controller)
        controllerInit = true
    }

    private fun runXray(
        coreBase64Text: String,
        establishedTunnel: ParcelFileDescriptor,
        generation: Int,
    ) {
        scope.launch {
            try {
                initController()
                if (generation != startGeneration.get() || tunnel !== establishedTunnel) {
                    return@launch
                }
                LibXray.setTunFd(establishedTunnel.fd)
                val result = LibXray.runXray(coreBase64Text)
                validateRunXrayResult(result)
                if (generation != startGeneration.get() || tunnel !== establishedTunnel) {
                    XLog.d("OneVpnService: stale runXray result ignored")
                    if (tunnel == null) {
                        LibXray.stopXray()
                    }
                    return@launch
                }
                XLog.d("TProxyStartService: runXray result=$result")
                running = true
                sendStatusBroadcast(true)
            } catch (e: Exception) {
                failStart("OneVpnService: runXray failed", e, generation)
            }
        }
    }

    private fun validateRunXrayResult(result: String) {
        val decoded = String(Base64.decode(result, Base64.DEFAULT), Charsets.UTF_8)
        val response = JSONObject(decoded)
        if (!response.optBoolean("success", false)) {
            val error = response.optString("error", "runXray failed")
            throw IllegalStateException(error)
        }
    }
}
