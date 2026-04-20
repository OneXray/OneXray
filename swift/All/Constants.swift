import Foundation

public let ProxyHost = "127.0.0.1"
public let TunMtu: NSNumber = 1500

public let StartModelFile = "run/start.json"

public enum Constants {
    public static var useSystemExtension = false
}

private let teamAppGroupId = "2CKAULFA9J.net.yuandev.onexray"
private let groupAppGroupId = "group.net.yuandev.onexray"
private let seGroupAppGroupId = "group.net.yuandev.onexray.se"

public func appGroupId() -> String {
    #if os(iOS)
        return groupAppGroupId
    #elseif os(macOS)
        if Constants.useSystemExtension {
            return seGroupAppGroupId
        } else {
            return teamAppGroupId
        }
    #endif
}

private let tunId = "net.yuandev.onexray.tun"
private let seTunId = "net.yuandev.onexray.se.tun"

public func packetTunnelId() -> String {
    #if os(iOS)
        return tunId
    #elseif os(macOS)
        if Constants.useSystemExtension {
            return seTunId
        } else {
            return tunId
        }
    #endif
}

private let serverAddress = "OneXray"
private let seServerAddress = "OneXraySE"

public func vpnServerAddress() -> String {
    #if os(iOS)
        return serverAddress
    #elseif os(macOS)
        if Constants.useSystemExtension {
            return seServerAddress
        } else {
            return serverAddress
        }
    #endif
}

public func extensionGroupContainerURL() -> URL? {
    #if os(macOS)
    if Constants.useSystemExtension {
        return URL(fileURLWithPath: "/private/var/root/Library/Group Containers/\(appGroupId())")
    }
    #endif
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId())
}
