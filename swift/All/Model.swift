import Foundation

enum OnDemandRuleMode: String, Codable {
    case connect
    case disconnect
}

enum OnDemandRuleInterfaceType: String, Codable {
    case any
    case cellular
    case wifi
    case ethernet
}

struct OnDemandRule: Codable {
    var mode: OnDemandRuleMode?
    var interfaceType: OnDemandRuleInterfaceType?
    var ssid: [String]?
}

struct TunJson: Codable {
    var tunDnsIPv4: String?
    var tunDnsIPv6: String?
    var enableDot: Bool?
    var dnsServerName: String?
    var enableIPv6: Bool?
    var tunName: String?
    var tunPriority: Int?
    var interface: String?
    var onDemandEnabled: Bool?
    var disconnectOnSleep: Bool?
    var onDemandRules: [OnDemandRule]?
    var perAppVPNMode: String?
    var allowAppList: [String]?
    var disallowAppList: [String]?
}

struct StartVpnRequest: Codable {
    var tun: TunJson?
    var pingPort: String?
    var coreBase64Text: String?

    private static func fromUrl(_ url: URL) throws -> Self {
        let data = try Data(contentsOf: url)
        let request = try JSONDecoder().decode(self, from: data)
        return request
    }

    static var startModel: StartVpnRequest? {
        YGLog("tunnel appGroupId=\(appGroupId())")
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId()) {
            YGLog("tunnel groupURL=\(groupURL)")
            let requestUrl = groupURL.adaptedAppendPath(path: StartModelFile)
            do {
                let request = try fromUrl(requestUrl)
                return request
            } catch {}
        }
        return nil
    }
}


struct CallResponse: Codable, Hashable {
    var success: Bool
    var error: String?
    static func fromResponse(_ res: UnsafeMutablePointer<CChar>?) -> Self {
        if let res = res {
            let text = String(cString: res)
            free(res)

            if let data = Data(base64Encoded: text) {
                do {
                    let decoder = JSONDecoder()
                    let model = try decoder.decode(self, from: data)
                    return model
                } catch {}
            }
        }
        return CallResponse(success: false)
    }
}

// MARK: - System extension XPC protocol (app ↔ tunnel)

enum TunnelRequest: Codable {
    case listDat
    case clearDat
    case putDat(name: String, content: Data, mtimeMs: Int64)
    case commitDat
    case startXray
}

enum TunnelResponse: Codable {
    case ok
    case datManifest([String: Int64])
    case error(String)
}

enum TunnelMessageCoder {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = PropertyListDecoder()
        return try decoder.decode(type, from: data)
    }
}
