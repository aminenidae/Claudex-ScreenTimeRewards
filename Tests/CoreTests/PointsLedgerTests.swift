import XCTest
@testable import PointsEngine
@testable import Core

@MainActor
final class PointsLedgerTests: XCTestCase {
    var ledger: PointsLedger!
    var childId: ChildID!
    var auditLog: MockAuditLog!

    override func setUp() {
        super.setUp()
        auditLog = MockAuditLog()
        let auditLog = AuditLog()
        ledger = PointsLedger(auditLog: auditLog)
        childId = ChildID("test-child-456")
    }

    override func tearDown() {
        ledger.clear()
        ledger = nil
        childId = nil
        auditLog = nil
        super.tearDown()
    }

    // MARK: - Recording Tests

    func testRecordAccrual() {
        let entry = ledger.recordAccrual(childId: childId, points: 50)

        XCTAssertEqual(entry.type, .accrual)
        XCTAssertEqual(entry.amount, 50)
        XCTAssertEqual(entry.childId, childId)
    }

    func testRecordRedemption() {
        let entry = ledger.recordRedemption(childId: childId, points: 30)

        XCTAssertEqual(entry.type, .redemption)
        XCTAssertEqual(entry.amount, -30) // Should be negative
        XCTAssertEqual(entry.childId, childId)
    }

    func testRecordAdjustment() {
        let entry = ledger.recordAdjustment(childId: childId, points: 10, reason: "Bonus")

        XCTAssertEqual(entry.type, .adjustment)
        XCTAssertEqual(entry.amount, 10)
        XCTAssertEqual(entry.childId, childId)
    }

    // MARK: - Balance Tests

    func testGetBalanceEmpty() {
        XCTAssertEqual(ledger.getBalance(childId: childId), 0)
    }

    func testGetBalanceWithAccruals() {
        ledger.recordAccrual(childId: childId, points: 50)
        ledger.recordAccrual(childId: childId, points: 30)

        XCTAssertEqual(ledger.getBalance(childId: childId), 80)
    }

    func testGetBalanceWithRedemptions() {
        ledger.recordAccrual(childId: childId, points: 100)
        ledger.recordRedemption(childId: childId, points: 30)
        ledger.recordRedemption(childId: childId, points: 20)

        XCTAssertEqual(ledger.getBalance(childId: childId), 50)
    }

    func testGetBalanceWithMixedTransactions() {
        ledger.recordAccrual(childId: childId, points: 100)
        ledger.recordRedemption(childId: childId, points: 30)
        ledger.recordAdjustment(childId: childId, points: 15, reason: "Bonus")
        ledger.recordRedemption(childId: childId, points: 20)

        XCTAssertEqual(ledger.getBalance(childId: childId), 65)
    }

    func testGetBalancePerApp() {
        let mathApp = AppIdentifier("app.math")
        let readingApp = AppIdentifier("app.reading")

        ledger.recordAccrual(childId: childId, appId: mathApp, points: 100)
        ledger.recordAccrual(childId: childId, appId: readingApp, points: 50)
        ledger.recordRedemption(childId: childId, appId: mathApp, points: 40)

        XCTAssertEqual(ledger.getBalance(childId: childId, appId: mathApp), 60)
        XCTAssertEqual(ledger.getBalance(childId: childId, appId: readingApp), 50)
        XCTAssertEqual(ledger.getBalance(childId: childId), 110)
    }

    func testGetBalancesDictionary() {
        let mathApp = AppIdentifier("app.math")
        let readingApp = AppIdentifier("app.reading")

        ledger.recordAccrual(childId: childId, appId: mathApp, points: 20)
        ledger.recordAccrual(childId: childId, appId: readingApp, points: 30)
        ledger.recordAdjustment(childId: childId, appId: mathApp, points: 10, reason: "Bonus")

        let balances = ledger.getBalances(childId: childId)
        XCTAssertEqual(balances[mathApp], 30)
        XCTAssertEqual(balances[readingApp], 30)
    }

    // MARK: - Query Tests

    func testGetEntriesOrdered() {
        let entry1 = ledger.recordAccrual(childId: childId, points: 10)
        sleep(1)
        let entry2 = ledger.recordAccrual(childId: childId, points: 20)

        let entries = ledger.getEntries(childId: childId)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].id, entry2.id) // Most recent first
        XCTAssertEqual(entries[1].id, entry1.id)
    }

    func testGetEntriesWithLimit() {
        ledger.recordAccrual(childId: childId, points: 10)
        ledger.recordAccrual(childId: childId, points: 20)
        ledger.recordAccrual(childId: childId, points: 30)

        let entries = ledger.getEntries(childId: childId, limit: 2)

        XCTAssertEqual(entries.count, 2)
    }

    func testGetEntriesInRange() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)

        ledger.recordAccrual(childId: childId, points: 10, timestamp: yesterday)
        ledger.recordAccrual(childId: childId, points: 20, timestamp: now)
        ledger.recordAccrual(childId: childId, points: 30, timestamp: tomorrow)

        let entries = ledger.getEntriesInRange(
            childId: childId,
            from: yesterday.addingTimeInterval(3600),
            to: tomorrow.addingTimeInterval(-3600)
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].amount, 20)
    }

    // MARK: - Today Queries

    func testGetTodayEntries() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)

        ledger.recordAccrual(childId: childId, points: 10, timestamp: yesterday)
        ledger.recordAccrual(childId: childId, points: 20, timestamp: now)
        ledger.recordAccrual(childId: childId, points: 30, timestamp: now)

        let todayEntries = ledger.getTodayEntries(childId: childId)

        XCTAssertEqual(todayEntries.count, 2)
    }

    func testGetTodayAccrual() {
        let now = Date()

        ledger.recordAccrual(childId: childId, points: 50, timestamp: now)
        ledger.recordRedemption(childId: childId, points: 20, timestamp: now)
        ledger.recordAccrual(childId: childId, points: 30, timestamp: now)

        let todayAccrual = ledger.getTodayAccrual(childId: childId)

        XCTAssertEqual(todayAccrual, 80) // Only accruals, not redemptions
    }

    // MARK: - Multiple Children

    func testMultipleChildrenIsolation() {
        let child1 = ChildID("child-1")
        let child2 = ChildID("child-2")

        ledger.recordAccrual(childId: child1, points: 50)
        ledger.recordAccrual(childId: child2, points: 75)

        XCTAssertEqual(ledger.getBalance(childId: child1), 50)
        XCTAssertEqual(ledger.getBalance(childId: child2), 75)

        let entries1 = ledger.getEntries(childId: child1)
        let entries2 = ledger.getEntries(childId: child2)

        XCTAssertEqual(entries1.count, 1)
        XCTAssertEqual(entries2.count, 1)
    }

    // MARK: - Persistence Tests

    func testSaveAndLoad() throws {
        // Use fresh ledgers to avoid test interference
        let auditLog1 = AuditLog()
        let saveLedger = PointsLedger(auditLog: auditLog1)
        _ = saveLedger.recordAccrual(childId: childId, points: 100)
        _ = saveLedger.recordRedemption(childId: childId, points: 30)

        // Wait for async operations to complete
        Thread.sleep(forTimeInterval: 0.1)

        try saveLedger.save()

        let auditLog2 = AuditLog()
        let loadLedger = PointsLedger(auditLog: auditLog2)
        try loadLedger.load()

        XCTAssertEqual(loadLedger.getBalance(childId: childId), 70)
        XCTAssertEqual(loadLedger.getEntries(childId: childId).count, 2)
    }

    func testClear() {
        _ = ledger.recordAccrual(childId: childId, points: 100)
        ledger.clear()

        XCTAssertEqual(ledger.getBalance(childId: childId), 0)
        XCTAssertEqual(ledger.getEntries(childId: childId).count, 0)
    }

    // MARK: - Audit Log

    func testAuditLogRecordsRedemptionsAndAdjustments() {
        let redemption = ledger.recordRedemption(childId: childId, points: 40)
        let adjustment = ledger.recordAdjustment(childId: childId, points: 15, reason: "Bonus")

        // Ensure ledger still stores entries
        XCTAssertEqual(redemption.type, .redemption)
        XCTAssertEqual(adjustment.type, .adjustment)

        let entries = auditLog.entries(for: childId)
        XCTAssertEqual(entries.count, 2)

        let redemptionAudit = entries.first { $0.action == "redemption" }
        XCTAssertNotNil(redemptionAudit)
        XCTAssertEqual(redemptionAudit?.details?["points"], "-40")

        let adjustmentAudit = entries.first { $0.action == "adjustment" }
        XCTAssertNotNil(adjustmentAudit)
        XCTAssertEqual(adjustmentAudit?.details?["points"], "15")
        XCTAssertEqual(adjustmentAudit?.details?["reason"], "Bonus")
    }
}

// MARK: - Helpers

final class MockAuditLog: AuditLogProtocol {
    private(set) var recorded: [AuditEntry] = []

    func record(entry: AuditEntry) {
        recorded.append(entry)
    }

    func entries(for childId: ChildID) -> [AuditEntry] {
        recorded.filter { $0.childId == childId }
    }

    func allEntries() -> [AuditEntry] {
        recorded
    }

    func clear() {
        recorded.removeAll()
    }
}
