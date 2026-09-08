package net.yuandev.onexray.pigeon

import com.elvishew.xlog.XLog
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AppFlutterApi(binaryMessenger: BinaryMessenger) {
    private val flutterApi: BridgeFlutterApi = BridgeFlutterApi(binaryMessenger)

    @Volatile private var vpnStatus = VpnStatus.DISCONNECTED

    suspend fun refreshVpnStatus() {
        vpnStatusChanged(vpnStatus)
    }

    fun readVpnStatus(): VpnStatus {
        return vpnStatus
    }

    fun setVpnStatus(status: VpnStatus) {
        vpnStatus = status
    }

    suspend fun vpnStatusChanged(status: VpnStatus) {
        XLog.d("AppFlutterApi: vpnStatusChanged $status")
        withContext(Dispatchers.Main) {
            setVpnStatus(status)
            flutterApi.vpnStatusChanged(status) {
            }
        }
    }
}
