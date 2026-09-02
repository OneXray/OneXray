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
    private var systemExtensionActivationTask: Task<RefreshVpnResult, Never>?

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

        vpn.protocolConfiguration = conf
        vpn.localizedDescription = serverAddress
        return vpn
    }

    func refreshVpn() async -> RefreshVpnResult {
        let permission = await queryPlatformPermission()
        switch permission.state {
        case .granted:
            return .installed
        case .awaitingUserApproval:
            return .waitForApproval
        default:
            return .notInstalled
        }
    }

    func queryPlatformPermission() async -> PlatformPermissionResult {
        #if os(macOS)
        if Constants.useSystemExtension {
            let state = await querySystemExtensionIfNeeded()
            if state != .installed {
                return platformPermissionResult(from: state)
            }
        }
        #endif
        do {
            vpn = try await findVpn()
            return PlatformPermissionResult(
                kind: .appleVpn,
                state: vpn == nil ? .notDetermined : .granted,
                message: nil
            )
        } catch {
            YGLog(error.localizedDescription)
            return PlatformPermissionResult(
                kind: .appleVpn,
                state: .failed,
                message: error.localizedDescription
            )
        }
    }

    func requestPlatformPermission() async -> PlatformPermissionResult {
        #if os(macOS)
        if Constants.useSystemExtension {
            var state = await querySystemExtensionIfNeeded()
            if state != .installed {
                state = await requestSystemExtensionIfNeeded()
            }
            if state != .installed {
                return platformPermissionResult(from: state, requested: true)
            }
        }
        #endif
        do {
            if let existing = try await findVpn() {
                vpn = existing
            } else {
                let manager = newVpn()
                // Prepare authorization only; the initial profile has no On Demand rules.
                try await saveVpn(vpn: manager, tun: TunJson())
                vpn = manager
            }
            return PlatformPermissionResult(
                kind: .appleVpn,
                state: .granted,
                message: nil
            )
        } catch {
            YGLog(error.localizedDescription)
            return PlatformPermissionResult(
                kind: .appleVpn,
                state: .failed,
                message: error.localizedDescription
            )
        }
    }

    #if os(macOS)
    private func platformPermissionResult(
        from state: RefreshVpnResult,
        requested: Bool = false
    ) -> PlatformPermissionResult {
        switch state {
        case .installed:
            return PlatformPermissionResult(
                kind: .macosSystemExtension,
                state: .granted,
                message: nil
            )
        case .waitForApproval:
            return PlatformPermissionResult(
                kind: .macosSystemExtension,
                state: .awaitingUserApproval,
                message: nil
            )
        case .notInstalled:
            return PlatformPermissionResult(
                kind: .macosSystemExtension,
                state: requested ? .failed : .notDetermined,
                message: requested ? "System Extension activation did not complete." : nil
            )
        }
    }

    private func querySystemExtensionIfNeeded() async -> RefreshVpnResult {
        await SystemExtensionManager.isInstalled()
    }

    private func requestSystemExtensionIfNeeded() async -> RefreshVpnResult {
        if let existing = systemExtensionActivationTask {
            let result = await existing.value
            if result != .installed {
                systemExtensionActivationTask = nil
            }
            return result
        }
        let task = Task { await self.runSystemExtensionSetup() }
        systemExtensionActivationTask = task
        let result = await task.value
        if result != .installed {
            systemExtensionActivationTask = nil
        }
        return result
    }

    private func runSystemExtensionSetup() async -> RefreshVpnResult {
        #if DEBUG
        let force = true
        #else
        let force = false
        #endif
        do {
            let installed = await SystemExtensionManager.isInstalled()
            if (installed == .installed || installed == .waitForApproval) && !force {
                return installed
            }
            if let result = try await SystemExtensionManager.activate(forceReplace: force) {
                if result == .completed {
                    return .installed
                } else {
                    return .notInstalled
                }
            }
            return .waitForApproval
        } catch {
            YGLog("setup system extension error: \(error.localizedDescription)")
            return .notInstalled
        }
    }
    #endif

    func readStatus() -> NEVPNStatus? {
        return VPNManager.shared.vpn?.connection.status
    }

    func startVpn() async -> RefreshVpnResult {
        guard let request = StartVpnRequest.startModel else {
            return .notInstalled
        }

        do {
            let installed = await refreshVpn()
            if installed != .installed {
                return installed
            }
            if let vpn = vpn {
                if let tun = request.tun {
                    try await saveVpn(vpn: vpn, tun: tun, request: request)
                } else {
                    try await saveVpn(vpn: vpn, tun: TunJson(), request: request)
                }
                if let session = vpn.connection as? NETunnelProviderSession {
                    if Constants.useSystemExtension {
                        try session.startTunnel(options: ["source": "app" as NSString])
                        try await syncDatAndStart(session: session)
                    } else {
                        try session.startTunnel()
                    }
                    return .installed
                } else {
                    return .notInstalled
                }
            } else {
                return .notInstalled
            }
        } catch {
            YGLog(error.localizedDescription)
            return .notInstalled
        }
    }

    func stopVpn() async -> RefreshVpnResult {
        #if os(macOS)
        if Constants.useSystemExtension {
            let installed = await querySystemExtensionIfNeeded()
            YGLog("querySystemExtensionIfNeeded \(installed)")
            if installed != .installed {
                return installed
            }
        }
        #endif
        if vpn == nil {
            do {
                vpn = try await findVpn()
            } catch {
                YGLog(error.localizedDescription)
                return .notInstalled
            }
        }
        guard let vpn = vpn else {
            return .notInstalled
        }
        do {
            try await saveVpn(vpn: vpn, tun: TunJson())
        } catch {
            YGLog(error.localizedDescription)
            return .notInstalled
        }
        switch vpn.connection.status {
        case .connected, .connecting, .reasserting:
            if let session = vpn.connection as? NETunnelProviderSession {
                session.stopTunnel()
            }
        case .disconnected:
            runStatusObserver()
        default:
            break
        }
        return .installed
    }

    private func saveVpn(vpn: NETunnelProviderManager, tun: TunJson, request: StartVpnRequest? = nil) async throws {
        vpn.isEnabled = true
        if let conf = vpn.protocolConfiguration as? NETunnelProviderProtocol {
            applyAppleNetworkRouting(conf, tun: tun)
            if let request {
                var providerConfig = conf.providerConfiguration ?? [:]
                let encodedRequest: Data
                if Constants.useSystemExtension {
                    let rewritten = rewriteRequestForExtension(request)
                    encodedRequest = try JsonTool.encode(rewritten)
                } else {
                    encodedRequest = try JsonTool.encode(request)
                }
                providerConfig["request"] = encodedRequest
                conf.providerConfiguration = providerConfig
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
        } else {
            vpn.isOnDemandEnabled = false
            vpn.onDemandRules = nil
        }
        vpn.protocolConfiguration?.disconnectOnSleep = false
        try await vpn.saveToPreferences()
        try await vpn.loadFromPreferences()
    }

    private func applyAppleNetworkRouting(_ conf: NETunnelProviderProtocol, tun: TunJson) {
        conf.includeAllNetworks = tun.includeAllNetworks ?? false
        conf.excludeLocalNetworks = tun.excludeLocalNetworks ?? true
        if #available(macOS 13.3, iOS 16.4, *) {
            conf.excludeCellularServices = tun.excludeCellularServices ?? true
            conf.excludeAPNs = tun.excludeAPNs ?? true
        }
        if #available(macOS 14.4, iOS 17.4, *) {
            conf.excludeDeviceCommunication = tun.excludeDeviceCommunication ?? true
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
        guard let mode = rule.mode else { return nil }
        let onDemandRule: NEOnDemandRule
        switch mode {
        case .connect:
            onDemandRule = NEOnDemandRuleConnect()
        case .disconnect:
            onDemandRule = NEOnDemandRuleDisconnect()
        case .ignore:
            onDemandRule = NEOnDemandRuleIgnore()
        }
        return fillOnDemandRule(onDemandRule, rule) ? onDemandRule : nil
    }

    private func fillOnDemandRule(_ onDemandRule: NEOnDemandRule, _ rule: OnDemandRule) -> Bool {
        guard let interfaceType = rule.interfaceType,
              let interfaceTypeMatch = convertInterfaceType(interfaceType) else {
            return false
        }
        onDemandRule.interfaceTypeMatch = interfaceTypeMatch
        if interfaceTypeMatch == .wiFi {
            if let ssid = rule.ssid, !ssid.isEmpty {
                onDemandRule.ssidMatch = ssid
            }
        }
        return true
    }

    private func convertInterfaceType(_ interfaceType: OnDemandRuleInterfaceType) -> NEOnDemandRuleInterfaceType? {
        switch interfaceType {
        case .any:
            return .any
        case .wifi:
            return .wiFi
        #if os(macOS)
        case .ethernet:
            return .ethernet
        case .cellular:
            return nil
        #else
        case .cellular:
            return .cellular
        case .ethernet:
            return nil
        #endif
        }
    }

    // MARK: - System Extension path rewriting + XPC dat sync

    func readRuntimeState(removeSessionIds: [String]) async throws -> String? {
        guard Constants.useSystemExtension else { throw RuntimeStateError.unsupported }
        guard removeSessionIds.allSatisfy(RuntimeStateSnapshot.isSessionId) else {
            throw RuntimeStateError.invalid
        }
        guard let manager = try await findVpn(),
              let session = manager.connection as? NETunnelProviderSession else {
            throw RuntimeStateError.unavailable
        }
        // NE may launch the provider just to handle a message. Do not start a
        // tunnel or require connected status; offline SE delivery remains NOT RUN.
        let response = try await sendTunnelRequest(
            session: session,
            .readRuntime(removeSessionIds: removeSessionIds),
            timeoutSeconds: 5
        )
        switch response {
        case let .runtimeState(text):
            guard let text, text.utf8.count <= RuntimeStateFiles.maximumBytes else {
                throw RuntimeStateError.invalid
            }
            return try JSONDecoder().decode(RuntimeStateFiles.self, from: Data(text.utf8)).validatedText()
        case let .error(code):
            throw RuntimeStateError(rawValue: code) ?? .unavailable
        default:
            throw RuntimeStateError.invalid
        }
    }

    private func pathMapping() -> (user: String, ext: String)? {
        guard let userGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId()),
              let extGroup = extensionGroupContainerURL()
        else {
            return nil
        }
        var u = userGroup.adaptedPath()
        var e = extGroup.adaptedPath()
        while u.hasSuffix("/") {
            u.removeLast()
        }
        while e.hasSuffix("/") {
            e.removeLast()
        }
        if u == e { return nil }
        return (u, e)
    }

    private func rewriteRequestForExtension(_ request: StartVpnRequest) -> StartVpnRequest {
        guard let mapping = pathMapping() else { return request }
        var newRequest = request
        if let text = request.coreInvokeText,
           var invoke = try? LibXrayInvokeRequest.fromText(text),
           var payload = invoke.payload,
           let xrayJson = payload.xrayJson {
            payload.xrayJson = xrayJson.replacingOccurrences(
                of: mapping.user,
                with: mapping.ext
            )
            invoke.payload = payload
            if let rewritten = try? invoke.toText() {
                newRequest.coreInvokeText = rewritten
            }
        }
        return newRequest
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
            try await Task.sleep(nanoseconds: 100000000)
        }
        throw VPNError.sessionNotReady
    }

    private func sendTunnelRequest(
        session: NETunnelProviderSession,
        _ request: TunnelRequest,
        timeoutSeconds: UInt64? = nil
    ) async throws -> TunnelResponse {
        let data = try TunnelMessageCoder.encode(request)
        if timeoutSeconds != nil && data.count > RuntimeStateFiles.maximumBytes {
            throw RuntimeStateError.invalid
        }
        return try await withCheckedThrowingContinuation { continuation in
            let pending = PendingTunnelResponse(continuation)
            let timeout = timeoutSeconds.map { seconds in
                Task { @MainActor in
                    do { try await Task.sleep(nanoseconds: seconds * 1_000_000_000) }
                    catch { return }
                    pending.resolve(.failure(RuntimeStateError.timeout))
                }
            }
            do {
                try session.sendProviderMessage(data) { response in
                    Task { @MainActor in
                        timeout?.cancel()
                        guard let response else {
                            pending.resolve(.failure(RuntimeStateError.unavailable))
                            return
                        }
                        if timeoutSeconds != nil && response.count > RuntimeStateFiles.maximumBytes {
                            pending.resolve(.failure(RuntimeStateError.invalid))
                            return
                        }
                        do {
                            let decoded = try TunnelMessageCoder.decode(TunnelResponse.self, from: response)
                            pending.resolve(.success(decoded))
                        } catch {
                            pending.resolve(.failure(RuntimeStateError.invalid))
                        }
                    }
                }
            } catch {
                timeout?.cancel()
                pending.resolve(.failure(RuntimeStateError.unavailable))
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

@MainActor
private final class PendingTunnelResponse {
    private var continuation: CheckedContinuation<TunnelResponse, Error>?

    init(_ continuation: CheckedContinuation<TunnelResponse, Error>) {
        self.continuation = continuation
    }

    func resolve(_ result: Result<TunnelResponse, Error>) {
        let pending = continuation
        continuation = nil
        pending?.resume(with: result)
    }
}
