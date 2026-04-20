import Combine
import Foundation
import NetworkExtension

typealias VPNStatusCallback = @MainActor () -> Void

enum VPNError: Error {
    case sessionNotReady
    case noGroupContainer
}

@MainActor
class VPNManager {
    static let shared = VPNManager()
    
    var vpn: NETunnelProviderManager?
    private var cancellable: Cancellable?
    private var statusObserver: VPNStatusCallback?
    private var systemExtensionSetupTask: Task<Bool, Never>?

    init() {
        YGLog("VPNManager init")
        cancellable = NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)
            .sink(receiveValue: { noti in
                if let session = noti.object as? NETunnelProviderSession {
                    if session == self.vpn?.connection {
                        self.runStatusObserver()
                    }
                }
            })
    }
    
    private func runStatusObserver() {
        if let observer = statusObserver {
            observer()
        }
    }
    
    func registerStatusObserver(_ observer: @escaping VPNStatusCallback) {
        statusObserver = observer
    }
    
    func unregisterStatusObserver() {
        statusObserver = nil
    }
    
    private func findVpn() async throws -> NETunnelProviderManager? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        for vpn in managers {
            if let conf = vpn.protocolConfiguration as? NETunnelProviderProtocol {
                if conf.providerBundleIdentifier == packetTunnelId() {
                    return vpn
                }
            }
        }
        return nil
    }
    
    private func newVpn() -> NETunnelProviderManager {
        let serverAddress = vpnServerAddress()
        
        let vpn = NETunnelProviderManager()
        let conf = NETunnelProviderProtocol()
        conf.providerBundleIdentifier = packetTunnelId()
        conf.serverAddress = serverAddress
        
        conf.username = serverAddress
        conf.excludeLocalNetworks = true
        
        vpn.protocolConfiguration = conf
        vpn.localizedDescription = serverAddress
        return vpn
    }
    
    func refreshVpn() async {
        #if os(macOS)
        if Constants.useSystemExtension {
            guard await ensureSystemExtensionIfNeeded() else {
                return
            }
        }
        #endif
        do {
            if let vpn = try await findVpn() {
                self.vpn = vpn
            } else {
                vpn = newVpn()
                await saveVpn(vpn: vpn!, tun: TunJson())
            }
        } catch {
            YGLog(error)
        }
    }

    #if os(macOS)
    private func ensureSystemExtensionIfNeeded() async -> Bool {
        if let existing = systemExtensionSetupTask {
            let cached = await existing.value
            if cached { return true }
            // Previous attempt returned nil (approval pending) or failed.
            // Re-check current state: the user may have approved in System
            // Settings since then.
            let installed = await SystemExtensionManager.isInstalled()
            if installed {
                systemExtensionSetupTask = Task { true }
            }
            return installed
        }
        let task = Task { await self.runSystemExtensionSetup() }
        systemExtensionSetupTask = task
        return await task.value
    }

    private func runSystemExtensionSetup() async -> Bool {
        #if DEBUG
        let force = true
        #else
        let force = false
        #endif
        do {
            if await SystemExtensionManager.isInstalled() && !force {
                return true
            }
            if let result = try await SystemExtensionManager.activate(forceReplace: force) {
                return result == .completed
            }
            return false
        } catch {
            YGLog("setup system extension error: \(error.localizedDescription)")
            return false
        }
    }
    #endif
    
    func readStatus() -> NEVPNStatus? {
        return VPNManager.shared.vpn?.connection.status
    }
    
    func startVpn() async -> Bool {
        guard let request = StartVpnRequest.startModel else {
            return false
        }

        do {
            await refreshVpn()
            if let vpn = vpn {
                if let tun = request.tun {
                    await saveVpn(vpn: vpn, tun: tun, request: request)
                } else {
                    await saveVpn(vpn: vpn, tun: TunJson(), request: request)
                }
                if let session = vpn.connection as? NETunnelProviderSession {
                    if Constants.useSystemExtension {
                        try session.startTunnel(options: ["source": "app" as NSString])
                        try await syncDatAndStart(session: session)
                    } else {
                        try session.startTunnel()
                    }
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        } catch {
            YGLog(error)
            return false
        }
    }

    func stopVpn() async {
        await refreshVpn()
        if let vpn = vpn {
            await saveVpn(vpn: vpn, tun: TunJson())
            switch vpn.connection.status {
            case .connected:
                if let session = vpn.connection as? NETunnelProviderSession {
                    session.stopTunnel()
                }
            case .disconnected:
                runStatusObserver()
            default:
                break
            }
        }
    }
    
    private func saveVpn(vpn: NETunnelProviderManager, tun: TunJson, request: StartVpnRequest? = nil) async {
        vpn.isEnabled = true
        if let request, let conf = vpn.protocolConfiguration as? NETunnelProviderProtocol {
            do {
                var providerConfig = conf.providerConfiguration ?? [:]
                let encodedRequest: Data
                if Constants.useSystemExtension {
                    let rewritten = rewriteRequestForExtension(request)
                    encodedRequest = try JSONEncoder().encode(rewritten)
                    if let xrayJson = readAndRewriteXrayJson() {
                        providerConfig["xrayJson"] = xrayJson
                    }
                } else {
                    encodedRequest = try JSONEncoder().encode(request)
                }
                providerConfig["request"] = encodedRequest
                conf.providerConfiguration = providerConfig
            } catch {
                YGLog(error)
            }
        }
        if let onDemandEnabled = tun.onDemandEnabled, onDemandEnabled {
            if let rules = tun.onDemandRules, !rules.isEmpty {
                let onDemandRules = convertRules(rules)
                if onDemandRules.isEmpty {
                    vpn.isOnDemandEnabled = false
                    vpn.onDemandRules = nil
                } else {
                    vpn.isOnDemandEnabled = true
                    vpn.onDemandRules = onDemandRules
                }
            } else {
                vpn.isOnDemandEnabled = true
                vpn.onDemandRules = [NEOnDemandRuleConnect()]
            }
            if let disconnectOnSleep = tun.disconnectOnSleep, disconnectOnSleep {
                vpn.protocolConfiguration?.disconnectOnSleep = true
            } else {
                vpn.protocolConfiguration?.disconnectOnSleep = false
            }
        } else {
            vpn.isOnDemandEnabled = false
            vpn.onDemandRules = nil
            vpn.protocolConfiguration?.disconnectOnSleep = false
        }
        do {
            try await vpn.saveToPreferences()
            try await vpn.loadFromPreferences()
        } catch {
            YGLog(error)
        }
    }

    
    private func convertRules(_ rules: [OnDemandRule]) -> [NEOnDemandRule] {
        var onDemandRules: [NEOnDemandRule] = []
        for rule in rules {
            if let onDemandRule = convertRule(rule) {
                onDemandRules.append(onDemandRule)
            }
        }
        return onDemandRules
    }
    
    private func convertRule(_ rule: OnDemandRule) -> NEOnDemandRule? {
        if let mode = rule.mode {
            switch mode {
            case .connect:
                let onDemandRule = NEOnDemandRuleConnect()
                if fillOnDemandRule(onDemandRule, rule) {
                    return onDemandRule
                }
                
            case .disconnect:
                let onDemandRule = NEOnDemandRuleDisconnect()
                if fillOnDemandRule(onDemandRule, rule) {
                    return onDemandRule
                }
            }
        }
        return nil
    }
    
    private func fillOnDemandRule(_ onDemandRule: NEOnDemandRule, _ rule: OnDemandRule) -> Bool {
        guard let interfaceType = rule.interfaceType else {
            return false
        }
        let interfaceTypeMatch = convertInterfaceType(interfaceType)
        onDemandRule.interfaceTypeMatch = interfaceTypeMatch
        if interfaceTypeMatch == .wiFi {
            if let ssid = rule.ssid, !ssid.isEmpty {
                onDemandRule.ssidMatch = ssid
            }
        }
        return true
    }
    
    private func convertInterfaceType(_ interfaceType: OnDemandRuleInterfaceType) -> NEOnDemandRuleInterfaceType {
        switch interfaceType {
        case .any:
            return .any
        case .wifi:
            return .wiFi
#if os(macOS)
        case .ethernet:
            return .ethernet
        case .cellular:
            return .any
#else
        case .cellular:
            return .cellular
        case .ethernet:
            return .any
#endif
        }
    }

    // MARK: - System Extension path rewriting + XPC dat sync

    private func pathMapping() -> (user: String, ext: String)? {
        guard let userGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId()),
              let extGroup = extensionGroupContainerURL() else {
            return nil
        }
        var u = userGroup.adaptedPath()
        var e = extGroup.adaptedPath()
        while u.hasSuffix("/") { u.removeLast() }
        while e.hasSuffix("/") { e.removeLast() }
        if u == e { return nil }
        return (u, e)
    }

    private func rewriteRequestForExtension(_ request: StartVpnRequest) -> StartVpnRequest {
        guard let mapping = pathMapping() else { return request }
        var newRequest = request
        if let coreBase64 = request.coreBase64Text,
           let data = Data(base64Encoded: coreBase64),
           let text = String(data: data, encoding: .utf8) {
            let rewritten = text.replacingOccurrences(of: mapping.user, with: mapping.ext)
            if let rewrittenData = rewritten.data(using: .utf8) {
                newRequest.coreBase64Text = rewrittenData.base64EncodedString()
            }
        }
        return newRequest
    }

    private func readAndRewriteXrayJson() -> Data? {
        guard let userGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId()) else {
            return nil
        }
        let xrayURL = userGroup.adaptedAppendPath(path: "run/xray.json")
        guard let data = try? Data(contentsOf: xrayURL) else { return nil }
        guard let mapping = pathMapping() else { return data }
        guard let text = String(data: data, encoding: .utf8) else { return data }
        let rewritten = text.replacingOccurrences(of: mapping.user, with: mapping.ext)
        return rewritten.data(using: .utf8) ?? data
    }

    private func syncDatAndStart(session: NETunnelProviderSession) async throws {
        try await waitSessionMessageable(session: session)

        let remote: [String: Int64]
        let listResp = try await sendTunnelRequest(session: session, .listDat)
        if case let .datManifest(m) = listResp {
            remote = m
        } else {
            remote = [:]
        }

        let local = buildLocalDatManifest()
        if needsDatSync(local: local, remote: remote) {
            YGLog("dat manifest mismatch, syncing \(local.count) files")
            _ = try await sendTunnelRequest(session: session, .clearDat)
            for (name, mtime) in local {
                guard let content = try? readLocalDatFile(name: name) else { continue }
                _ = try await sendTunnelRequest(session: session, .putDat(name: name, content: content, mtimeMs: mtime))
            }
            _ = try await sendTunnelRequest(session: session, .commitDat)
        } else {
            YGLog("dat manifest in sync")
        }

        _ = try await sendTunnelRequest(session: session, .startXray)
    }

    private func waitSessionMessageable(session: NETunnelProviderSession, timeout: TimeInterval = 10) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            switch session.status {
            case .connecting, .connected, .reasserting:
                return
            default:
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw VPNError.sessionNotReady
    }

    private func sendTunnelRequest(session: NETunnelProviderSession, _ request: TunnelRequest) async throws -> TunnelResponse {
        let data = try TunnelMessageCoder.encode(request)
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try session.sendProviderMessage(data) { response in
                    guard let response else {
                        continuation.resume(returning: .ok)
                        return
                    }
                    do {
                        let decoded = try TunnelMessageCoder.decode(TunnelResponse.self, from: response)
                        continuation.resume(returning: decoded)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func buildLocalDatManifest() -> [String: Int64] {
        let fm = FileManager.default
        guard let userGroup = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupId()) else {
            return [:]
        }
        let datDir = userGroup.adaptedAppendPath(path: "dat")
        guard let entries = try? fm.contentsOfDirectory(at: datDir, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]) else {
            return [:]
        }
        var result: [String: Int64] = [:]
        for url in entries {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true, let mtime = values?.contentModificationDate else { continue }
            result[url.lastPathComponent] = Int64(mtime.timeIntervalSince1970 * 1000)
        }
        return result
    }

    private func readLocalDatFile(name: String) throws -> Data {
        guard let userGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId()) else {
            throw VPNError.noGroupContainer
        }
        let url = userGroup.adaptedAppendPath(path: "dat").adaptedAppendPath(path: name)
        return try Data(contentsOf: url)
    }

    private func needsDatSync(local: [String: Int64], remote: [String: Int64]) -> Bool {
        if Set(local.keys) != Set(remote.keys) { return true }
        for (name, localMtime) in local {
            guard let remoteMtime = remote[name] else { return true }
            if abs(localMtime - remoteMtime) > 1000 { return true }
        }
        return false
    }
}
