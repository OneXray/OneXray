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
    var metricsPort: String?
    var coreInvokeText: String?

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

struct LibXrayEnvJson: Codable, Hashable {
    var configLocation: String?
    var confdirLocation: String?
    var assetLocation: String?
    var certLocation: String?
    var useReadV: String?
    var useFreedomSplice: String?
    var useVmessPadding: String?
    var useCone: String?
    var useStrictJson: String?
    var bufferSize: String?
    var browserDialerAddress: String?
    var xudpLog: String?
    var xudpBaseKey: String?
    var tunFd: String?

    enum CodingKeys: String, CodingKey {
        case configLocation = "xray.location.config"
        case confdirLocation = "xray.location.confdir"
        case assetLocation = "xray.location.asset"
        case certLocation = "xray.location.cert"
        case useReadV = "xray.buf.readv"
        case useFreedomSplice = "xray.buf.splice"
        case useVmessPadding = "xray.vmess.padding"
        case useCone = "xray.cone.disabled"
        case useStrictJson = "xray.json.strict"
        case bufferSize = "xray.ray.buffer.size"
        case browserDialerAddress = "xray.browser.dialer"
        case xudpLog = "xray.xudp.show"
        case xudpBaseKey = "xray.xudp.basekey"
        case tunFd = "xray.tun.fd"
    }
}

struct RunXrayRequest: Codable, Hashable {
    var configPath: String?
}

struct LibXrayInvokeRequest: Codable, Hashable {
    var apiVersion: Int?
    var method: LibXrayMethod?
    var env: LibXrayEnvJson?
    var payload: RunXrayRequest?

    init(
        apiVersion: Int? = 1,
        method: LibXrayMethod? = nil,
        env: LibXrayEnvJson? = nil,
        payload: RunXrayRequest? = nil
    ) {
        self.apiVersion = apiVersion
        self.method = method
        self.env = env
        self.payload = payload
    }

    static func fromText(_ text: String) throws -> Self {
        let data = Data(text.utf8)
        return try JSONDecoder().decode(Self.self, from: data)
    }

    func toText() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func withTunFd(_ fd: Int32) -> Self {
        var request = self
        var env = request.env ?? LibXrayEnvJson()
        env.tunFd = "\(fd)"
        request.env = env
        return request
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
                    let decoder = JSONDecoder()
                    let model = try decoder.decode(self, from: data)
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
