import Foundation
import NetworkExtension

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#else
#error("Unsupported platform.")
#endif

@MainActor
class AppFlutterApi {
    private let flutterApi: BridgeFlutterApi
    init(binaryMessenger: FlutterBinaryMessenger) {
        self.flutterApi = BridgeFlutterApi(binaryMessenger: binaryMessenger)
        VPNManager.shared.registerStatusObserver(vpnStatusChanged)
    }

    deinit {
        Task {
            await VPNManager.shared.unregisterStatusObserver()
        }
    }
    
    func vpnStatusChanged() {
        if let status = VPNManager.shared.readStatus() {
            YGLog("readRunningVpn \(status.rawValue)")
            var vpnStatus: VpnStatus = .disconnected
            switch status {
            case .disconnecting:
                vpnStatus = .disconnecting
            case .disconnected, .invalid:
                vpnStatus = .disconnected
            case .connecting:
                vpnStatus = .connecting
            case .connected:
                vpnStatus = .connected
            default:
                break
            }
            flutterApi.vpnStatusChanged(status: vpnStatus) { _ in
            }
        } else {
            flutterApi.vpnStatusChanged(status: .disconnected) { _ in
            }
        }
    }
}
