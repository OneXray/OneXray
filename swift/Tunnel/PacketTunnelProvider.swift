import Foundation
import NetworkExtension

enum TunnelError: Error {
    case noSocketFd
    case noStartModel
    case noGroupContainer
    case startXrayTimeout
}

final class PacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {
    /// https://github.com/WireGuard/wireguard-apple/blob/master/Sources/WireGuardKit/WireGuardAdapter.swift
    /// Tunnel device file descriptor.
    private var tunnelFileDescriptor: Int32? {
        var ctlInfo = ctl_info()
        withUnsafeMutablePointer(to: &ctlInfo.ctl_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        for fd: Int32 in 0 ... 1024 {
            var addr = sockaddr_ctl()
            var ret: Int32 = -1
            var len = socklen_t(MemoryLayout.size(ofValue: addr))
            withUnsafeMutablePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    ret = getpeername(fd, $0, &len)
                }
            }
            if ret != 0 || addr.sc_family != AF_SYSTEM {
                continue
            }
            if ctlInfo.ctl_id == 0 {
                ret = ioctl(fd, CTLIOCGINFO, &ctlInfo)
                if ret != 0 {
                    continue
                }
            }
            if addr.sc_id == ctlInfo.ctl_id {
                return fd
            }
        }
        return nil
    }

    private static let stateQueue = DispatchQueue(label: "net.yuandev.onexray.tunnel.state")
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var pendingStartSignal = false

    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        if Constants.useSystemExtension {
            try await startTunnelSE(options: options)
        } else {
            try await startTunnelLegacy()
        }
    }

    private func startTunnelLegacy() async throws {
        guard let request = StartVpnRequest.startModel else {
            YGLog("startTunnel noStartModel")
            throw TunnelError.noStartModel
        }
        let settings = buildSettings(request: request)
        try await setTunnelNetworkSettings(settings)
        if let coreBase64Text = request.coreBase64Text {
            try startXray(coreBase64Text)
        }
        YGLog("startTunnel finished")
    }

    private func startTunnelSE(options: [String: NSObject]?) async throws {
        guard let providerConfig = (self.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration else {
            YGLog("startTunnel no providerConfiguration")
            throw TunnelError.noStartModel
        }
        guard let requestData = providerConfig["request"] as? Data,
              let request = try? JSONDecoder().decode(StartVpnRequest.self, from: requestData) else {
            YGLog("startTunnel decode request failed")
            throw TunnelError.noStartModel
        }

        guard let extGroupURL = extensionGroupContainerURL() else {
            YGLog("startTunnel noGroupContainer")
            throw TunnelError.noGroupContainer
        }

        // Prepare extension-side directories.
        let runDir = extGroupURL.adaptedAppendPath(path: "run")
        let datDir = extGroupURL.adaptedAppendPath(path: "dat")
        let stagingDir = extGroupURL.adaptedAppendPath(path: "dat.staging")
        let fm = FileManager.default
        try? fm.createDirectory(at: runDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: datDir, withIntermediateDirectories: true)
        // Abandoned staging from an aborted previous sync → discard.
        try? fm.removeItem(at: stagingDir)

        // Materialize xray.json (already path-rewritten by the app).
        if let xrayJson = providerConfig["xrayJson"] as? Data {
            let xrayURL = runDir.adaptedAppendPath(path: "xray.json")
            do {
                try xrayJson.write(to: xrayURL)
            } catch {
                YGLog("startTunnel write xray.json error: \(error)")
            }
        }

        // App-driven path waits for the dat sync + start_xray signal.
        // On-demand path skips the wait and uses whatever is already in dat/.
        if options != nil {
            YGLog("startTunnel awaiting start_xray signal")
            try await waitStartSignal(timeout: 30)
        } else {
            YGLog("startTunnel on-demand, skipping XPC sync")
        }

        let settings = buildSettings(request: request)
        try await setTunnelNetworkSettings(settings)

        if let coreBase64Text = request.coreBase64Text {
            try startXray(coreBase64Text)
        }
    }

    private func buildSettings(request: StartVpnRequest) -> NEPacketTunnelNetworkSettings {
        let ipv4 = NEIPv4Settings(addresses: ["192.168.20.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: ProxyHost)
        settings.ipv4Settings = ipv4
        settings.mtu = TunMtu
        var servers: [String] = []
        if let tun = request.tun {
            if let tunDnsIPv4 = tun.tunDnsIPv4 {
                servers.append(tunDnsIPv4)
            }
            if let enableIPv6 = tun.enableIPv6, enableIPv6 {
                let ipv6 = NEIPv6Settings(addresses: ["FC00::0001"], networkPrefixLengths: [7])
                ipv6.includedRoutes = [NEIPv6Route.default()]
                settings.ipv6Settings = ipv6
                if let tunDnsIPv6 = tun.tunDnsIPv6 {
                    servers.append(tunDnsIPv6)
                }
            }

            if let enableDot = tun.enableDot, enableDot {
                let dnsSettings = NEDNSOverTLSSettings(servers: servers)
                if let serverName = tun.dnsServerName {
                    dnsSettings.serverName = serverName
                }
                settings.dnsSettings = dnsSettings
            } else {
                settings.dnsSettings = NEDNSSettings(servers: servers)
            }
        }
        return settings
    }

    private func waitStartSignal(timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Self.stateQueue.async {
                if self.pendingStartSignal {
                    self.pendingStartSignal = false
                    continuation.resume(returning: ())
                    return
                }
                self.startContinuation = continuation
                let deadline = DispatchTime.now() + timeout
                Self.stateQueue.asyncAfter(deadline: deadline) {
                    if let c = self.startContinuation {
                        self.startContinuation = nil
                        c.resume(throwing: TunnelError.startXrayTimeout)
                    }
                }
            }
        }
    }

    private func fulfillStartSignal() {
        Self.stateQueue.async {
            if let c = self.startContinuation {
                self.startContinuation = nil
                c.resume(returning: ())
            } else {
                self.pendingStartSignal = true
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        self.stopXray()
    }

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        if Constants.useSystemExtension {
            return handleAppMessageSE(messageData)
        }
        return messageData
    }

    private func handleAppMessageSE(_ data: Data) -> Data? {
        let request: TunnelRequest
        do {
            request = try TunnelMessageCoder.decode(TunnelRequest.self, from: data)
        } catch {
            YGLog("handleAppMessage decode error: \(error)")
            return try? TunnelMessageCoder.encode(TunnelResponse.error("decode"))
        }

        let response: TunnelResponse
        switch request {
        case .listDat:
            response = .datManifest(listDatManifest())
        case .clearDat:
            response = clearStaging() ? .ok : .error("clear")
        case let .putDat(name, content, mtimeMs):
            response = putStaged(name: name, content: content, mtimeMs: mtimeMs) ? .ok : .error("put \(name)")
        case .commitDat:
            response = commitStaging() ? .ok : .error("commit")
        case .startXray:
            fulfillStartSignal()
            response = .ok
        }
        return try? TunnelMessageCoder.encode(response)
    }

    // MARK: - dat staging operations

    private func datDir() -> URL? {
        extensionGroupContainerURL()?.adaptedAppendPath(path: "dat")
    }

    private func stagingDir() -> URL? {
        extensionGroupContainerURL()?.adaptedAppendPath(path: "dat.staging")
    }

    private func listDatManifest() -> [String: Int64] {
        let fm = FileManager.default
        guard let dir = datDir(),
              let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]) else {
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

    private func clearStaging() -> Bool {
        let fm = FileManager.default
        guard let dir = stagingDir() else { return false }
        try? fm.removeItem(at: dir)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return true
        } catch {
            YGLog("clearStaging error: \(error)")
            return false
        }
    }

    private func putStaged(name: String, content: Data, mtimeMs: Int64) -> Bool {
        let fm = FileManager.default
        guard let dir = stagingDir() else { return false }
        // Reject path traversal. File names must be single segments.
        let sanitized = (name as NSString).lastPathComponent
        guard !sanitized.isEmpty, sanitized == name else {
            YGLog("putStaged invalid name: \(name)")
            return false
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.adaptedAppendPath(path: sanitized)
        do {
            try content.write(to: target)
            let date = Date(timeIntervalSince1970: TimeInterval(mtimeMs) / 1000.0)
            try fm.setAttributes([.modificationDate: date], ofItemAtPath: target.adaptedPath())
            return true
        } catch {
            YGLog("putStaged write \(sanitized) error: \(error)")
            return false
        }
    }

    private func commitStaging() -> Bool {
        let fm = FileManager.default
        guard let staging = stagingDir(), let dat = datDir() else { return false }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: staging.adaptedPath(), isDirectory: &isDir), isDir.boolValue else {
            YGLog("commitStaging: staging missing")
            return false
        }
        let parent = dat.deletingLastPathComponent()
        let backup = parent.adaptedAppendPath(path: "dat.old")
        try? fm.removeItem(at: backup)
        // If current dat/ exists, move aside first; otherwise just rename staging → dat.
        if fm.fileExists(atPath: dat.adaptedPath()) {
            do {
                try fm.moveItem(at: dat, to: backup)
            } catch {
                YGLog("commitStaging move dat→dat.old error: \(error)")
                return false
            }
        }
        do {
            try fm.moveItem(at: staging, to: dat)
        } catch {
            YGLog("commitStaging move staging→dat error: \(error)")
            // Rollback.
            if fm.fileExists(atPath: backup.adaptedPath()) {
                try? fm.moveItem(at: backup, to: dat)
            }
            return false
        }
        try? fm.removeItem(at: backup)
        return true
    }

    // MARK: - Xray lifecycle

    private func startXray(_ base64Text: String) throws {
        guard let fd = self.tunnelFileDescriptor else {
            YGLog("PacketTunnelProvider TunnelError.noSocketFd")
            throw TunnelError.noSocketFd
        }

        Task {
            CGoSetTunFd(fd)
            let res = base64Text.withCString { p in
                let p0 = UnsafeMutablePointer(mutating: p)
                return CGoRunXray(p0)
            }
            let result = CallResponse.fromResponse(res)
            if !result.success {
                YGLog("PacketTunnelProvider startXray \(result.error)")
                killProcess()
            }
        }
    }

    private func stopXray() {
        let res = CGoStopXray()
        let result = CallResponse.fromResponse(res)
        if !result.success {
            killProcess()
        }
    }
}


private func killProcess() {
    Task {
        try await Task.sleep(nanoseconds: 1000000000)
        exit(0)
    }
}
