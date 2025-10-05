import Foundation

public struct AuditEntry: Codable, Identifiable {
    public let id: UUID
    public let childId: ChildID
    public let action: String
    public let timestamp: Date
    public let details: [String: String]?

    public init(
        id: UUID = UUID(),
        childId: ChildID,
        action: String,
        timestamp: Date = Date(),
        details: [String: String]? = nil
    ) {
        self.id = id
        self.childId = childId
        self.action = action
        self.timestamp = timestamp
        self.details = details
    }
}

public protocol AuditLogProtocol: AnyObject {
    func record(entry: AuditEntry)
    func entries(for childId: ChildID) -> [AuditEntry]
    func allEntries() -> [AuditEntry]
    func clear()
}

public final class AuditLog: AuditLogProtocol {
    private var storage: [AuditEntry] = []
    private let queue = DispatchQueue(label: "com.claudex.auditlog", attributes: .concurrent)

    public init() {}

    public func record(entry: AuditEntry) {
        queue.async(flags: .barrier) {
            self.storage.append(entry)
        }
    }

    public func entries(for childId: ChildID) -> [AuditEntry] {
        queue.sync {
            storage
                .filter { $0.childId == childId }
                .sorted { $0.timestamp > $1.timestamp }
        }
    }

    public func allEntries() -> [AuditEntry] {
        queue.sync {
            storage.sorted { $0.timestamp > $1.timestamp }
        }
    }

    public func clear() {
        queue.async(flags: .barrier) {
            self.storage.removeAll()
        }
    }
}
