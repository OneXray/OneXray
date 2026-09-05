import Foundation
import LibXray
#if os(iOS)
import Flutter
#elseif os(macOS)
import AppKit
import FlutterMacOS
#else
#error("Unsupported platform.")
#endif

enum AppHostApiError: Error {
    case cgoFailed
}

@MainActor
final class AppHostApi: @preconcurrency BridgeHostApi {
    private let flutterApi: AppFlutterApi
    private nonisolated static let invokeLock = NSLock()
    init(flutterApi: AppFlutterApi) {
        self.flutterApi = flutterApi
    }
    
    func getTunFilesDir(completion: @escaping (Result<String, any Error>) -> Void) {
        if let groupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId()) {
            let path = groupUrl.adaptedPath()
            completion(.success(path))
        } else {
            completion(.success(""))
        }
    }

    func readVpnStatus(completion: @escaping (Result<NativeVpnCommandResult, any Error>) -> Void) {
        Task {
            let permission = await VPNManager.shared.queryPlatformPermission()
            let installed = VPNManager.shared.refreshVpnResult(from: permission)
            flutterApi.refreshVpn(result: installed)
            flutterApi.vpnStatusChanged()
            if permission.state == .failed {
                completion(.success(NativeVpnCommandResult(
                    state: .failed,
                    permission: permission,
                    message: permission.message
                )))
            } else {
                completion(.success(commandSuccess(permission: permission)))
            }
        }
    }
    
    func startVpn(completion: @escaping (Result<NativeVpnCommandResult, any Error>) -> Void) {
        Task {
            let installed = await VPNManager.shared.startVpn()
            let permission = await VPNManager.shared.queryPlatformPermission()
            flutterApi.refreshVpn(result: installed)
            completion(.success(commandResult(installed, permission: permission)))
        }
    }

    func stopVpn(completion: @escaping (Result<NativeVpnCommandResult, any Error>) -> Void) {
        Task {
            let installed = await VPNManager.shared.stopVpn()
            let permission = await VPNManager.shared.queryPlatformPermission()
            flutterApi.refreshVpn(result: installed)
            completion(.success(commandResult(installed, permission: permission)))
        }
    }
    
    func invoke(requestJson: String, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.invoke(requestJson)
            }.value
            completion(result)
        }
    }

    private nonisolated static func invoke(_ requestJson: String) -> Result<String, any Error> {
        // Temporary cores share process-global Xray state; the VPN uses its extension.
        invokeLock.lock()
        defer { invokeLock.unlock() }
        let res = requestJson.withCString { p in
            let p0 = UnsafeMutablePointer(mutating: p)
            return CGoInvoke(p0)
        }
        if let res = res {
            let text = String(cString: res)
            CGoFree(res)
            return .success(text)
        } else {
            return .failure(AppHostApiError.cgoFailed)
        }
    }
    
    func queryPlatformPermission(completion: @escaping (Result<PlatformPermissionResult, any Error>) -> Void) {
        Task {
            completion(.success(await VPNManager.shared.queryPlatformPermission()))
        }
    }

    func requestPlatformPermission(completion: @escaping (Result<PlatformPermissionResult, any Error>) -> Void) {
        Task {
            completion(.success(await VPNManager.shared.requestPlatformPermission()))
        }
    }
    
    /// android
    func getInstalledApps(completion: @escaping (Result<[AndroidAppInfo], any Error>) -> Void) {
        completion(.success([]))
    }

    func getAppIcon(packageName: String, completion: @escaping (Result<FlutterStandardTypedData?, any Error>) -> Void) {
        completion(.success(nil))
    }

    /// macOS
    func useSystemExtension(completion: @escaping (Result<Bool, any Error>) -> Void) {
        completion(.success(Constants.useSystemExtension))
    }

    func appleVpnCapabilities(completion: @escaping (Result<AppleVpnCapabilities, any Error>) -> Void) {
        let serviceExclusions: Bool
        let deviceCommunication: Bool
        if #available(iOS 16.4, macOS 13.3, *) {
            serviceExclusions = true
        } else {
            serviceExclusions = false
        }
        if #available(iOS 17.4, macOS 14.4, *) {
            deviceCommunication = true
        } else {
            deviceCommunication = false
        }
        completion(.success(AppleVpnCapabilities(
            serviceExclusions: serviceExclusions,
            deviceCommunication: deviceCommunication
        )))
    }

    func queryLaunchAtLogin(
        completion: @escaping (Result<NativeLaunchAtLoginResult, any Error>) -> Void
    ) {
#if os(macOS)
        completion(.success(LaunchAtLoginService.query()))
#else
        completion(.success(NativeLaunchAtLoginResult(
            state: .unavailable,
            message: nil
        )))
#endif
    }

    func setLaunchAtLogin(
        enabled: Bool,
        completion: @escaping (Result<NativeLaunchAtLoginResult, any Error>) -> Void
    ) {
#if os(macOS)
        completion(.success(LaunchAtLoginService.setEnabled(enabled)))
#else
        completion(.success(NativeLaunchAtLoginResult(
            state: .unavailable,
            message: nil
        )))
#endif
    }

    func openLaunchAtLoginSettings(
        completion: @escaping (Result<Bool, any Error>) -> Void
    ) {
#if os(macOS)
        completion(.success(LaunchAtLoginService.openSettings()))
#else
        completion(.success(false))
#endif
    }

    /// Apple app icon
    func setAppIcon(appIcon: String, completion: @escaping (Result<Bool, any Error>) -> Void) {
#if os(iOS)
        var iconName: String? = appIcon
        if appIcon.isEmpty {
            iconName = nil
        }
        if UIApplication.shared.alternateIconName == iconName {
            completion(.success(true))
            return
        }
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                YGLog(error.localizedDescription)
                completion(.success(false))
            } else {
                completion(.success(true))
            }
        }
#elseif os(macOS)
        completion(.success(DockIconService.setIcon(appIcon)))
#endif
    }

    func getCurrentAppIcon(completion: @escaping (Result<String, any Error>) -> Void) {
#if os(iOS)
        var appIcon = ""
        if let iconName = UIApplication.shared.alternateIconName {
            appIcon = iconName
        }
        completion(.success(appIcon))
#elseif os(macOS)
        completion(.success(DockIconService.currentIconName))
#endif
    }

    private func commandResult(
        _ result: RefreshVpnResult,
        permission: PlatformPermissionResult
    ) -> NativeVpnCommandResult {
        switch result {
        case .installed:
            return NativeVpnCommandResult(
                state: .success,
                permission: permission,
                message: nil
            )
        case .waitForApproval:
            return NativeVpnCommandResult(
                state: .waitingForPlatformPermission,
                permission: permission,
                message: nil
            )
        case .notInstalled:
            if permission.state == .awaitingUserApproval || permission.state == .notDetermined {
                return NativeVpnCommandResult(
                    state: .waitingForPlatformPermission,
                    permission: permission,
                    message: nil
                )
            }
            return NativeVpnCommandResult(
                state: .failed,
                permission: permission,
                message: nil
            )
        }
    }

    private func commandSuccess(permission: PlatformPermissionResult) -> NativeVpnCommandResult {
        NativeVpnCommandResult(
            state: .success,
            permission: permission,
            message: nil
        )
    }
}
