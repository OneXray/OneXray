import Foundation

// App ↔ System Extension resource transfer. This verifies the transfer, not
// which resources an Xray configuration needs.
enum TunnelRequest: Codable {
    case listDat
    case clearDat
    case putDat(name: String, content: Data, mtimeMs: Int64)
    // A distinct case also makes old extensions reject the new commit contract.
    case commitDatFiles(expected: [String: Int64])
    case startXray
}

enum TunnelResponse: Codable {
    case ok
    // nil means no published directory; [:] is a complete, empty directory.
    case datManifest([String: Int64]?)
    case error(String)
}

enum TunnelMessageCoder {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try PropertyListDecoder().decode(type, from: data)
    }
}

enum DatFileTransfer {
    enum Failure: Error {
        case invalidDirectory
        case invalidFile(String)
        case incompleteTransfer
    }

    static func directoryExists(_ directory: URL) throws -> Bool {
        do {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw Failure.invalidDirectory
            }
            return true
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return false
        }
    }

    static func manifest(in directory: URL, strict: Bool = false) throws -> [String: Int64]? {
        guard try directoryExists(directory) else { return nil }
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey]
        let entries = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))
        var result: [String: Int64] = [:]
        for file in entries {
            let values = try file.resourceValues(forKeys: keys)
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                if strict { throw Failure.invalidFile(file.lastPathComponent) }
                continue
            }
            guard let date = values.contentModificationDate else {
                throw Failure.invalidFile(file.lastPathComponent)
            }
            result[file.lastPathComponent] = Int64(date.timeIntervalSince1970 * 1000)
        }
        return result
    }

    static func needsSync(local: [String: Int64], remote: [String: Int64]?) -> Bool {
        guard let remote, Set(local.keys) == Set(remote.keys) else { return true }
        return local.contains { name, time in
            abs(Double(time) - Double(remote[name]!)) > 1000
        }
    }

    private static func fileURL(name: String, in directory: URL) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..",
              !name.contains("\0"), (name as NSString).lastPathComponent == name else {
            throw Failure.invalidFile(name)
        }
        return directory.appendingPathComponent(name)
    }

    static func read(name: String, in directory: URL) throws -> Data {
        let file = try fileURL(name: name, in: directory)
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Failure.invalidFile(name)
        }
        return try Data(contentsOf: file)
    }

    static func clearStaging(_ staging: URL) throws {
        let fm = FileManager.default
        if try directoryExists(staging) { try fm.removeItem(at: staging) }
        try fm.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    }

    static func put(name: String, content: Data, mtimeMs: Int64, in staging: URL) throws {
        guard try directoryExists(staging) else { throw Failure.invalidDirectory }
        let file = try fileURL(name: name, in: staging)
        try content.write(to: file, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: Double(mtimeMs) / 1000)],
            ofItemAtPath: file.path
        )
    }

    static func commit(
        staging: URL,
        to directory: URL,
        expected: [String: Int64],
        fileManager fm: FileManager = .default
    ) throws {
        guard let actual = try manifest(in: staging, strict: true),
              !needsSync(local: expected, remote: actual) else {
            throw Failure.incompleteTransfer
        }
        let hasPrevious = try directoryExists(directory)
        let backup = directory.deletingLastPathComponent().appendingPathComponent("dat.old")
        if try directoryExists(backup) { try fm.removeItem(at: backup) }
        if hasPrevious { try fm.moveItem(at: directory, to: backup) }
        do {
            try fm.moveItem(at: staging, to: directory)
        } catch {
            if hasPrevious { try fm.moveItem(at: backup, to: directory) }
            throw error
        }
        // A leftover previous directory is cleaned on the next commit.
        if hasPrevious { try? fm.removeItem(at: backup) }
    }
}
