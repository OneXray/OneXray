package net.yuandev.onexray

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import com.elvishew.xlog.XLog
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import net.yuandev.onexray.pigeon.AppFlutterApi
import net.yuandev.onexray.pigeon.AppHostApi
import net.yuandev.onexray.pigeon.BridgeHostApi
import net.yuandev.onexray.vpn.OneVpnService

class MainActivity : FlutterFragmentActivity() {

    private val hostApi = AppHostApi(this)
    private var vpnStatusReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val flutterApi = AppFlutterApi(flutterEngine.dartExecutor)
        BridgeHostApi.setUp(flutterEngine.dartExecutor, hostApi)

        hostApi.onInit(flutterApi)
    }

    @SuppressLint("UnspecifiedRegisterReceiverFlag")
    override fun onResume() {
        super.onResume()
        // 注册跨进程广播接收器
        if (vpnStatusReceiver == null) {
            vpnStatusReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == OneVpnService.ACTION_VPN_STATUS) {
                        val running = intent.getBooleanExtra(OneVpnService.EXTRA_RUNNING, false)
                        XLog.d("MainActivity: received VPN status changed: $running")
                        // 将状态交给现有 hostApi（可触发 Flutter 通知或内部状态更新）
                        hostApi.onVpnStatusChanged(running)
                    }
                }
            }
        }
        val filter = IntentFilter(OneVpnService.ACTION_VPN_STATUS).apply {
            priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        }
        vpnStatusReceiver?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(it, filter, RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(it, filter)
            }
        }
    }

    override fun onPause() {
        // 解绑接收器避免泄漏
        vpnStatusReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        super.onPause()
    }

    override fun onDestroy() {
        hostApi.onDestroy()
        // 防御式注销
        vpnStatusReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        vpnStatusReceiver = null
        super.onDestroy()
    }
}
