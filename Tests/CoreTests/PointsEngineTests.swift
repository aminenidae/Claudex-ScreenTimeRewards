import XCTest
@testable import PointsEngine
@testable import Core

final class PointsEngineTests: XCTestCase {
    var engine: PointsEngine!
    var childId: ChildID!

    override func setUp() {
        super.setUp()
        engine = PointsEngine()
        childId = ChildID("test-child-123")
    }

    override func tearDown() {
        engine = nil
        childId = nil
        super.tearDown()
    }

    // MARK: - Basic Session Tests

    func testStartSession() {
        let session = engine.startSession(childId: childId)

        XCTAssertEqual(session.childId, childId)
        XCTAssertNil(session.endTime)
        XCTAssertEqual(session.startTime, session.lastActivityTime)
    }

    func testUpdateActivity() {
        let session = engine.startSession(childId: childId)
        sleep(1)

        let updated = engine.updateActivity(session: session)

        XCTAssertGreaterThan(updated.lastActivityTime, session.lastActivityTime)
    }

    func testEndSession() {
        let config = PointsConfiguration(pointsPerMinute: 10, dailyCapPoints: 600, idleTimeoutSeconds: 180)
        let startTime = Date()
        let session = engine.startSession(childId: childId, at: startTime)

        // Simulate 5 minutes of learning
        let endTime = startTime.addingTimeInterval(300) // 5 minutes
        let result = engine.endSession(session: session, config: config, at: endTime)

        XCTAssertEqual(result.session.endTime, endTime)
        XCTAssertEqual(result.pointsEarned, 50) // 5 min * 10 points/min
    }

    // MARK: - Idle Timeout Tests

    func testIdleTimeoutExcludesInactiveTime() {
        let config = PointsConfiguration(pointsPerMinute: 10, dailyCapPoints: 600, idleTimeoutSeconds: 180)
        let startTime = Date()
        let session = engine.startSession(childId: childId, at: startTime)

        // Last activity at 5 minutes
        let lastActivityTime = startTime.addingTimeInterval(300)
        var updated = session
        updated.lastActivityTime = lastActivityTime

        // End session 10 minutes after last activity (should only count 5 min)
        updated.endTime = lastActivityTime.addingTimeInterval(600)

        let points = engine.calculatePoints(for: updated, config: config)

        XCTAssertEqual(points, 50) // Only 5 minutes counted
    }

    func testNoIdleTimeoutWhenActive() {
        let config = PointsConfiguration(pointsPerMinute: 10, dailyCapPoints: 600, idleTimeoutSeconds: 180)
        let startTime = Date()
        let session = engine.startSession(childId: childId, at: startTime)

        // Last activity at 4.5 minutes
        let lastActivityTime = startTime.addingTimeInterval(270)
        var updated = session
        updated.lastActivityTime = lastActivityTime

        // End session 1 minute later (within idle timeout)
        updated.endTime = lastActivityTime.addingTimeInterval(60)

        let points = engine.calculatePoints(for: updated, config: config)

        XCTAssertEqual(points, 55) // Full 5.5 minutes counted
    }

    // MARK: - Daily Cap Tests

    func testDailyCapEnforcement() {
        engine.resetDailyAccruals(childId: childId)

        let config = PointsConfiguration(pointsPerMinute: 10, dailyCapPoints: 100, idleTimeoutSeconds: 180)
        let startTime = Date()

        // First session: 8 minutes = 80 points
        let session1 = engine.startSession(childId: childId, at: startTime)
        let end1 = startTime.addingTimeInterval(480)
        let result1 = engine.endSession(session: session1, config: config, at: end1)

        XCTAssertEqual(result1.pointsEarned, 80)
        XCTAssertTrue(engine.canAccruePoints(childId: childId, config: config))

        // Second session: 5 minutes = 50 points, but only 20 points left in cap
        let session2 = engine.startSession(childId: childId, at: end1)
        let end2 = end1.addingTimeInterval(300)
        let result2 = engine.endSession(session: session2, config: config, at: end2)

        XCTAssertEqual(result2.pointsEarned, 20) // Capped at daily limit
        XCTAssertFalse(engine.canAccruePoints(childId: childId, config: config))

        // Third session: 0 points (cap reached)
        let session3 = engine.startSession(childId: childId, at: end2)
        let end3 = end2.addingTimeInterval(300)
        let result3 = engine.endSession(session: session3, config: config, at: end3)

        XCTAssertEqual(result3.pointsEarned, 0)
    }

    func testGetTodayPoints() {
        engine.resetDailyAccruals(childId: childId)

        let config = PointsConfiguration.default
        let startTime = Date()
        let session = engine.startSession(childId: childId, at: startTime)
        let endTime = startTime.addingTimeInterval(300) // 5 minutes
        _ = engine.endSession(session: session, config: config, at: endTime)

        XCTAssertEqual(engine.getTodayPoints(childId: childId), 50)
    }

    func testPerAppAccrualsRespectDailyCapsIndependently() {
        engine.resetDailyAccruals(childId: childId)

        let mathApp = AppIdentifier("app.math")
        let readingApp = AppIdentifier("app.reading")
        let config = PointsConfiguration(pointsPerMinute: 10, dailyCapPoints: 100, idleTimeoutSeconds: 180)
        let startTime = Date()

        // Math app hits the cap (10 minutes * 10 = 100)
        let mathSession = engine.startSession(childId: childId, appId: mathApp, at: startTime)
        let mathEnd = startTime.addingTimeInterval(600)
        let mathResult = engine.endSession(session: mathSession, config: config, at: mathEnd)

        XCTAssertEqual(mathResult.pointsEarned, 100)
        XCTAssertEqual(engine.getTodayPoints(childId: childId, appId: mathApp), 100)
        XCTAssertFalse(engine.canAccruePoints(childId: childId, appId: mathApp, config: config))

        // Reading app still has full cap available and should accrue normally
        let readingStart = mathEnd
        let readingSession = engine.startSession(childId: childId, appId: readingApp, at: readingStart)
        let readingEnd = readingStart.addingTimeInterval(300)
        let readingResult = engine.endSession(session: readingSession, config: config, at: readingEnd)

        XCTAssertEqual(readingResult.pointsEarned, 50)
        XCTAssertEqual(engine.getTodayPoints(childId: childId, appId: readingApp), 50)
        XCTAssertTrue(engine.canAccruePoints(childId: childId, appId: readingApp, config: config))

        // Global total should combine both apps
        XCTAssertEqual(engine.getTodayPoints(childId: childId), 150)
    }

    func testEndSessionWithoutAppIdentifierStillTracksGlobalTotal() {
        engine.resetDailyAccruals(childId: childId)

        let config = PointsConfiguration(pointsPerMinute: 10, dailyCapPoints: 100, idleTimeoutSeconds: 180)
        let startTime = Date()
        let session = engine.startSession(childId: childId, at: startTime)
        let endTime = startTime.addingTimeInterval(600)
        let result = engine.endSession(session: session, config: config, at: endTime)

        XCTAssertEqual(result.pointsEarned, 100)
        XCTAssertEqual(engine.getTodayPoints(childId: childId), 100)
    }

    // MARK: - Multiple Children Tests

    func testMultipleChildrenIndependentAccruals() {
        let child1 = ChildID("child-1")
        let child2 = ChildID("child-2")

        let config = PointsConfiguration(pointsPerMinute: 10, dailyCapPoints: 600, idleTimeoutSeconds: 180)
        let startTime = Date()

        // Child 1: 3 minutes
        let session1 = engine.startSession(childId: child1, at: startTime)
        let end1 = startTime.addingTimeInterval(180)
        let result1 = engine.endSession(session: session1, config: config, at: end1)

        // Child 2: 7 minutes
        let session2 = engine.startSession(childId: child2, at: startTime)
        let end2 = startTime.addingTimeInterval(420)
        let result2 = engine.endSession(session: session2, config: config, at: end2)

        XCTAssertEqual(result1.pointsEarned, 30)
        XCTAssertEqual(result2.pointsEarned, 70)
        XCTAssertEqual(engine.getTodayPoints(childId: child1), 30)
        XCTAssertEqual(engine.getTodayPoints(childId: child2), 70)
    }

    // MARK: - Edge Cases

    func testZeroDurationSession() {
        let config = PointsConfiguration.default
        let session = engine.startSession(childId: childId)
        let result = engine.endSession(session: session, config: config, at: session.startTime)

        XCTAssertEqual(result.pointsEarned, 0)
    }

    func testNegativeTimeProtection() {
        let startTime = Date()
        let session = engine.startSession(childId: childId, at: startTime)

        // Try to end before start (clock issue)
        let endTime = startTime.addingTimeInterval(-100)
        var completed = session
        completed.endTime = endTime

        let config = PointsConfiguration.default
        let points = engine.calculatePoints(for: completed, config: config)

        XCTAssertEqual(points, 0) // Should not award negative points
    }
}
