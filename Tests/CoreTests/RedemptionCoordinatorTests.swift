import XCTest
@testable import Core
@testable import PointsEngine

class RedemptionCoordinatorTests: XCTestCase {
    var redemptionService: MockRedemptionService!
    var exemptionManager: MockExemptionManager!
    var coordinator: RedemptionCoordinator!

    override func setUp() {
        super.setUp()
        redemptionService = MockRedemptionService()
        exemptionManager = MockExemptionManager()
        coordinator = RedemptionCoordinator(
            childId: ChildID("test-child"),
            redemptionService: redemptionService,
            exemptionManager: exemptionManager
        )
    }

    func testRedeemSuccess() {
        // Given
        let pointsToRedeem = 100
        let config = RedemptionConfiguration.default

        // When
        coordinator.redeem(points: pointsToRedeem, config: config)

        // Then
        XCTAssertEqual(redemptionService.redeem_calledCount, 1)
        XCTAssertEqual(redemptionService.redeem_childId, ChildID("test-child"))
        XCTAssertEqual(redemptionService.redeem_points, pointsToRedeem)
        XCTAssertEqual(exemptionManager.startExemption_calledCount, 1)
    }

    func testRedeemFailure() {
        // Given
        let pointsToRedeem = 100
        let config = RedemptionConfiguration.default
        redemptionService.redeem_shouldThrowError = true

        // When
        coordinator.redeem(points: pointsToRedeem, config: config)

        // Then
        XCTAssertEqual(redemptionService.redeem_calledCount, 1)
        XCTAssertEqual(exemptionManager.startExemption_calledCount, 0)
    }
}

class MockRedemptionService: RedemptionServiceProtocol {
    var redeem_calledCount = 0
    var redeem_childId: ChildID?
    var redeem_points: Int?
    var redeem_shouldThrowError = false

    func redeem(childId: ChildID, points: Int, config: RedemptionConfiguration) throws -> EarnedTimeWindow {
        redeem_calledCount += 1
        redeem_childId = childId
        redeem_points = points

        if redeem_shouldThrowError {
            throw RedemptionError.insufficientBalance(available: 0, required: 100)
        }

        return EarnedTimeWindow(childId: childId, durationSeconds: 600)
    }

    func canRedeem(childId: ChildID, points: Int, config: RedemptionConfiguration) -> Result<Int, RedemptionError> {
        return .success(1000)
    }
}

class MockExemptionManager: ExemptionManagerProtocol {
    var startExemption_calledCount = 0

    func startExemption(window: EarnedTimeWindow, onExpiry: (() -> Void)?) {
        startExemption_calledCount += 1
    }

    func getActiveWindow(for childId: ChildID) -> EarnedTimeWindow? {
        return nil
    }

    func getAllActiveWindows() -> [EarnedTimeWindow] {
        return []
    }

    func extendExemption(for childId: ChildID, additionalSeconds: TimeInterval, maxTotalMinutes: Int) -> EarnedTimeWindow? {
        return nil
    }

    func cancelExemption(for childId: ChildID) {}

    func restoreFromPersistence() {}
}
