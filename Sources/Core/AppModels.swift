import Foundation

public struct FamilyID: Hashable, Codable { public let rawValue: String; public init(_ v: String) { self.rawValue = v } }
public struct ChildID: Hashable, Codable { public let rawValue: String; public init(_ v: String) { self.rawValue = v } }

public enum AppClassification: String, Codable { case learning, reward }

public struct PointsLedgerEntry: Codable, Identifiable {
    public enum EntryType: String, Codable { case accrual, redemption, adjustment }
    public let id: UUID
    public let childId: ChildID
    public let type: EntryType
    public let amount: Int
    public let timestamp: Date
    public init(id: UUID = .init(), childId: ChildID, type: EntryType, amount: Int, timestamp: Date = .init()) {
        self.id = id; self.childId = childId; self.type = type; self.amount = amount; self.timestamp = timestamp
    }
}

public struct UsageSession: Codable, Identifiable {
    public let id: UUID
    public let childId: ChildID
    public let startTime: Date
    public var endTime: Date?
    public var lastActivityTime: Date
    public var durationSeconds: TimeInterval {
        let end = endTime ?? Date()
        return max(0, end.timeIntervalSince(startTime))
    }

    public init(id: UUID = .init(), childId: ChildID, startTime: Date = .init(), endTime: Date? = nil, lastActivityTime: Date = .init()) {
        self.id = id
        self.childId = childId
        self.startTime = startTime
        self.endTime = endTime
        self.lastActivityTime = lastActivityTime
    }
}

public struct PointsConfiguration: Codable {
    public let pointsPerMinute: Int
    public let dailyCapPoints: Int
    public let idleTimeoutSeconds: TimeInterval

    public init(pointsPerMinute: Int = 10, dailyCapPoints: Int = 600, idleTimeoutSeconds: TimeInterval = 180) {
        self.pointsPerMinute = pointsPerMinute
        self.dailyCapPoints = dailyCapPoints
        self.idleTimeoutSeconds = idleTimeoutSeconds
    }

    public static let `default` = PointsConfiguration()
}

public struct RedemptionConfiguration: Codable {
    public let pointsPerMinute: Int        // Points required per minute of earned time
    public let minRedemptionPoints: Int    // Minimum points to redeem
    public let maxRedemptionPoints: Int    // Maximum points per redemption
    public let maxTotalMinutes: Int        // Max accumulated earned time (for stacking)

    public init(
        pointsPerMinute: Int = 10,
        minRedemptionPoints: Int = 30,
        maxRedemptionPoints: Int = 600,
        maxTotalMinutes: Int = 120
    ) {
        self.pointsPerMinute = pointsPerMinute
        self.minRedemptionPoints = minRedemptionPoints
        self.maxRedemptionPoints = maxRedemptionPoints
        self.maxTotalMinutes = maxTotalMinutes
    }

    public static let `default` = RedemptionConfiguration()
}

public struct EarnedTimeWindow: Codable, Identifiable {
    public let id: UUID
    public let childId: ChildID
    public let durationSeconds: TimeInterval
    public let startTime: Date

    public var endTime: Date {
        startTime.addingTimeInterval(durationSeconds)
    }

    public var remainingSeconds: TimeInterval {
        max(0, endTime.timeIntervalSince(Date()))
    }

    public var isExpired: Bool {
        Date() >= endTime
    }

    public init(
        id: UUID = .init(),
        childId: ChildID,
        durationSeconds: TimeInterval,
        startTime: Date = .init()
    ) {
        self.id = id
        self.childId = childId
        self.durationSeconds = durationSeconds
        self.startTime = startTime
    }
}

public enum ExemptionStackingPolicy: String, Codable {
    case replace        // New redemption replaces current window
    case extend         // Add time to existing window (respects max)
    case queue          // Queue next window after current expires
    case block          // Prevent redemption until current expires
}

// MARK: - Protocols

public protocol PointsLedgerProtocol {
    func recordAccrual(childId: ChildID, points: Int, timestamp: Date) -> PointsLedgerEntry
    func recordRedemption(childId: ChildID, points: Int, timestamp: Date) -> PointsLedgerEntry
    func recordAdjustment(childId: ChildID, points: Int, reason: String, timestamp: Date) -> PointsLedgerEntry
    func getBalance(childId: ChildID) -> Int
    func getEntries(childId: ChildID) -> [PointsLedgerEntry]
    func getEntries(childId: ChildID, limit: Int?) -> [PointsLedgerEntry]
    func getEntriesInRange(childId: ChildID, from: Date, to: Date) -> [PointsLedgerEntry]
}

