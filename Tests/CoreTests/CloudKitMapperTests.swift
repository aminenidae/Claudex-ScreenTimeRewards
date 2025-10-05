#if canImport(CloudKit)
import XCTest
import CloudKit
@testable import Core
@testable import SyncKit

final class CloudKitMapperTests: XCTestCase {
    func testChildPayloadRoundTrip() throws {
        let familyID = CKRecord.ID(recordName: "family-123")
        let payload = ChildContextPayload(id: ChildID("child-abc"), childOpaqueId: "opaque-token", displayName: "Alice", pairedDeviceIds: ["device-1"])
        let record = CloudKitMapper.childRecord(for: payload, familyID: familyID)

        let decoded = try CloudKitMapper.childPayload(from: record)
        XCTAssertEqual(decoded.id, payload.id)
        XCTAssertEqual(decoded.childOpaqueId, payload.childOpaqueId)
        XCTAssertEqual(decoded.displayName, payload.displayName)
        XCTAssertEqual(decoded.pairedDeviceIds, payload.pairedDeviceIds)
    }

    func testLedgerEntryRoundTrip() throws {
        let entry = PointsLedgerEntry(
            id: UUID(uuidString: "F0F0F0F0-F0F0-F0F0-F0F0-F0F0F0F0F0F0")!,
            childId: ChildID("child-xyz"),
            type: .redemption,
            amount: -120,
            timestamp: Date()
        )
        let familyID = CKRecord.ID(recordName: "family-xyz")
        let record = CloudKitMapper.ledgerRecord(for: entry, familyID: familyID)

        let decoded = try CloudKitMapper.ledgerEntry(from: record)
        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.childId, entry.childId)
        XCTAssertEqual(decoded.type, entry.type)
        XCTAssertEqual(decoded.amount, entry.amount)
    }

    func testAuditEntryRoundTrip() throws {
        let audit = AuditEntry(
            childId: ChildID("child-xyz"),
            action: "redemption",
            details: ["points": "-120", "reason": "Reward"]
        )
        let familyID = CKRecord.ID(recordName: "family-xyz")
        let record = CloudKitMapper.auditRecord(for: audit, familyID: familyID)

        let decoded = try CloudKitMapper.auditEntry(from: record)
        XCTAssertEqual(decoded.childId, audit.childId)
        XCTAssertEqual(decoded.action, audit.action)
        XCTAssertEqual(decoded.details?["points"], "-120")
        XCTAssertEqual(decoded.details?["reason"], "Reward")
    }
}
#endif
