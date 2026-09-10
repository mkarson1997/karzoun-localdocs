import Foundation
import XCTest
@testable import LocalDocsCore

final class SecurityScopedAccessTests: XCTestCase {
    func testLeaseBalancesStartAndStopExactlyOnce() throws {
        let controller = RecordingSecurityScopedController(allowAccess: true)
        let url = URL(fileURLWithPath: "/tmp/localdocs-test")

        let lease = try SecurityScopedAccessLease(url: url, controller: controller)

        XCTAssertEqual(controller.startCount, 1)
        XCTAssertEqual(controller.stopCount, 0)
        XCTAssertEqual(try lease.withAccess { $0.path }, url.path)

        lease.stop()
        lease.stop()

        XCTAssertEqual(controller.stopCount, 1)
    }

    func testDeniedAccessFailsWithoutStopCall() {
        let controller = RecordingSecurityScopedController(allowAccess: false)
        let url = URL(fileURLWithPath: "/tmp/localdocs-denied")

        XCTAssertThrowsError(
            try SecurityScopedAccessLease(url: url, controller: controller)
        ) { error in
            XCTAssertEqual(
                error as? SecurityScopedAccessError,
                .accessDenied(url.path)
            )
        }

        XCTAssertEqual(controller.startCount, 1)
        XCTAssertEqual(controller.stopCount, 0)
    }

    func testLeaseStopsOnDeinit() throws {
        let controller = RecordingSecurityScopedController(allowAccess: true)
        let url = URL(fileURLWithPath: "/tmp/localdocs-deinit")

        do {
            let lease = try SecurityScopedAccessLease(url: url, controller: controller)
            XCTAssertEqual(lease.url, url)
            XCTAssertEqual(controller.stopCount, 0)
        }

        XCTAssertEqual(controller.stopCount, 1)
    }
}

private final class RecordingSecurityScopedController: SecurityScopedURLControlling, @unchecked Sendable {
    private let lock = NSLock()
    private let allowAccess: Bool
    private var starts = 0
    private var stops = 0

    init(allowAccess: Bool) {
        self.allowAccess = allowAccess
    }

    var startCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return starts
    }

    var stopCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return stops
    }

    func startAccessing(_ url: URL) -> Bool {
        lock.lock()
        starts += 1
        lock.unlock()
        return allowAccess
    }

    func stopAccessing(_ url: URL) {
        lock.lock()
        stops += 1
        lock.unlock()
    }
}
