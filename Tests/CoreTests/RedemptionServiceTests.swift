import XCTest
@testable import PointsEngine
@testable import Core

final class RedemptionServiceTests: XCTestCase {
    var service: RedemptionService!
    var ledger: PointsLedger!
    var childId: ChildID!
    var config: RedemptionConfiguration!

    override func setUp() {
        super.setUp()
        ledger = PointsLedger()
        service = RedemptionService(ledger: ledger)
        childId = ChildID("test-child")
        config = RedemptionConfiguration(
            pointsPerMinute: 10,
            minRedemptionPoints: 30,
            maxRedemptionPoints: 600,
            maxTotalMinutes: 120
        )
    }

    override func tearDown() {
        ledger.clear()
        service = nil
        ledger = nil
        childId = nil
        config = nil
        super.tearDown()
    }

    // MARK: - Validation Tests

    func testCanRedeemWithSufficientBalance() {
        // Give child 100 points
        ledger.recordAccrual(childId: childId, points: 100)

        let result = service.canRedeem(childId: childId, points: 50, config: config)

        switch result {
        case .success(let balance):
            XCTAssertEqual(balance, 100)
        case .failure:
            XCTFail("Should succeed with sufficient balance")
        }
    }

    func testCannotRedeemWithInsufficientBalance() {
        // Give child 20 points
        ledger.recordAccrual(childId: childId, points: 20)

        let result = service.canRedeem(childId: childId, points: 50, config: config)

        switch result {
        case .success:
            XCTFail("Should fail with insufficient balance")
        case .failure(let error):
            XCTAssertEqual(error, .insufficientBalance(available: 20, required: 50))
        }
    }

    func testCannotRedeemBelowMinimum() {
        ledger.recordAccrual(childId: childId, points: 100)

        let result = service.canRedeem(childId: childId, points: 20, config: config)

        switch result {
        case .success:
            XCTFail("Should fail below minimum")
        case .failure(let error):
            XCTAssertEqual(error, .belowMinimum(points: 20, minimum: 30))
        }
    }

    func testCannotRedeemAboveMaximum() {
        ledger.recordAccrual(childId: childId, points: 1000)

        let result = service.canRedeem(childId: childId, points: 700, config: config)

        switch result {
        case .success:
            XCTFail("Should fail above maximum")
        case .failure(let error):
            XCTAssertEqual(error, .aboveMaximum(points: 700, maximum: 600))
        }
    }

    // MARK: - Redemption Tests

    func testSuccessfulRedemption() throws {
        // Give child 100 points
        ledger.recordAccrual(childId: childId, points: 100)

        // Redeem 50 points (should get 5 minutes)
        let window = try service.redeem(childId: childId, points: 50, config: config)

        XCTAssertEqual(window.childId, childId)
        XCTAssertEqual(window.durationSeconds, 300) // 5 minutes = 300 seconds
        XCTAssertEqual(ledger.getBalance(childId: childId), 50) // 100 - 50
    }

    func testRedemptionDeductsPoints() throws {
        ledger.recordAccrual(childId: childId, points: 200)

        let initialBalance = ledger.getBalance(childId: childId)
        XCTAssertEqual(initialBalance, 200)

        _ = try service.redeem(childId: childId, points: 100, config: config)

        let finalBalance = ledger.getBalance(childId: childId)
        XCTAssertEqual(finalBalance, 100)
    }

    func testRedemptionFailsWithInsufficientBalance() {
        ledger.recordAccrual(childId: childId, points: 40)

        XCTAssertThrowsError(try service.redeem(childId: childId, points: 50, config: config)) { error in
            XCTAssertEqual(error as? RedemptionError, .insufficientBalance(available: 40, required: 50))
        }

        // Balance should not change on failed redemption
        XCTAssertEqual(ledger.getBalance(childId: childId), 40)
    }

    func testRedemptionFailsBelowMinimum() {
        ledger.recordAccrual(childId: childId, points: 100)

        XCTAssertThrowsError(try service.redeem(childId: childId, points: 20, config: config)) { error in
            XCTAssertEqual(error as? RedemptionError, .belowMinimum(points: 20, minimum: 30))
        }
    }

    func testRedemptionFailsAboveMaximum() {
        ledger.recordAccrual(childId: childId, points: 1000)

        XCTAssertThrowsError(try service.redeem(childId: childId, points: 700, config: config)) { error in
            XCTAssertEqual(error as? RedemptionError, .aboveMaximum(points: 700, maximum: 600))
        }
    }

    // MARK: - Helper Tests

    func testCalculateMinutes() {
        let minutes = service.calculateMinutes(points: 100, config: config)
        XCTAssertEqual(minutes, 10.0) // 100 points / 10 points per minute
    }

    func testCalculatePointsNeeded() {
        let points = service.calculatePointsNeeded(minutes: 15, config: config)
        XCTAssertEqual(points, 150) // 15 minutes * 10 points per minute
    }

    // MARK: - Edge Cases

    func testRedeemExactMinimum() throws {
        ledger.recordAccrual(childId: childId, points: 30)

        let window = try service.redeem(childId: childId, points: 30, config: config)

        XCTAssertEqual(window.durationSeconds, 180) // 3 minutes
        XCTAssertEqual(ledger.getBalance(childId: childId), 0)
    }

    func testRedeemExactMaximum() throws {
        ledger.recordAccrual(childId: childId, points: 600)

        let window = try service.redeem(childId: childId, points: 600, config: config)

        XCTAssertEqual(window.durationSeconds, 3600) // 60 minutes
        XCTAssertEqual(ledger.getBalance(childId: childId), 0)
    }

    func testMultipleRedemptions() throws {
        ledger.recordAccrual(childId: childId, points: 300)

        // First redemption
        let window1 = try service.redeem(childId: childId, points: 100, config: config)
        XCTAssertEqual(window1.durationSeconds, 600) // 10 minutes
        XCTAssertEqual(ledger.getBalance(childId: childId), 200)

        // Second redemption
        let window2 = try service.redeem(childId: childId, points: 100, config: config)
        XCTAssertEqual(window2.durationSeconds, 600) // 10 minutes
        XCTAssertEqual(ledger.getBalance(childId: childId), 100)

        // Third redemption (remaining balance)
        let window3 = try service.redeem(childId: childId, points: 100, config: config)
        XCTAssertEqual(window3.durationSeconds, 600) // 10 minutes
        XCTAssertEqual(ledger.getBalance(childId: childId), 0)
    }
}
