package net.yuandev.onexray.pigeon

import com.elvishew.xlog.XLog
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AppFlutterApi(binaryMessenger: BinaryMessenger) {
    private val flutterApi: BridgeFlutterApi = BridgeFlutterApi(binaryMessenger)

    suspend fun vpnStatusChanged(status: VpnStatus) {
        XLog.d("AppFlutterApi: vpnStatusChanged $status")
        withContext(Dispatchers.Main) {
            flutterApi.vpnStatusChanged(status) {
            }
        }
    }
}
