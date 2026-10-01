import Foundation
import XCTest

// Link the production file without submitting requests to the operating system.
func packetTunnelId() -> String { "net.yuandev.onexray.test.tun" }
func YGLog(_ message: String) {}

final class SystemExtensionActivationTests: XCTestCase {
    @MainActor
    func testMissingExtensionCanBeActivatedAgainAfterSuccess() async {
        let activation = SystemExtensionActivation()
        let first = await activation.request { .installed }
        XCTAssertEqual(first, .installed)

        // A later permission check finds the extension missing; the new request
        // must reach the OS, where it may need approval again.
        let retry = await activation.request { .waitForApproval }
        XCTAssertEqual(retry, .waitForApproval)
        let failed = await activation.request { .notInstalled }
        XCTAssertEqual(failed, .notInstalled)
        let approved = await activation.request { .installed }
        XCTAssertEqual(approved, .installed)
    }

    @MainActor
    func testConcurrentPermissionRequestsShareThePendingActivation() async {
        let activation = SystemExtensionActivation()
        let started = expectation(description: "Activation submitted")
        let joined = expectation(description: "Second permission request started")
        var complete: CheckedContinuation<SystemExtensionState, Never>?
        let first = Task {
            await activation.request {
                await withCheckedContinuation {
                    complete = $0
                    started.fulfill()
                }
            }
        }
        await fulfillment(of: [started], timeout: 2)
        let second = Task {
            joined.fulfill()
            return await activation.request {
                XCTFail("A pending activation must be shared, not resubmitted")
                return .notInstalled
            }
        }
        await fulfillment(of: [joined], timeout: 2)
        complete?.resume(returning: .installed)

        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertEqual(firstResult, .installed)
        XCTAssertEqual(secondResult, .installed)
        let retry = await activation.request { .notInstalled }
        XCTAssertEqual(retry, .notInstalled)
    }
}

@main
enum ActivationTests {
    static func main() {
        let suite = SystemExtensionActivationTests.defaultTestSuite
        suite.run()
        guard let result = suite.testRun, result.executionCount > 0,
              result.totalFailureCount == 0 else { exit(1) }
    }
}
