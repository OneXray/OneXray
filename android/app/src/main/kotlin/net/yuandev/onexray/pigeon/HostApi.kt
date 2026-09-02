package net.yuandev.onexray.pigeon

import android.Manifest
import android.app.Activity.RESULT_OK
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
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
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import libXray.LibXray
import net.yuandev.onexray.vpn.VpnController
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicInteger
import kotlin.time.Duration.Companion.seconds

class AppHostApi(
    private val context: Context,
) : BridgeHostApi {
    private val vpnStatusGeneration = AtomicInteger(0)
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
        val generation = vpnStatusGeneration.incrementAndGet()
        scope.launch {
            if (running) {
                flutterApi?.vpnStatusChanged(VpnStatus.CONNECTED)
            } else {
                delay(2.seconds)
                if (generation == vpnStatusGeneration.get()) {
                    flutterApi?.vpnStatusChanged(VpnStatus.DISCONNECTED)
                }
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
    private val invokeMutex = Mutex()

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
            if (VpnController.startVpn(context)) {
                callback(Result.success(commandSuccess(permission)))
            } else {
                flutterApi?.vpnStatusChanged(VpnStatus.DISCONNECTED)
                callback(Result.success(commandFailed(permission)))
            }
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
                VpnStatus.CONNECTING, VpnStatus.CONNECTED, VpnStatus.DISCONNECTING -> {
                    flutterApi?.vpnStatusChanged(VpnStatus.DISCONNECTING)
                    if (!VpnController.stopVpn(context)) {
                        flutterApi?.refreshVpnStatus()
                    }
                }
            }

            callback(Result.success(commandSuccess(queryPermissionNow())))
        }
    }

    override fun invoke(requestJson: String, callback: (Result<String>) -> Unit) {
        scope.launch {
            // Temporary cores share process-global Xray state. The VPN runs in :native.
            invokeMutex.withLock {
                callback(runCatching { LibXray.invoke(requestJson) })
            }
        }
    }

    override fun readRuntimeState(removeSessionIds: List<String>, callback: (Result<String?>) -> Unit) {
        callback(Result.failure(UnsupportedOperationException("runtimeStateRequiresSystemExtension")))
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

    override fun getAppIcon(packageName: String, callback: (Result<ByteArray?>) -> Unit) {
        scope.launch {
            callback(Result.success(loadAppIconBytes(packageName)))
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

    private fun loadAppIconBytes(packageName: String): ByteArray? {
        return try {
            val drawable = context.packageManager.getApplicationIcon(packageName)
            val bitmap = Bitmap.createBitmap(ICON_SIZE_PX, ICON_SIZE_PX, Bitmap.Config.ARGB_8888)
            try {
                drawable.setBounds(0, 0, ICON_SIZE_PX, ICON_SIZE_PX)
                drawable.draw(Canvas(bitmap))
                val stream = ByteArrayOutputStream()
                if (bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                    stream.toByteArray()
                } else {
                    null
                }
            } finally {
                bitmap.recycle()
            }
        } catch (e: Exception) {
            XLog.d("AppHostApi: getAppIcon failed for $packageName: $e")
            null
        }
    }

    // macOS
    override fun appleVpnCapabilities(callback: (Result<AppleVpnCapabilities>) -> Unit) {
        callback(Result.success(AppleVpnCapabilities(false, false)))
    }

    override fun readLog(planId: String, access: Boolean, offset: Long, limit: Long, callback: (Result<NativeLogChunk?>) -> Unit) {
        callback(Result.failure(UnsupportedOperationException("System Extension logs are Apple-only")))
    }

    override fun useSystemExtension(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(false))
    }

    override fun queryLaunchAtLogin(callback: (Result<NativeLaunchAtLoginResult>) -> Unit) {
        callback(
            Result.success(
                NativeLaunchAtLoginResult(
                    NativeLaunchAtLoginState.UNAVAILABLE,
                    null,
                )
            )
        )
    }

    override fun setLaunchAtLogin(
        enabled: Boolean,
        callback: (Result<NativeLaunchAtLoginResult>) -> Unit,
    ) {
        callback(
            Result.success(
                NativeLaunchAtLoginResult(
                    NativeLaunchAtLoginState.UNAVAILABLE,
                    null,
                )
            )
        )
    }

    override fun openLaunchAtLoginSettings(callback: (Result<Boolean>) -> Unit) {
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

    private fun commandFailed(permission: PlatformPermissionResult): NativeVpnCommandResult =
        NativeVpnCommandResult(
            NativeVpnCommandState.FAILED,
            permission,
        )

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

    private companion object {
        // The per-app list renders icons in a 31dp slot; 96px covers 3x density.
        const val ICON_SIZE_PX = 96
    }
}
