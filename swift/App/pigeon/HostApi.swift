import Foundation
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

    func readVpnStatus(completion: @escaping (Result<Void, any Error>) -> Void) {
        Task {
            await VPNManager.shared.refreshVpn()
            await flutterApi.vpnStatusChanged()
            completion(.success(()))
        }
    }
    
    func startVpn(completion: @escaping (Result<Void, any Error>) -> Void) {
        Task {
            _ = await VPNManager.shared.startVpn()
            completion(.success(()))
        }
    }

    func stopVpn(completion: @escaping (Result<Void, any Error>) -> Void) {
        Task {
            await VPNManager.shared.stopVpn()
            completion(.success(()))
        }
    }
    
    func getFreePorts(num: Int64, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = CGoGetFreePorts(GoInt(num))
            callResponse(res, completion: completion)
        }
    }
    
    func convertShareLinksToXrayJson(base64Text: String, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = base64Text.withCString { p in
                let p0 = UnsafeMutablePointer(mutating: p)
                return CGoConvertShareLinksToXrayJson(p0)
            }
            callResponse(res, completion: completion)
        }
    }
    
    func convertXrayJsonToShareLinks(base64Text: String, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = base64Text.withCString { p in
                let p0 = UnsafeMutablePointer(mutating: p)
                return CGOConvertXrayJsonToShareLinks(p0)
            }
            callResponse(res, completion: completion)
        }
    }
    
    func countGeoData(base64Text: String, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = base64Text.withCString { p in
                let p0 = UnsafeMutablePointer(mutating: p)
                return CGoCountGeoData(p0)
            }
            callResponse(res, completion: completion)
        }
    }
    
    func readGeoFiles(base64Text: String, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = base64Text.withCString { p in
                let p0 = UnsafeMutablePointer(mutating: p)
                return CGoReadGeoFiles(p0)
            }
            callResponse(res, completion: completion)
        }
    }
    
    func ping(base64Text: String, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = base64Text.withCString { p in
                let p0 = UnsafeMutablePointer(mutating: p)
                return CGoPing(p0)
            }
            callResponse(res, completion: completion)
        }
    }

    func testXray(base64Text: String, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = base64Text.withCString { p in
                let p0 = UnsafeMutablePointer(mutating: p)
                return CGoTestXray(p0)
            }
            callResponse(res, completion: completion)
        }
    }
    
    func runXray(base64Text: String, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = base64Text.withCString { p in
                let p0 = UnsafeMutablePointer(mutating: p)
                return CGoRunXray(p0)
            }
            callResponse(res, completion: completion)
        }
    }
    
    func stopXray(completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = CGoStopXray()
            callResponse(res, completion: completion)
        }
    }
    
    func xrayVersion(completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = CGoXrayVersion()
            callResponse(res, completion: completion)
        }
    }
    
    func buildMphCache(base64Text: String, completion: @escaping (Result<String, any Error>) -> Void) {
        Task {
            let res = base64Text.withCString { p in
                let p0 = UnsafeMutablePointer(mutating: p)
                return CGoBuildMphCache(p0)
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
    
    // android
    func getInstalledApps(completion: @escaping (Result<[AndroidAppInfo], any Error>) -> Void) {
        completion(.success([]))
    }

    // macOS
    func useSystemExtension(completion: @escaping (Result<Bool, any Error>) -> Void) {
        completion(.success(Constants.useSystemExtension))
    }

    // iOS
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
}
