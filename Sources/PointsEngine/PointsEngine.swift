import Foundation
#if canImport(Core)
import Core
#endif

public protocol PointsEngineProtocol {
    func startSession(childId: ChildID, appId: AppIdentifier?, at time: Date) -> UsageSession
    func updateActivity(session: UsageSession, at time: Date) -> UsageSession
    func endSession(session: UsageSession, config: PointsConfiguration, at time: Date) -> (session: UsageSession, pointsEarned: Int)
    func calculatePoints(for session: UsageSession, config: PointsConfiguration) -> Int
    func getTodayPoints(childId: ChildID) -> Int
    func getTodayPoints(childId: ChildID, appId: AppIdentifier) -> Int
    func canAccruePoints(childId: ChildID, appId: AppIdentifier?, config: PointsConfiguration) -> Bool
}

public final class PointsEngine: PointsEngineProtocol {
    private struct SessionKey: Hashable {
        let childId: ChildID
        let appIdRaw: String?
    }

    private struct ChildDailyAccruals {
        var totals: [Date: Int] = [:]
        var perApp: [AppIdentifier: [Date: Int]] = [:]
    }

    private var activeSessions: [SessionKey: UsageSession] = [:]
    private var dailyAccruals: [ChildID: ChildDailyAccruals] = [:]
    private let calendar = Calendar.current

    public init() {}

    // MARK: - Session Management

    /// Start a new learning session for a child
    public func startSession(childId: ChildID, appId: AppIdentifier? = nil, at time: Date = Date()) -> UsageSession {
        let session = UsageSession(
            childId: childId,
            appId: appId,
            startTime: time,
            endTime: nil,
            lastActivityTime: time
        )
        activeSessions[sessionKey(childId: childId, appId: appId)] = session
        return session
    }

    /// Update last activity time (prevents idle timeout)
    public func updateActivity(session: UsageSession, at time: Date = Date()) -> UsageSession {
        var updated = session
        updated.lastActivityTime = time
        activeSessions[sessionKey(for: session)] = updated
        return updated
    }

    /// End session and calculate final points earned
    public func endSession(session: UsageSession, config: PointsConfiguration = .default, at time: Date = Date()) -> (session: UsageSession, pointsEarned: Int) {
        var completed = session
        completed.endTime = time

        let points = calculatePoints(for: completed, config: config)

        // Record daily accrual
        let today = calendar.startOfDay(for: time)
        var childAccruals = dailyAccruals[session.childId, default: ChildDailyAccruals()]

        let currentAppDaily: Int
        if let appId = session.appId {
            currentAppDaily = childAccruals.perApp[appId]?[today] ?? 0
        } else {
            currentAppDaily = childAccruals.totals[today] ?? 0
        }

        let remaining = max(0, config.dailyCapPoints - currentAppDaily)
        let cappedPoints = min(points, remaining)

        if cappedPoints > 0 {
            childAccruals.totals[today, default: 0] += cappedPoints

            if let appId = session.appId {
                var perApp = childAccruals.perApp[appId] ?? [:]
                perApp[today, default: 0] += cappedPoints
                childAccruals.perApp[appId] = perApp
            }

            dailyAccruals[session.childId] = childAccruals
        }

        activeSessions[sessionKey(for: session)] = nil

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
        return dailyAccruals[childId]?.totals[today] ?? 0
    }

    /// Get total points accrued today for a child/app combination
    public func getTodayPoints(childId: ChildID, appId: AppIdentifier) -> Int {
        let today = calendar.startOfDay(for: Date())
        return dailyAccruals[childId]?.perApp[appId]?[today] ?? 0
    }

    /// Check if child can still accrue points today (under daily cap)
    public func canAccruePoints(childId: ChildID, appId: AppIdentifier? = nil, config: PointsConfiguration) -> Bool {
        let current = appId.map { getTodayPoints(childId: childId, appId: $0) } ?? getTodayPoints(childId: childId)
        return current < config.dailyCapPoints
    }

    // MARK: - State Access (for testing/debugging)

    public func getActiveSession(childId: ChildID, appId: AppIdentifier? = nil) -> UsageSession? {
        activeSessions[sessionKey(childId: childId, appId: appId)]
    }

    public func resetDailyAccruals(childId: ChildID) {
        dailyAccruals[childId] = ChildDailyAccruals()
    }

    // MARK: - Legacy method (deprecated)

    @available(*, deprecated, message: "Use session-based methods instead")
    public func accrue(pointsPerMinute: Int, minutes: Int) -> Int {
        max(0, pointsPerMinute * minutes)
    }
}

private extension PointsEngine {
    private func sessionKey(for session: UsageSession) -> SessionKey {
        sessionKey(childId: session.childId, appId: session.appId)
    }

    private func sessionKey(childId: ChildID, appId: AppIdentifier?) -> SessionKey {
        SessionKey(childId: childId, appIdRaw: appId?.rawValue)
    }
}
