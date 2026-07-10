import Foundation

enum JsonTool {
    static let decoder = JSONDecoder()
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return encoder
    }()

    private static let writingOptions: JSONSerialization.WritingOptions = [
        .prettyPrinted,
        .withoutEscapingSlashes,
    ]

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        try decode(type, from: Data(text.utf8))
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    static func encodeText<T: Encodable>(_ value: T) throws -> String {
        let data = try encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func decodeObject(from data: Data) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    static func encodeObject(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: writingOptions)
    }
}

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
    var metricsPort: String?
    var coreInvokeText: String?

    private static func fromUrl(_ url: URL) throws -> Self {
        let data = try Data(contentsOf: url)
        let request = try JsonTool.decode(self, from: data)
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


enum LibXrayMethod: String, Codable {
    case getFreePorts
    case convertShareLinksToXrayJson
    case convertXrayJsonToShareLinks
    case countGeoData
    case ping
    case testXray
    case runXray
    case runXrayFromJson
    case stopXray
    case xrayVersion
    case getXrayState
}

struct RunXrayRequest: Codable, Hashable {
    var configPath: String?
}

struct XrayEnv: Codable, Hashable {
    var assetLocation: String?
    var certLocation: String?
    var tunFd: String?

    enum CodingKeys: String, CodingKey {
        case assetLocation = "xray.location.asset"
        case certLocation = "xray.location.cert"
        case tunFd = "xray.tun.fd"
    }

    static func fromObject(_ object: Any?) throws -> Self {
        guard let object, !(object is NSNull) else {
            return Self()
        }
        return try JsonTool.decode(Self.self, from: JsonTool.encodeObject(object))
    }

    func toObject() throws -> [String: Any] {
        try JsonTool.decodeObject(from: JsonTool.encode(self))
    }
}

struct LibXrayInvokeRequest: Codable, Hashable {
    var apiVersion: Int?
    var method: LibXrayMethod?
    var payload: RunXrayRequest?

    init(
        apiVersion: Int? = 1,
        method: LibXrayMethod? = nil,
        payload: RunXrayRequest? = nil
    ) {
        self.apiVersion = apiVersion
        self.method = method
        self.payload = payload
    }

    static func fromText(_ text: String) throws -> Self {
        try JsonTool.decode(Self.self, from: text)
    }

    func toText() throws -> String {
        try JsonTool.encodeText(self)
    }
}

struct LibXrayInvokeResponse: Codable, Hashable {
    var success: Bool?
    var error: String?

    var isSuccess: Bool {
        success == true
    }

    static func fromResponse(_ res: UnsafeMutablePointer<CChar>?) -> Self {
        if let res = res {
            let text = String(cString: res)
            free(res)

            if let data = text.data(using: .utf8) {
                do {
                    let model = try JsonTool.decode(self, from: data)
                    return model
                } catch {}
            }
        }
        return LibXrayInvokeResponse(success: false)
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
