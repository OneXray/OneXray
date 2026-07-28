#if os(macOS)
import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginService {
    static func query() -> NativeLaunchAtLoginResult {
        result(for: service.status)
    }

    static func setEnabled(_ enabled: Bool) -> NativeLaunchAtLoginResult {
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
            return query()
        } catch {
            YGLog("LaunchAtLoginService setEnabled failed: \(error.localizedDescription)")
            return NativeLaunchAtLoginResult(
                state: .error,
                message: error.localizedDescription
            )
        }
    }

    static func openSettings() -> Bool {
        SMAppService.openSystemSettingsLoginItems()
        return true
    }

    private static var service: SMAppService {
        SMAppService.mainApp
    }

    private static func result(for status: SMAppService.Status) -> NativeLaunchAtLoginResult {
        switch status {
        case .enabled:
            return NativeLaunchAtLoginResult(state: .enabled, message: nil)
        case .notRegistered:
            return NativeLaunchAtLoginResult(state: .disabled, message: nil)
        case .requiresApproval:
            return NativeLaunchAtLoginResult(state: .requiresApproval, message: nil)
        case .notFound:
            // mainApp may report notFound before its first registration,
            // including for a valid development-signed Debug app.
            return NativeLaunchAtLoginResult(state: .disabled, message: nil)
        @unknown default:
            return NativeLaunchAtLoginResult(
                state: .error,
                message: "Unknown login item status."
            )
        }
    }
}
#endif
