#if canImport(CloudKit)
import CloudKit
#endif
import Foundation
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

public enum CloudKitRecordType {
    public static let family = "Family"
    public static let childContext = "ChildContext"
    public static let appRule = "AppRule"
    public static let pointsLedgerEntry = "PointsLedgerEntry"
    public static let auditEntry = "AuditEntry"
}

public enum CloudKitMapperError: Error {
    case missingField(String)
    case invalidReference(String)
}

public struct CloudKitMapper {
#if canImport(CloudKit)
    // MARK: - Child Context

    public static func childRecord(
        for payload: ChildContextPayload,
        familyID: CKRecord.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(recordName: payload.id.rawValue)
        let record = CKRecord(recordType: CloudKitRecordType.childContext, recordID: recordID)
        record["familyRef"] = CKRecord.Reference(recordID: familyID, action: .none)
        record["childOpaqueId"] = payload.childOpaqueId
        if let displayName = payload.displayName {
            record["displayName"] = displayName
        }
        if !payload.pairedDeviceIds.isEmpty {
            record["pairedDeviceIds"] = payload.pairedDeviceIds
        }
        return record
    }

    public static func childPayload(from record: CKRecord) throws -> ChildContextPayload {
        guard let opaqueId = record["childOpaqueId"] as? String else {
            throw CloudKitMapperError.missingField("childOpaqueId")
        }
        let displayName = record["displayName"] as? String
        let pairedDeviceIds = record["pairedDeviceIds"] as? [String] ?? []
        let childId = ChildID(record.recordID.recordName)
        return ChildContextPayload(
            id: childId,
            childOpaqueId: opaqueId,
            displayName: displayName,
            pairedDeviceIds: pairedDeviceIds
        )
    }

    // MARK: - Points Ledger

    public static func ledgerRecord(
        for entry: PointsLedgerEntry,
        familyID: CKRecord.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(recordName: entry.id.uuidString)
        let record = CKRecord(recordType: CloudKitRecordType.pointsLedgerEntry, recordID: recordID)
        record["familyRef"] = CKRecord.Reference(recordID: familyID, action: .none)
        record["childRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: entry.childId.rawValue), action: .none)
        record["type"] = entry.type.rawValue
        record["amount"] = entry.amount
        record["timestamp"] = entry.timestamp
        return record
    }

    public static func ledgerEntry(from record: CKRecord) throws -> PointsLedgerEntry {
        guard let typeRaw = record["type"] as? String,
              let type = PointsLedgerEntry.EntryType(rawValue: typeRaw) else {
            throw CloudKitMapperError.missingField("type")
        }
        guard let amount = record["amount"] as? Int else {
            throw CloudKitMapperError.missingField("amount")
        }
        guard let timestamp = record["timestamp"] as? Date else {
            throw CloudKitMapperError.missingField("timestamp")
        }
        let childRecordName = (record["childRef"] as? CKRecord.Reference)?.recordID.recordName ?? record.recordID.zoneID.ownerName
        let childId = ChildID(childRecordName ?? "unknown")
        return PointsLedgerEntry(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            childId: childId,
            type: type,
            amount: amount,
            timestamp: timestamp
        )
    }

    // MARK: - Audit Entry

    public static func auditRecord(
        for entry: AuditEntry,
        familyID: CKRecord.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(recordName: entry.id.uuidString)
        let record = CKRecord(recordType: CloudKitRecordType.auditEntry, recordID: recordID)
        record["familyRef"] = CKRecord.Reference(recordID: familyID, action: .none)
        record["childRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: entry.childId.rawValue), action: .none)
        record["action"] = entry.action
        record["timestamp"] = entry.timestamp
        if let details = entry.details,
           let data = try? JSONSerialization.data(withJSONObject: details, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            record["metadata"] = jsonString
        }
        return record
    }

    public static func auditEntry(from record: CKRecord) throws -> AuditEntry {
        guard let action = record["action"] as? String else {
            throw CloudKitMapperError.missingField("action")
        }
        guard let timestamp = record["timestamp"] as? Date else {
            throw CloudKitMapperError.missingField("timestamp")
        }
        let childRef = (record["childRef"] as? CKRecord.Reference)?.recordID.recordName ?? "unknown"
        var metadataDict: [String: String]? = nil
        if let metadataString = record["metadata"] as? String,
           let data = metadataString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
            metadataDict = json
        }
        return AuditEntry(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            childId: ChildID(childRef),
            action: action,
            timestamp: timestamp,
            details: metadataDict
        )
    }
#endif
}
