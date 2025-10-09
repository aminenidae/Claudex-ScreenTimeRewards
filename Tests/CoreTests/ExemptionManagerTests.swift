import XCTest
@testable import PointsEngine
@testable import Core

@MainActor
final class ExemptionManagerTests: XCTestCase {
    var manager: ExemptionManager!
    var childId: ChildID!

    override func setUp() {
        super.setUp()
        manager = ExemptionManager(policy: .extend)
        childId = ChildID("test-child")
    }

    override func tearDown() {
        manager = nil
        childId = nil
        super.tearDown()
    }

    // MARK: - Basic Window Tests

    func testStartExemption() {
        let expectation = XCTestExpectation(description: "Exemption started")

        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 300,
            startTime: Date()
        )

        manager.startExemption(window: window) {
            expectation.fulfill()
        }

        let activeWindow = manager.getActiveWindow(for: childId)
        XCTAssertNotNil(activeWindow)
        XCTAssertEqual(activeWindow?.id, window.id)
        XCTAssertEqual(activeWindow?.durationSeconds, 300)
    }

    func testGetActiveWindowReturnsNilWhenNone() {
        let window = manager.getActiveWindow(for: childId)
        XCTAssertNil(window)
    }

    func testCancelExemption() {
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 300,
            startTime: Date()
        )

        manager.startExemption(window: window) {}

        XCTAssertNotNil(manager.getActiveWindow(for: childId))

        manager.cancelExemption(for: childId)

        XCTAssertNil(manager.getActiveWindow(for: childId))
    }

    // MARK: - Extension Tests

    func testExtendExemption() {
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 300, // 5 minutes
            startTime: Date()
        )

        manager.startExemption(window: window) {}

        // Extend by 2 minutes
        let extended = manager.extendExemption(
            for: childId,
            additionalSeconds: 120,
            maxTotalMinutes: 60
        )

        XCTAssertNotNil(extended)
        XCTAssertEqual(extended?.durationSeconds, 420) // 7 minutes total
    }

    func testExtendExemptionRespectsMaxCap() {
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 3000, // 50 minutes
            startTime: Date()
        )

        manager.startExemption(window: window) {}

        // Try to extend by 20 minutes (would be 70 total, but max is 60)
        let extended = manager.extendExemption(
            for: childId,
            additionalSeconds: 1200,
            maxTotalMinutes: 60
        )

        XCTAssertNotNil(extended)
        XCTAssertEqual(extended?.durationSeconds, 3600) // Capped at 60 minutes
    }

    func testExtendNonExistentExemption() {
        let extended = manager.extendExemption(
            for: childId,
            additionalSeconds: 120,
            maxTotalMinutes: 60
        )

        XCTAssertNil(extended)
    }

    // MARK: - Timer Tests

    func testExpiryCallbackFires() {
        let expectation = XCTestExpectation(description: "Expiry callback fires")

        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 0.5, // Half second
            startTime: Date()
        )

        manager.startExemption(window: window) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        // After expiry, window should be cleared
        XCTAssertNil(manager.getActiveWindow(for: childId))
    }

    func testExpiredWindowReturnsNil() {
        let pastTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 300,
            startTime: pastTime
        )

        manager.startExemption(window: window) {}

        // Should return nil because window is already expired
        let activeWindow = manager.getActiveWindow(for: childId)
        XCTAssertNil(activeWindow)
    }

    // MARK: - Multiple Children

    func testMultipleChildrenIndependentWindows() {
        let child1 = ChildID("child-1")
        let child2 = ChildID("child-2")

        let window1 = EarnedTimeWindow(
            childId: child1,
            durationSeconds: 300,
            startTime: Date()
        )

        let window2 = EarnedTimeWindow(
            childId: child2,
            durationSeconds: 600,
            startTime: Date()
        )

        manager.startExemption(window: window1) {}
        manager.startExemption(window: window2) {}

        let active1 = manager.getActiveWindow(for: child1)
        let active2 = manager.getActiveWindow(for: child2)

        XCTAssertEqual(active1?.durationSeconds, 300)
        XCTAssertEqual(active2?.durationSeconds, 600)

        // Cancel one doesn't affect the other
        manager.cancelExemption(for: child1)

        XCTAssertNil(manager.getActiveWindow(for: child1))
        XCTAssertNotNil(manager.getActiveWindow(for: child2))
    }

    // MARK: - Policy Tests

    func testCanStartExemptionWithExtendPolicy() {
        let manager = ExemptionManager(policy: .extend)
        XCTAssertTrue(manager.canStartExemption(for: childId))

        // Start an exemption
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 300,
            startTime: Date()
        )
        manager.startExemption(window: window) {}

        // Should still allow (extend policy)
        XCTAssertTrue(manager.canStartExemption(for: childId))
    }

    func testCanStartExemptionWithBlockPolicy() {
        let manager = ExemptionManager(policy: .block)
        XCTAssertTrue(manager.canStartExemption(for: childId))

        // Start an exemption
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 300,
            startTime: Date()
        )
        manager.startExemption(window: window) {}

        // Should not allow (block policy)
        XCTAssertFalse(manager.canStartExemption(for: childId))
    }

    func testCanStartExemptionWithReplacePolicy() {
        let manager = ExemptionManager(policy: .replace)
        XCTAssertTrue(manager.canStartExemption(for: childId))

        // Start an exemption
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 300,
            startTime: Date()
        )
        manager.startExemption(window: window) {}

        // Should still allow (replace policy)
        XCTAssertTrue(manager.canStartExemption(for: childId))
    }

    // MARK: - Persistence Tests

    func testSaveAndRestore() {
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 300,
            startTime: Date()
        )

        manager.startExemption(window: window) {}

        // Save state
        manager.save()

        // Create new manager and restore
        let newManager = ExemptionManager(policy: .extend)
        newManager.restoreFromPersistence()

        let restored = newManager.getActiveWindow(for: childId)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.durationSeconds, 300)
    }

    func testRestoreSkipsExpiredWindows() {
        let pastTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: 300,
            startTime: pastTime
        )

        manager.startExemption(window: window) {}

        // Save state
        manager.save()

        // Create new manager and restore
        let newManager = ExemptionManager(policy: .extend)
        newManager.restoreFromPersistence()

        let restored = newManager.getActiveWindow(for: childId)
        XCTAssertNil(restored) // Should not restore expired windows
    }
}