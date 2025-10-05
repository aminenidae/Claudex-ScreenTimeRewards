import Foundation
#if canImport(Core)
import Core
#endif

public protocol PointsEngineProtocol {
    func startSession(childId: ChildID, at time: Date) -> UsageSession
    func updateActivity(session: UsageSession, at time: Date) -> UsageSession
    func endSession(session: UsageSession, config: PointsConfiguration, at time: Date) -> (session: UsageSession, pointsEarned: Int)
    func calculatePoints(for session: UsageSession, config: PointsConfiguration) -> Int
    func getTodayPoints(childId: ChildID) -> Int
    func canAccruePoints(childId: ChildID, config: PointsConfiguration) -> Bool
}

public final class PointsEngine: PointsEngineProtocol {
    private var activeSessions: [ChildID: UsageSession] = [:]
    private var dailyAccruals: [ChildID: [Date: Int]] = [:]
    private let calendar = Calendar.current

    public init() {}

    // MARK: - Session Management

    /// Start a new learning session for a child
    public func startSession(childId: ChildID, at time: Date = Date()) -> UsageSession {
        let session = UsageSession(
            childId: childId,
            startTime: time,
            endTime: nil,
            lastActivityTime: time
        )
        activeSessions[childId] = session
        return session
    }

    /// Update last activity time (prevents idle timeout)
    public func updateActivity(session: UsageSession, at time: Date = Date()) -> UsageSession {
        var updated = session
        updated.lastActivityTime = time
        activeSessions[session.childId] = updated
        return updated
    }

    /// End session and calculate final points earned
    public func endSession(session: UsageSession, config: PointsConfiguration = .default, at time: Date = Date()) -> (session: UsageSession, pointsEarned: Int) {
        var completed = session
        completed.endTime = time

        let points = calculatePoints(for: completed, config: config)

        // Record daily accrual
        let today = calendar.startOfDay(for: time)
        let currentDaily = dailyAccruals[session.childId, default: [:]][today, default: 0]
        let cappedPoints = min(points, config.dailyCapPoints - currentDaily)

        if cappedPoints > 0 {
            dailyAccruals[session.childId, default: [:]][today, default: 0] += cappedPoints
        }

        activeSessions[session.childId] = nil

        return (completed, cappedPoints)
    }

    // MARK: - Points Calculation

    /// Calculate points for a session with idle timeout enforcement
    public func calculatePoints(for session: UsageSession, config: PointsConfiguration) -> Int {
        let effectiveDuration = calculateEffectiveDuration(for: session, config: config)
        let minutes = effectiveDuration / 60.0
        let points = Int(minutes * Double(config.pointsPerMinute))
        return max(0, points)
    }

    /// Calculate effective duration accounting for idle timeout
    private func calculateEffectiveDuration(for session: UsageSession, config: PointsConfiguration) -> TimeInterval {
        guard let endTime = session.endTime else {
            // Active session - check if currently idle
            let timeSinceActivity = Date().timeIntervalSince(session.lastActivityTime)
            if timeSinceActivity > config.idleTimeoutSeconds {
                // Currently idle - only count up to last activity
                return session.lastActivityTime.timeIntervalSince(session.startTime)
            }
            return session.durationSeconds
        }

        // Completed session - check if ended while idle
        // Only apply idle timeout if lastActivityTime was explicitly updated (different from startTime)
        let activityWasUpdated = session.lastActivityTime > session.startTime
        if activityWasUpdated {
            let timeSinceActivity = endTime.timeIntervalSince(session.lastActivityTime)
            if timeSinceActivity > config.idleTimeoutSeconds {
                // Was idle at end - only count up to last activity
                return max(0, session.lastActivityTime.timeIntervalSince(session.startTime))
            }
        }

        return session.durationSeconds
    }

    // MARK: - Daily Cap Management

    /// Get total points accrued today for a child
    public func getTodayPoints(childId: ChildID) -> Int {
        let today = calendar.startOfDay(for: Date())
        return dailyAccruals[childId, default: [:]][today, default: 0]
    }

    /// Check if child can still accrue points today (under daily cap)
    public func canAccruePoints(childId: ChildID, config: PointsConfiguration) -> Bool {
        getTodayPoints(childId: childId) < config.dailyCapPoints
    }

    // MARK: - State Access (for testing/debugging)

    public func getActiveSession(childId: ChildID) -> UsageSession? {
        activeSessions[childId]
    }

    public func resetDailyAccruals(childId: ChildID) {
        dailyAccruals[childId] = [:]
    }

    // MARK: - Legacy method (deprecated)

    @available(*, deprecated, message: "Use session-based methods instead")
    public func accrue(pointsPerMinute: Int, minutes: Int) -> Int {
        max(0, pointsPerMinute * minutes)
    }
}
