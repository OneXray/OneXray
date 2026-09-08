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

    func readVpnStatus() async throws -> VpnStatus {
        if let status = try await VPNManager.shared.readStatus() {
            YGLog("readRunningVpn \(status.rawValue)")
            var vpnStatus: VpnStatus = .disconnected
            switch status {
            case .disconnecting:
                vpnStatus = .disconnecting
            case .disconnected, .invalid:
                vpnStatus = .disconnected
            case .connecting, .reasserting:
                vpnStatus = .connecting
            case .connected:
                vpnStatus = .connected
            default:
                break
            }
            return vpnStatus
        } else {
            return .disconnected
        }
    }

    func vpnStatusChanged() async throws {
        let status = try await readVpnStatus()
        flutterApi.vpnStatusChanged(status: status) { _ in }
    }

    func refreshVpn(result: RefreshVpnResult) {
        flutterApi.refreshVpn(result: result) { _ in
        }
    }
}
