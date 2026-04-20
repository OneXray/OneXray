package net.yuandev.onexray.pigeon

import android.Manifest
import android.app.Activity.RESULT_OK
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.FragmentActivity
import com.elvishew.xlog.XLog
import com.hjq.permissions.Permission
import com.hjq.permissions.XXPermissions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import libXray.LibXray
import net.yuandev.onexray.vpn.OneVpnService
import kotlin.time.Duration.Companion.seconds

class AppHostApi(
    private val context: Context,
) : BridgeHostApi {
    private val prepareResult =
        (context as FragmentActivity).registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
            if (it.resultCode == RESULT_OK) {
                if (startVpnIntent != null) {
                    context.startForegroundService(startVpnIntent)
                    startVpnIntent = null
                }
            } else {
                onVpnStatusChanged(false)
            }
        }


    private fun readVpnRunning(): Boolean {
        val connectivityManager = context.getSystemService(ConnectivityManager::class.java)
        val network = connectivityManager.activeNetwork ?: return false
        val caps = connectivityManager.getNetworkCapabilities(network) ?: return false
        if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
            return false
        }
        val linkProperties = connectivityManager.getLinkProperties(network) ?: return false
        val name = linkProperties.interfaceName ?: return false
        if (!name.startsWith("tun")) {
            return false
        }

        var ipv4Match = false
        var ipv6Match = false
        val addresses = linkProperties.linkAddresses
        for (address in addresses) {
            address.address?.hostAddress?.let { host ->
                if (host == OneVpnService.IPV4_ADDRESS) {
                    ipv4Match = true
                }
                if (host == OneVpnService.IPV6_ADDRESS) {
                    ipv6Match = true
                }
            }
        }
        return ipv4Match || ipv6Match
    }

    fun onVpnStatusChanged(running: Boolean) {
        XLog.d("AppHostApi: onVpnStatusChanged running=$running")
        scope.launch {
            if (running) {
                flutterApi?.vpnStatusChanged(VpnStatus.CONNECTED)
            } else {
                delay(2.seconds)
                flutterApi?.vpnStatusChanged(VpnStatus.DISCONNECTED)
            }
        }
    }

    private var flutterApi: AppFlutterApi? = null

    fun onInit(api: AppFlutterApi) {
        XLog.init()
        flutterApi = api
        onVpnStatusChanged(readVpnRunning())
    }

    fun onDestroy() {
        scope.cancel()
    }

    private var startVpnIntent: Intent? = null

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun getTunFilesDir(callback: (Result<String>) -> Unit) {
        val dirPath = context.filesDir.path
        callback(Result.success(dirPath))
    }

    override fun readVpnStatus(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            flutterApi?.refreshVpnStatus()
            callback(Result.success(Unit))
        }
    }

    override fun startVpn(callback: (Result<Unit>) -> Unit) {
        XLog.d("AppHostApi: startVpn called")
        scope.launch {
            flutterApi?.vpnStatusChanged(VpnStatus.CONNECTING)
            val intent = Intent(context, OneVpnService::class.java)
            intent.action = OneVpnService.ACTION_START
            val prepare = VpnService.prepare(context)
            if (prepare != null) {
                startVpnIntent = intent
                prepareResult.launch(prepare)
            } else {
                context.startForegroundService(intent)
            }
            callback(Result.success(Unit))
        }
    }

    override fun stopVpn(callback: (Result<Unit>) -> Unit) {
        XLog.d("AppHostApi: stopVpn called")
        scope.launch {
            val vpnStatus = flutterApi?.readVpnStatus() ?: return@launch
            when (vpnStatus) {
                VpnStatus.DISCONNECTED -> flutterApi?.refreshVpnStatus()
                VpnStatus.CONNECTED -> {
                    flutterApi?.vpnStatusChanged(VpnStatus.DISCONNECTING)
                    val intent = Intent(context, OneVpnService::class.java)
                    intent.action = OneVpnService.ACTION_STOP
                    context.startService(intent)
                }

                else -> XLog.d("stopVpn unknown VpnStatus $vpnStatus")
            }

            callback(Result.success(Unit))
        }
    }

    override fun getFreePorts(num: Long, callback: (Result<String>) -> Unit) {
        scope.launch {
            val res = LibXray.getFreePorts(num)
            callback(Result.success(res))
        }
    }

    override fun convertShareLinksToXrayJson(
        base64Text: String,
        callback: (Result<String>) -> Unit
    ) {
        scope.launch {
            val res = LibXray.convertShareLinksToXrayJson(base64Text)
            callback(Result.success(res))
        }
    }

    override fun convertXrayJsonToShareLinks(
        base64Text: String,
        callback: (Result<String>) -> Unit
    ) {
        scope.launch {
            val res = LibXray.convertXrayJsonToShareLinks(base64Text)
            callback(Result.success(res))
        }
    }

    override fun countGeoData(base64Text: String, callback: (Result<String>) -> Unit) {
        scope.launch {
            val res = LibXray.countGeoData(base64Text)
            callback(Result.success(res))
        }
    }

    override fun readGeoFiles(base64Text: String, callback: (Result<String>) -> Unit) {
        scope.launch {
            val res = LibXray.readGeoFiles(base64Text)
            callback(Result.success(res))
        }
    }

    override fun ping(base64Text: String, callback: (Result<String>) -> Unit) {
        scope.launch {
            val res = LibXray.ping(base64Text)
            callback(Result.success(res))
        }
    }


    override fun testXray(base64Text: String, callback: (Result<String>) -> Unit) {
        scope.launch {
            val res = LibXray.testXray(base64Text)
            callback(Result.success(res))
        }
    }

    override fun runXray(base64Text: String, callback: (Result<String>) -> Unit) {
        scope.launch {
            val res = LibXray.runXray(base64Text)
            callback(Result.success(res))
        }
    }

    override fun stopXray(callback: (Result<String>) -> Unit) {
        scope.launch {
            val res = LibXray.stopXray()
            callback(Result.success(res))
        }
    }

    override fun xrayVersion(callback: (Result<String>) -> Unit) {
        scope.launch {
            val res = LibXray.xrayVersion()
            callback(Result.success(res))
        }
    }


    override fun buildMphCache(base64Text: String, callback: (Result<String>) -> Unit) {
        scope.launch {
            val res = LibXray.buildMphCache(base64Text)
            callback(Result.success(res))
        }
    }

    // android
    override fun checkVpnPermission(callback: (Result<Boolean>) -> Unit) {
        scope.launch {
            val permissions = mutableListOf<String>()
            permissions.add(Manifest.permission.INTERNET)
            permissions.add(Manifest.permission.ACCESS_NETWORK_STATE)
            permissions.add(Manifest.permission.FOREGROUND_SERVICE)

            // android 13, level 33
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }
            // android 14, level 34
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                permissions.add(Manifest.permission.FOREGROUND_SERVICE_SPECIAL_USE)
            }
            XXPermissions.with(context)
                .permission(permissions)
                .request { _, allGranted ->
                    callback(Result.success(allGranted))
                }
        }
    }


    override fun getInstalledApps(callback: (Result<List<AndroidAppInfo>>) -> Unit) {
        scope.launch {
            checkInstalledAppPermission {
                if (it) {
                    val packageManager = context.packageManager
                    val installedApps = packageManager.getInstalledApplications(0)
                    val apps = mutableListOf<AndroidAppInfo>()
                    for (info in installedApps) {
                        val appInfo =
                            AndroidAppInfo(
                                packageManager.getApplicationLabel(info).toString(),
                                info.packageName,
                            )
                        apps.add(appInfo)
                    }
                    callback(Result.success(apps))
                } else {
                    callback(Result.success(listOf()))
                }
            }
        }
    }

    private fun checkInstalledAppPermission(callback: (Boolean) -> Unit) {
        // android 11, level 30
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val permissions = mutableListOf<String>()
            permissions.add(Manifest.permission.QUERY_ALL_PACKAGES)
            permissions.add(Permission.GET_INSTALLED_APPS)
            XXPermissions.with(context)
                .permission(permissions)
                .request { _, allGranted ->
                    callback(allGranted)
                }
        } else {
            callback(true)
        }
    }

    // macOS

    //ios
    override fun setAppIcon(appIcon: String, callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun getCurrentAppIcon(callback: (Result<String>) -> Unit) {
        callback(Result.success(""))
    }
}