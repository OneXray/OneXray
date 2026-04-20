package net.yuandev.onexray.pigeon

import com.elvishew.xlog.XLog
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AppFlutterApi(binaryMessenger: BinaryMessenger) {
    private val flutterApi: BridgeFlutterApi = BridgeFlutterApi(binaryMessenger)

    private var vpnStatus = VpnStatus.DISCONNECTED

    suspend fun refreshVpnStatus() {
        vpnStatusChanged(vpnStatus)
    }

    fun readVpnStatus(): VpnStatus {
        return vpnStatus
    }

    suspend fun vpnStatusChanged(status: VpnStatus) {
        XLog.d("AppFlutterApi: vpnStatusChanged $status")
        withContext(Dispatchers.Main) {
            vpnStatus = status
            flutterApi.vpnStatusChanged(status) {
            }
        }
    }
}