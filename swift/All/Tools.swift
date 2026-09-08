import Foundation
import LibXray

enum LibXrayInvoker {
    enum Failure: Error {
        case cgoFailed
    }

    private static let lock = NSLock()

    static func invoke(_ requestJson: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try perform(requestJson)
        }.value
    }

    private static func perform(_ requestJson: String) throws -> String {
        // App invocations share process-global Xray state, including the simulator core.
        lock.lock()
        defer { lock.unlock() }
        let response = requestJson.withCString { pointer in
            CGoInvoke(UnsafeMutablePointer(mutating: pointer))
        }
        guard let response else { throw Failure.cgoFailed }
        defer { CGoFree(response) }
        return String(cString: response)
    }
}

extension URL {
    func adaptedAppendPath(path: String) -> URL {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            return self.appending(path: path)
        } else {
            return self.appendingPathComponent(path)
        }
    }

    func adaptedPath() -> String {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            return self.path(percentEncoded: false)
        } else {
            let path = self.path
            if let cleanPath = path.removingPercentEncoding {
                return cleanPath
            }
            return path
        }
    }
}
