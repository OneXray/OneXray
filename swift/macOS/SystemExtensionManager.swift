import Foundation
import SystemExtensions

/// Public entry points for managing the bundled packet tunnel system extension.
/// Each call constructs a one-shot driver around a single OSSystemExtensionRequest;
/// no state is retained between calls.
public enum SystemExtensionManager {
    public static func isInstalled() async -> Bool {
        guard let properties = try? await ExtensionRequestDriver().runProperties({ queue in
            OSSystemExtensionRequest.propertiesRequest(forExtensionWithIdentifier: packetTunnelId(), queue: queue)
        }) else { return false }
        return properties.contains { !$0.isAwaitingUserApproval && !$0.isUninstalling }
    }

    public static func activate(forceReplace: Bool = false) async throws -> OSSystemExtensionRequest.Result? {
        try await ExtensionRequestDriver(forceReplace: forceReplace).runResult { queue in
            OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: packetTunnelId(), queue: queue)
        }
    }

    public static func deactivate() async throws -> OSSystemExtensionRequest.Result? {
        try await ExtensionRequestDriver().runResult { queue in
            OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: packetTunnelId(), queue: queue)
        }
    }
}

// MARK: - Private

private typealias RequestFactory = (DispatchQueue) -> OSSystemExtensionRequest

/// Handles a single OSSystemExtensionRequest. Delegate callbacks run on a
/// dedicated serial queue that also guards all mutable state, making the
/// driver effectively single-threaded despite its `@unchecked Sendable`.
private final class ExtensionRequestDriver: NSObject, OSSystemExtensionRequestDelegate, @unchecked Sendable {
    private enum Waiter {
        case none
        case result(CheckedContinuation<OSSystemExtensionRequest.Result?, Error>)
        case properties(CheckedContinuation<[OSSystemExtensionProperties], Error>)
    }

    private static let delegateQueue = DispatchQueue(label: "net.yuandev.onexray.system-extension")

    private let forceReplace: Bool
    private var waiter: Waiter = .none

    init(forceReplace: Bool = false) {
        self.forceReplace = forceReplace
        super.init()
    }

    func runResult(_ make: @escaping RequestFactory) async throws -> OSSystemExtensionRequest.Result? {
        try await withCheckedThrowingContinuation { continuation in
            submit(.result(continuation), make: make)
        }
    }

    func runProperties(_ make: @escaping RequestFactory) async throws -> [OSSystemExtensionProperties] {
        try await withCheckedThrowingContinuation { continuation in
            submit(.properties(continuation), make: make)
        }
    }

    private func submit(_ waiter: Waiter, make: @escaping RequestFactory) {
        Self.delegateQueue.async {
            self.waiter = waiter
            let request = make(Self.delegateQueue)
            request.delegate = self
            OSSystemExtensionManager.shared.submitRequest(request)
        }
    }

    // MARK: - OSSystemExtensionRequestDelegate

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension new: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        if forceReplace { return .replace }
        let identical = existing.bundleIdentifier == new.bundleIdentifier
            && existing.bundleVersion == new.bundleVersion
            && existing.bundleShortVersion == new.bundleShortVersion
        if identical {
            YGLog("system extension already at current version; cancel")
            return .cancel
        }
        YGLog("system extension differs; replacing")
        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        // Caller isn't blocked while the user walks over to System Settings.
        // Resolve with nil so callers treat "pending approval" as "not ready";
        // the success path is detected later via isInstalled().
        YGLog("system extension awaiting user approval in System Settings")
        if case let .result(continuation) = waiter {
            waiter = .none
            continuation.resume(returning: nil)
        }
    }

    func request(_ request: OSSystemExtensionRequest,
                 didFinishWithResult result: OSSystemExtensionRequest.Result) {
        if case let .result(continuation) = waiter {
            waiter = .none
            continuation.resume(returning: result)
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        switch waiter {
        case let .result(c):
            waiter = .none
            c.resume(throwing: error)
        case let .properties(c):
            waiter = .none
            c.resume(throwing: error)
        case .none:
            break
        }
    }

    func request(_ request: OSSystemExtensionRequest,
                 foundProperties properties: [OSSystemExtensionProperties]) {
        if case let .properties(continuation) = waiter {
            waiter = .none
            continuation.resume(returning: properties)
        }
    }
}
