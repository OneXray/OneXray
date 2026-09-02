import Foundation
import LibXray

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
    case ignore
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
    var tunIPv4: String?
    var tunIPv6: String?
    var tunDnsIPv4: String?
    var tunDnsIPv6: String?
    var enableDot: Bool?
    var dnsServerName: String?
    var enableIPv6: Bool?
    var metricsEnabled: Bool?
    var tunName: String?
    var autoOutboundsInterface: String?
    var includeAllNetworks: Bool?
    var excludeLocalNetworks: Bool?
    var excludeCellularServices: Bool?
    var excludeAPNs: Bool?
    var excludeDeviceCommunication: Bool?
    var onDemandEnabled: Bool?
    var onDemandRules: [OnDemandRule]?
    var perAppVPNMode: String?
    var allowAppList: [String]?
    var disallowAppList: [String]?
}

struct XrayInboundAccount: Codable {
    var user: String?
    var pass: String?
}

struct StartVpnRequest: Codable {
    var tun: TunJson?
    var socksPort: String?
    var pingPort: String?
    var pingAuth: XrayInboundAccount?
    var metricsPort: String?
    var coreInvokeText: String?
    var configId: Int64?
    var snapshotToken: String?

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
    case pingBatch
    case testXray
    case checkRoute
    case runXray
    case stopXray
    case xrayVersion
    case getXrayState
}

struct RunXrayRequest: Codable, Hashable {
    var xrayJson: String?
    var runtime: ManagedRuntimeRequest?
}

struct ManagedRuntimeRequest: Codable, Hashable {
    var statePath: String
    var planId: String
    var inboundTag: String
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
        apiVersion: Int? = 3,
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
    var success: Bool
    var error: String

    var isSuccess: Bool {
        success
    }

    static func fromResponse(_ res: UnsafeMutablePointer<CChar>?) -> Self {
        if let res = res {
            let text = String(cString: res)
            CGoFree(res)
            return fromText(text)
        }
        return invalidResponse
    }

    static func fromText(_ text: String?) -> Self {
        if let text, let data = text.data(using: .utf8) {
            do {
                return try JsonTool.decode(self, from: data)
            } catch {}
        }
        return invalidResponse
    }

    private static let invalidResponse = LibXrayInvokeResponse(
        success: false,
        error: "invalid response"
    )
}

enum RuntimeStateError: String, Error {
    case unsupported = "runtimeStateUnsupported"
    case unavailable = "runtimeStateUnavailable"
    case invalid = "runtimeStateInvalid"
    case inUse = "runtimeStateInUse"
    case timeout = "runtimeStateTimeout"
}

// Decode/re-encode only the public fields; never forward arbitrary file content.
struct RuntimeStateSnapshot: Codable {
    struct Session: Codable {
        let id: String
        let planId: String
        let startedAtMs: Int64
        let endedAtMs: Int64
        let uplink: Int64
        let downlink: Int64
    }

    let version: Int
    let session: Session
    let available: Bool
    let sampledAtMs: Int64
    let savedAtMs: Int64
    let error: String

    func validate() throws {
        let counters = [session.startedAtMs, session.endedAtMs, session.uplink,
                        session.downlink, sampledAtMs, savedAtMs]
        guard version == 1, Self.isSessionId(session.id),
              !session.planId.isEmpty, session.planId.utf8.count <= 256,
              counters.allSatisfy({ $0 >= 0 }),
              ["", "counters_unavailable", "state_write_failed"].contains(error) else {
            throw RuntimeStateError.invalid
        }
    }

    static func isSessionId(_ value: String) -> Bool {
        value.utf8.count == 32 && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }
}

struct RuntimeStateFiles: Codable {
    static let maximumBytes = 16 * 1024 * 1024
    let current: RuntimeStateSnapshot?
    let archived: [RuntimeStateSnapshot]

    func validatedText() throws -> String {
        try current?.validate()
        for snapshot in archived { try snapshot.validate() }
        let data = try JSONEncoder().encode(self)
        guard data.count <= Self.maximumBytes, let text = String(data: data, encoding: .utf8) else {
            throw RuntimeStateError.invalid
        }
        return text
    }

    // Keep the empty current explicitly null in the app-provider envelope.
    enum CodingKeys: String, CodingKey { case current, archived }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(current, forKey: .current)
        try container.encode(archived, forKey: .archived)
    }
}

// MARK: - System extension app-provider messages (app ↔ tunnel)

struct TunnelLogChunk: Codable {
    static let maximumBytes = 1024 * 1024
    static let maximumMessageBytes = maximumBytes + 4096
    let data: Data
    let offset: Int64
    let size: Int64
    let fileId: String

    static func validateRequest(planId: String, offset: Int64, limit: Int64) throws {
        guard RuntimeStateSnapshot.isSessionId(planId), offset >= -1,
              limit > 0, limit <= Int64(maximumBytes) else { throw RuntimeStateError.invalid }
    }

    func validate(limit: Int64) throws {
        guard offset >= 0, size >= offset, Int64(data.count) <= limit,
              Int64(data.count) <= size - offset,
              !fileId.isEmpty, fileId.utf8.count <= 128 else {
            throw RuntimeStateError.invalid
        }
    }
}

enum TunnelRequest: Codable {
    case listDat
    case clearDat
    case putDat(name: String, content: Data, mtimeMs: Int64)
    case commitDat
    case startXray
    case readRuntime(removeSessionIds: [String])
    case readLog(planId: String, access: Bool, offset: Int64, limit: Int64)
}

enum TunnelResponse: Codable {
    case ok
    case datManifest([String: Int64])
    case runtimeState(String?)
    case logChunk(TunnelLogChunk?)
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
