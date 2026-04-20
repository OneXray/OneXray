import Foundation

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
