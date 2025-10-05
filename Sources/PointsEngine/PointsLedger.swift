import Foundation
#if canImport(Core)
import Core
#endif

public final class PointsLedger: ObservableObject, PointsLedgerProtocol {
    @Published private var entries: [PointsLedgerEntry] = []
    private let queue = DispatchQueue(label: "com.claudex.pointsledger", attributes: .concurrent)
    private let auditLog: AuditLogProtocol?

    public init(auditLog: AuditLogProtocol? = nil) {
        self.auditLog = auditLog
    }

    // MARK: - Recording Transactions

    @MainActor
    public func recordAccrual(childId: ChildID, points: Int, timestamp: Date = Date()) -> PointsLedgerEntry {
        let entry = PointsLedgerEntry(
            childId: childId,
            type: .accrual,
            amount: points,
            timestamp: timestamp
        )
        queue.async(flags: .barrier) {
            Task { @MainActor in
                self.entries.append(entry)
            }
        }
        return entry
    }

    @MainActor
    public func recordRedemption(childId: ChildID, points: Int, timestamp: Date = Date()) -> PointsLedgerEntry {
        let entry = PointsLedgerEntry(
            childId: childId,
            type: .redemption,
            amount: -abs(points), // Redemptions are negative
            timestamp: timestamp
        )
        queue.async(flags: .barrier) {
            Task { @MainActor in
                self.entries.append(entry)
                self.logAudit(action: "redemption", childId: childId, points: -abs(points), timestamp: timestamp, extra: nil)
            }
        }
        return entry
    }

    @MainActor
    public func recordAdjustment(childId: ChildID, points: Int, reason: String, timestamp: Date = Date()) -> PointsLedgerEntry {
        let entry = PointsLedgerEntry(
            childId: childId,
            type: .adjustment,
            amount: points,
            timestamp: timestamp
        )
        queue.async(flags: .barrier) {
            Task { @MainActor in
                self.entries.append(entry)
                self.logAudit(
                    action: "adjustment",
                    childId: childId,
                    points: points,
                    timestamp: timestamp,
                    extra: ["reason": reason]
                )
            }
        }
        return entry
    }

    // MARK: - Balance Calculation

    public func getBalance(childId: ChildID) -> Int {
        queue.sync {
            entries
                .filter { $0.childId == childId }
                .reduce(0) { $0 + $1.amount }
        }
    }

    // MARK: - Query Methods

    public func getEntries(childId: ChildID) -> [PointsLedgerEntry] {
        getEntries(childId: childId, limit: nil)
    }

    public func getEntries(childId: ChildID, limit: Int? = nil) -> [PointsLedgerEntry] {
        queue.sync {
            let filtered = entries
                .filter { $0.childId == childId }
                .sorted { $0.timestamp > $1.timestamp }

            if let limit = limit {
                return Array(filtered.prefix(limit))
            }
            return filtered
        }
    }

    public func getEntriesInRange(childId: ChildID, from: Date, to: Date) -> [PointsLedgerEntry] {
        queue.sync {
            entries
                .filter { $0.childId == childId }
                .filter { $0.timestamp >= from && $0.timestamp <= to }
                .sorted { $0.timestamp > $1.timestamp }
        }
    }

    // MARK: - Bulk Operations

    public func getTodayEntries(childId: ChildID, calendar: Calendar = .current) -> [PointsLedgerEntry] {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return getEntriesInRange(childId: childId, from: today, to: tomorrow)
    }

    public func getTodayAccrual(childId: ChildID, calendar: Calendar = .current) -> Int {
        getTodayEntries(childId: childId, calendar: calendar)
            .filter { $0.type == .accrual }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Persistence (File-based for MVP, CloudKit later)

    private var storageURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("points_ledger.json")
    }

    @MainActor
    public func save() throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: storageURL)
    }

    @MainActor
    public func load() throws {
        let data = try Data(contentsOf: storageURL)
        entries = try JSONDecoder().decode([PointsLedgerEntry].self, from: data)
    }

    @MainActor
    public func clear() {
        queue.async(flags: .barrier) {
            Task { @MainActor in
                self.entries.removeAll()
            }
        }
    }
}

// MARK: - Audit Helpers

private extension PointsLedger {
    func logAudit(
        action: String,
        childId: ChildID,
        points: Int,
        timestamp: Date,
        extra: [String: String]?
    ) {
        guard let auditLog else { return }
        var details = extra ?? [:]
        details["points"] = String(points)
        let entry = AuditEntry(childId: childId, action: action, timestamp: timestamp, details: details)
        auditLog.record(entry: entry)
    }
}
