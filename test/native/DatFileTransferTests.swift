import Foundation
import XCTest

final class DatFileTransferTests: XCTestCase {
    private var root: URL!
    private var source: URL { root.appendingPathComponent("source") }
    private var staging: URL { root.appendingPathComponent("dat.staging") }
    private var published: URL { root.appendingPathComponent("dat") }
    private let fm = FileManager.default
    private let time: Int64 = 1_790_726_400_000

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: "../references/validation-simplification/native-fixtures", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: source, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try fm.removeItem(at: root)
    }

    func testManifestIgnoresDirectoriesAndLinksWithoutFilteringExtensions() throws {
        try DatFileTransfer.put(name: "cert.pem", content: Data("certificate".utf8), mtimeMs: time, in: source)
        try fm.createDirectory(at: source.appendingPathComponent("unrelated"), withIntermediateDirectories: false)
        try fm.createSymbolicLink(at: source.appendingPathComponent("linked.dat"), withDestinationURL: source.appendingPathComponent("cert.pem"))
        let manifest = try XCTUnwrap(DatFileTransfer.manifest(in: source))
        XCTAssertEqual(Set(manifest.keys), ["cert.pem"])
        XCTAssertEqual(try DatFileTransfer.read(name: "cert.pem", in: source), Data("certificate".utf8))
        XCTAssertThrowsError(try DatFileTransfer.read(name: "linked.dat", in: source))
        XCTAssertThrowsError(try DatFileTransfer.manifest(in: source, strict: true))
        XCTAssertThrowsError(try DatFileTransfer.read(name: "missing.dat", in: source))
        try fm.createSymbolicLink(at: published, withDestinationURL: source)
        XCTAssertThrowsError(try DatFileTransfer.manifest(in: published))
    }

    func testManifestComparisonDistinguishesMissingAndEmpty() throws {
        XCTAssertNil(try DatFileTransfer.manifest(in: published))
        XCTAssertTrue(DatFileTransfer.needsSync(local: [:], remote: nil))
        XCTAssertFalse(DatFileTransfer.needsSync(local: [:], remote: [:]))
        XCTAssertFalse(DatFileTransfer.needsSync(local: ["cert.pem": time], remote: ["cert.pem": time + 1000]))
        XCTAssertTrue(DatFileTransfer.needsSync(local: ["cert.pem": time], remote: ["cert.pem": time + 1001]))
        XCTAssertTrue(DatFileTransfer.needsSync(local: ["cert.pem": time], remote: [:]))
    }

    func testEmptyCompletedTransferDoesNotRequireDefaultDat() throws {
        XCTAssertThrowsError(try DatFileTransfer.commit(staging: staging, to: published, expected: [:]))
        try DatFileTransfer.clearStaging(staging)
        try DatFileTransfer.commit(staging: staging, to: published, expected: [:])
        XCTAssertEqual(try DatFileTransfer.manifest(in: published), [:])
        XCTAssertFalse(try DatFileTransfer.directoryExists(staging))
        try DatFileTransfer.clearStaging(staging)
        try DatFileTransfer.put(name: "cert.pem", content: Data("certificate".utf8), mtimeMs: time, in: staging)
        try DatFileTransfer.commit(staging: staging, to: published, expected: ["cert.pem": time])
        XCTAssertEqual(try DatFileTransfer.read(name: "cert.pem", in: published), Data("certificate".utf8))
    }

    func testUnsafeFileNamesAndStagingLinksAreRejected() throws {
        try DatFileTransfer.clearStaging(staging)
        for name in ["", ".", "..", "../escape", "/absolute", "nested/file", "bad\0name"] {
            XCTAssertThrowsError(try DatFileTransfer.put(name: name, content: Data(), mtimeMs: time, in: staging), name)
        }
        try fm.removeItem(at: staging)
        try fm.createSymbolicLink(at: staging, withDestinationURL: source)
        XCTAssertThrowsError(try DatFileTransfer.clearStaging(staging))
        XCTAssertThrowsError(try DatFileTransfer.put(name: "file", content: Data(), mtimeMs: time, in: staging))
        XCTAssertEqual(try DatFileTransfer.manifest(in: source), [:])
    }

    func testMissingExtraOrModifiedFileNeverReplacesPublishedDirectory() throws {
        try DatFileTransfer.clearStaging(published)
        try DatFileTransfer.put(name: "old.dat", content: Data("old".utf8), mtimeMs: time, in: published)
        try DatFileTransfer.clearStaging(staging)
        try DatFileTransfer.put(name: "new.dat", content: Data("new".utf8), mtimeMs: time, in: staging)
        for expected in [["new.dat": time, "missing.dat": time], [:], ["new.dat": time + 2000]] {
            XCTAssertThrowsError(try DatFileTransfer.commit(staging: staging, to: published, expected: expected))
            XCTAssertEqual(try DatFileTransfer.read(name: "old.dat", in: published), Data("old".utf8))
        }
        try fm.createSymbolicLink(at: staging.appendingPathComponent("linked"), withDestinationURL: source)
        XCTAssertThrowsError(try DatFileTransfer.commit(staging: staging, to: published, expected: ["new.dat": time]))
        XCTAssertEqual(try DatFileTransfer.read(name: "old.dat", in: published), Data("old".utf8))
    }

    func testFailedPublicationRollsBackAndCanRetry() throws {
        try DatFileTransfer.clearStaging(published)
        try DatFileTransfer.put(name: "old.dat", content: Data("old".utf8), mtimeMs: time, in: published)
        try DatFileTransfer.clearStaging(staging)
        try DatFileTransfer.put(name: "new.dat", content: Data("new".utf8), mtimeMs: time, in: staging)
        let failing = FailingMove(staging: staging)
        XCTAssertThrowsError(try DatFileTransfer.commit(staging: staging, to: published, expected: ["new.dat": time], fileManager: failing))
        XCTAssertEqual(try DatFileTransfer.read(name: "old.dat", in: published), Data("old".utf8))
        XCTAssertTrue(try DatFileTransfer.directoryExists(staging))
        try DatFileTransfer.commit(staging: staging, to: published, expected: ["new.dat": time])
        XCTAssertEqual(try DatFileTransfer.read(name: "new.dat", in: published), Data("new".utf8))
        XCTAssertFalse(try DatFileTransfer.directoryExists(root.appendingPathComponent("dat.old")))
    }

    func testMessagesCarryExpectedManifestAndRejectOldCommits() throws {
        let expected = ["cert.pem": time]
        let message = try TunnelMessageCoder.encode(TunnelRequest.commitDatFiles(expected: expected))
        guard case let .commitDatFiles(decoded) = try TunnelMessageCoder.decode(TunnelRequest.self, from: message) else {
            return XCTFail("Wrong request")
        }
        XCTAssertEqual(decoded, expected)
        XCTAssertThrowsError(try TunnelMessageCoder.decode(LegacyRequest.self, from: message))
        let old = try TunnelMessageCoder.encode(LegacyRequest.commitDat)
        XCTAssertThrowsError(try TunnelMessageCoder.decode(TunnelRequest.self, from: old))
        for manifest: [String: Int64]? in [nil, [:], expected] {
            let response = try TunnelMessageCoder.encode(TunnelResponse.datManifest(manifest))
            guard case let .datManifest(decoded) = try TunnelMessageCoder.decode(TunnelResponse.self, from: response) else {
                return XCTFail("Wrong response")
            }
            XCTAssertEqual(decoded, manifest)
        }
    }
}

private enum LegacyRequest: Codable { case commitDat }

private final class FailingMove: FileManager, @unchecked Sendable {
    let staging: URL
    init(staging: URL) { self.staging = staging; super.init() }
    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if srcURL == staging { throw CocoaError(.fileWriteNoPermission) }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}

@main
enum NativeTests {
    static func main() {
        let suite = DatFileTransferTests.defaultTestSuite
        suite.run()
        guard let result = suite.testRun, result.executionCount == 7,
              result.totalFailureCount == 0 else { exit(1) }
    }
}
