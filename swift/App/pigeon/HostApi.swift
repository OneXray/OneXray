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

class AppHostApi: BridgeHostApi {
    private let flutterApi: AppFlutterApi
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
            let installed = await VPNManager.shared.refreshVpn()
            let permission = await VPNManager.shared.queryPlatformPermission()
            await flutterApi.refreshVpn(result: installed)
            await flutterApi.vpnStatusChanged()
            completion(.success(commandSuccess(permission: permission)))
        }
    }
    
    func startVpn(completion: @escaping (Result<NativeVpnCommandResult, any Error>) -> Void) {
        Task {
            let installed = await VPNManager.shared.startVpn()
            let permission = await VPNManager.shared.queryPlatformPermission()
            await flutterApi.refreshVpn(result: installed)
            completion(.success(commandResult(installed, permission: permission)))
        }
    }

    func stopVpn(completion: @escaping (Result<NativeVpnCommandResult, any Error>) -> Void) {
        Task {
            let installed = await VPNManager.shared.stopVpn()
            let permission = await VPNManager.shared.queryPlatformPermission()
            await flutterApi.refreshVpn(result: installed)
            completion(.success(commandResult(installed, permission: permission)))
        }
    }
    
    func invoke(requestJson: String, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = requestJson.withCString { p in
                let p0 = UnsafeMutablePointer(mutating: p)
                return CGoInvoke(p0)
            }
            callResponse(res, completion: completion)
        }
    }

    private func callResponse(_ res: UnsafeMutablePointer<CChar>?, completion: @escaping (Result<String, any Error>) -> Void) {
        if let res = res {
            let text = String(cString: res)
            free(res)
            completion(.success(text))
        } else {
            completion(.failure(AppHostApiError.cgoFailed))
        }
    }
    
    func checkVpnPermission(completion: @escaping (Result<Bool, any Error>) -> Void) {
        Task {
            await VPNManager.shared.refreshVpn()
        }
        completion(.success(true))
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

    /// macOS
    func useSystemExtension(completion: @escaping (Result<Bool, any Error>) -> Void) {
        completion(.success(Constants.useSystemExtension))
    }

    /// iOS
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
                print(error.localizedDescription)
                completion(.success(false))
            } else {
                completion(.success(true))
            }
        }
        
#else
        completion(.success(true))
#endif
    }

    func getCurrentAppIcon(completion: @escaping (Result<String, any Error>) -> Void) {
        var appIcon = ""
#if os(iOS)
        if let iconName = UIApplication.shared.alternateIconName {
            appIcon = iconName
        }
#endif
        completion(.success(appIcon))
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
