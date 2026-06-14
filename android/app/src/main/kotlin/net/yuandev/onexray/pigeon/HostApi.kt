package net.yuandev.onexray.pigeon

import android.Manifest
import android.app.Activity.RESULT_OK
import android.content.Context
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
import net.yuandev.onexray.vpn.VpnController
import kotlin.time.Duration.Companion.seconds

class AppHostApi(
    private val context: Context,
) : BridgeHostApi {
    private val activity = context as FragmentActivity
    private val prepareResult =
        activity.registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
            val callback = permissionCallback
            permissionCallback = null
            if (it.resultCode == RESULT_OK) {
                callback?.invoke(androidPermissionGranted())
            } else {
                callback?.invoke(androidPermissionDenied())
                onVpnStatusChanged(false)
            }
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
        onVpnStatusChanged(VpnController.readVpnRunning(context))
    }

    fun onDestroy() {
        scope.cancel()
    }

    private var permissionCallback: ((PlatformPermissionResult) -> Unit)? = null

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun getTunFilesDir(callback: (Result<String>) -> Unit) {
        val dirPath = context.filesDir.path
        callback(Result.success(dirPath))
    }

    override fun readVpnStatus(callback: (Result<NativeVpnCommandResult>) -> Unit) {
        scope.launch {
            flutterApi?.refreshVpnStatus()
            callback(Result.success(commandSuccess(queryPermissionNow())))
        }
    }

    override fun startVpn(callback: (Result<NativeVpnCommandResult>) -> Unit) {
        XLog.d("AppHostApi: startVpn called")
        scope.launch {
            val permission = queryPermissionNow()
            if (permission.state != PlatformPermissionState.GRANTED) {
                callback(Result.success(waitingForPermission(permission)))
                return@launch
            }
            flutterApi?.vpnStatusChanged(VpnStatus.CONNECTING)
            val intent = VpnController.buildStartIntent(context)
            context.startForegroundService(intent)
            callback(Result.success(commandSuccess(permission)))
        }
    }

    override fun stopVpn(callback: (Result<NativeVpnCommandResult>) -> Unit) {
        XLog.d("AppHostApi: stopVpn called")
        scope.launch {
            val vpnStatus = flutterApi?.readVpnStatus()
            if (vpnStatus == null) {
                callback(Result.success(commandSuccess(queryPermissionNow())))
                return@launch
            }
            when (vpnStatus) {
                VpnStatus.DISCONNECTED -> flutterApi?.refreshVpnStatus()
                VpnStatus.CONNECTED -> {
                    flutterApi?.vpnStatusChanged(VpnStatus.DISCONNECTING)
                    val intent = VpnController.buildStopIntent(context)
                    context.startService(intent)
                }

                else -> XLog.d("stopVpn unknown VpnStatus $vpnStatus")
            }

            callback(Result.success(commandSuccess(queryPermissionNow())))
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

    override fun queryPlatformPermission(callback: (Result<PlatformPermissionResult>) -> Unit) {
        scope.launch {
            callback(Result.success(queryPermissionNow()))
        }
    }

    override fun requestPlatformPermission(callback: (Result<PlatformPermissionResult>) -> Unit) {
        scope.launch {
            val permission = queryPermissionNow()
            if (permission.state == PlatformPermissionState.GRANTED) {
                callback(Result.success(permission))
                return@launch
            }
            val prepare = VpnService.prepare(context)
            if (prepare == null) {
                callback(Result.success(androidPermissionGranted()))
                return@launch
            }
            if (permissionCallback != null) {
                callback(
                    Result.success(
                        PlatformPermissionResult(
                            PlatformPermissionKind.ANDROID_VPN,
                            PlatformPermissionState.AWAITING_USER_APPROVAL,
                            "Android VPN permission is already pending.",
                        )
                    )
                )
                return@launch
            }
            permissionCallback = { result ->
                callback(Result.success(result))
            }
            activity.runOnUiThread {
                prepareResult.launch(prepare)
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
    override fun useSystemExtension(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(false))
    }

    //ios
    override fun setAppIcon(appIcon: String, callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun getCurrentAppIcon(callback: (Result<String>) -> Unit) {
        callback(Result.success(""))
    }

    private fun queryPermissionNow(): PlatformPermissionResult {
        val prepare = VpnService.prepare(context)
        return if (prepare == null) {
            androidPermissionGranted()
        } else {
            PlatformPermissionResult(
                PlatformPermissionKind.ANDROID_VPN,
                PlatformPermissionState.NOT_DETERMINED,
                null,
            )
        }
    }

    private fun androidPermissionGranted() = PlatformPermissionResult(
        PlatformPermissionKind.ANDROID_VPN,
        PlatformPermissionState.GRANTED,
        null,
    )

    private fun androidPermissionDenied() = PlatformPermissionResult(
        PlatformPermissionKind.ANDROID_VPN,
        PlatformPermissionState.DENIED,
        null,
    )

    private fun commandSuccess(permission: PlatformPermissionResult) = NativeVpnCommandResult(
        NativeVpnCommandState.SUCCESS,
        permission,
        null,
    )

    private fun waitingForPermission(permission: PlatformPermissionResult) = NativeVpnCommandResult(
        NativeVpnCommandState.WAITING_FOR_PLATFORM_PERMISSION,
        permission,
        null,
    )
}
