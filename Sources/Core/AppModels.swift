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

