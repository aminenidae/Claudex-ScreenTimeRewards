import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
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
    public static let redemptionWindow = "RedemptionWindow"
    public static let pairingCode = "PairingCode"
}

public enum CloudKitMapperError: Error {
    case missingField(String)
    case invalidReference(String)
}

#if canImport(CloudKit)
public struct CloudKitMapper {
    // MARK: - Family

    public static func familyRecord(for payload: FamilyPayload) -> CKRecord {
        let recordID = CKRecord.ID(recordName: payload.id.rawValue)
        let record = CKRecord(recordType: CloudKitRecordType.family, recordID: recordID)
        record["createdAt"] = payload.createdAt
        record["parentDeviceIds"] = payload.parentDeviceIds
        if let familyName = payload.familyName {
            record["familyName"] = familyName
        }
        record["modifiedAt"] = payload.modifiedAt
        return record
    }

    public static func familyPayload(from record: CKRecord) throws -> FamilyPayload {
        guard let createdAt = record["createdAt"] as? Date else {
            throw CloudKitMapperError.missingField("createdAt")
        }
        guard let modifiedAt = record["modifiedAt"] as? Date else {
            throw CloudKitMapperError.missingField("modifiedAt")
        }
        let parentDeviceIds = record["parentDeviceIds"] as? [String] ?? []
        let familyName = record["familyName"] as? String
        let familyId = FamilyID(record.recordID.recordName)

        return FamilyPayload(
            id: familyId,
            createdAt: createdAt,
            parentDeviceIds: parentDeviceIds,
            familyName: familyName,
            modifiedAt: modifiedAt
        )
    }

    // MARK: - App Rule

    public static func appRuleRecord(
        for payload: AppRulePayload,
        familyID: CKRecord.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(recordName: payload.id)
        let record = CKRecord(recordType: CloudKitRecordType.appRule, recordID: recordID)
        record["familyRef"] = CKRecord.Reference(recordID: familyID, action: .none)
        record["childRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: payload.childId.rawValue), action: .none)
        record["appToken"] = payload.appToken
        record["classification"] = payload.classification.rawValue
        record["isCategory"] = payload.isCategory
        if let categoryId = payload.categoryId {
            record["categoryId"] = categoryId
        }
        record["createdAt"] = payload.createdAt
        record["modifiedAt"] = payload.modifiedAt
        if let modifiedBy = payload.modifiedBy {
            record["modifiedBy"] = modifiedBy
        }
        return record
    }

    public static func appRulePayload(from record: CKRecord) throws -> AppRulePayload {
        guard let appToken = record["appToken"] as? String else {
            throw CloudKitMapperError.missingField("appToken")
        }
        guard let classificationRaw = record["classification"] as? String,
              let classification = AppClassification(rawValue: classificationRaw) else {
            throw CloudKitMapperError.missingField("classification")
        }
        guard let isCategory = record["isCategory"] as? Bool else {
            throw CloudKitMapperError.missingField("isCategory")
        }
        guard let createdAt = record["createdAt"] as? Date else {
            throw CloudKitMapperError.missingField("createdAt")
        }
        guard let modifiedAt = record["modifiedAt"] as? Date else {
            throw CloudKitMapperError.missingField("modifiedAt")
        }

        let childRef = (record["childRef"] as? CKRecord.Reference)?.recordID.recordName ?? "unknown"
        let childId = ChildID(childRef)
        let categoryId = record["categoryId"] as? String
        let modifiedBy = record["modifiedBy"] as? String

        return AppRulePayload(
            id: record.recordID.recordName,
            childId: childId,
            appToken: appToken,
            classification: classification,
            isCategory: isCategory,
            categoryId: categoryId,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            modifiedBy: modifiedBy
        )
    }

    // MARK: - Redemption Window

    public static func redemptionWindowRecord(
        for window: EarnedTimeWindow,
        familyID: CKRecord.ID,
        pointsSpent: Int,
        deviceId: String
    ) -> CKRecord {
        let recordID = CKRecord.ID(recordName: window.id.uuidString)
        let record = CKRecord(recordType: CloudKitRecordType.redemptionWindow, recordID: recordID)
        record["familyRef"] = CKRecord.Reference(recordID: familyID, action: .none)
        record["childRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: window.childId.rawValue), action: .none)
        record["startTime"] = window.startTime
        record["durationSeconds"] = window.durationSeconds
        record["expiresAt"] = window.endTime
        record["pointsSpent"] = pointsSpent
        record["isActive"] = !window.isExpired
        record["deviceId"] = deviceId
        record["createdAt"] = Date()
        return record
    }

    public static func redemptionWindow(from record: CKRecord) throws -> (window: EarnedTimeWindow, pointsSpent: Int, deviceId: String) {
        guard let startTime = record["startTime"] as? Date else {
            throw CloudKitMapperError.missingField("startTime")
        }
        guard let durationSeconds = record["durationSeconds"] as? Double else {
            throw CloudKitMapperError.missingField("durationSeconds")
        }
        guard let pointsSpent = record["pointsSpent"] as? Int else {
            throw CloudKitMapperError.missingField("pointsSpent")
        }
        let deviceId = record["deviceId"] as? String ?? "unknown"

        let childRef = (record["childRef"] as? CKRecord.Reference)?.recordID.recordName ?? "unknown"
        let childId = ChildID(childRef)

        let window = EarnedTimeWindow(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            childId: childId,
            durationSeconds: durationSeconds,
            startTime: startTime
        )

        return (window, pointsSpent, deviceId)
    }

    // MARK: - Pairing Code
    public static func pairingCodeRecord(
        for code: PairingCode,
        familyID: CKRecord.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(recordName: code.code)
        let record = CKRecord(recordType: CloudKitRecordType.pairingCode, recordID: recordID)
        applyPairingCode(code, to: record, familyID: familyID)
        return record
    }

    public static func applyPairingCode(
        _ code: PairingCode,
        to record: CKRecord,
        familyID: CKRecord.ID
    ) {
        record["familyRef"] = CKRecord.Reference(recordID: familyID, action: .none)
        record["childRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: code.childId.rawValue), action: .none)
        record["createdAt"] = code.createdAt
        record["expiresAt"] = code.expiresAt
        record["ttlMinutes"] = code.ttlMinutes
        record["isUsed"] = code.isUsed
        if let usedAt = code.usedAt {
            record["usedAt"] = usedAt
        } else {
            record["usedAt"] = nil
        }
        if let usedByDeviceId = code.usedByDeviceId {
            record["usedByDeviceId"] = usedByDeviceId
        } else {
            record["usedByDeviceId"] = nil
        }
    }

    public static func pairingCode(from record: CKRecord) throws -> PairingCode {
        guard let createdAt = record["createdAt"] as? Date else {
            throw CloudKitMapperError.missingField("createdAt")
        }
        guard let _ = record["expiresAt"] as? Date else {
            throw CloudKitMapperError.missingField("expiresAt")
        }
        guard let ttlMinutes = record["ttlMinutes"] as? Int else {
            throw CloudKitMapperError.missingField("ttlMinutes")
        }
        guard let isUsed = record["isUsed"] as? Bool else {
            throw CloudKitMapperError.missingField("isUsed")
        }
        
        // Get child ID from the record reference
        let childRef = (record["childRef"] as? CKRecord.Reference)?.recordID.recordName ?? "unknown"
        let childId = ChildID(childRef)
        let usedAt = record["usedAt"] as? Date
        let usedByDeviceId = record["usedByDeviceId"] as? String

        return PairingCode(
            code: record.recordID.recordName,
            childId: childId,
            createdAt: createdAt,
            ttlMinutes: ttlMinutes,
            isUsed: isUsed,
            usedAt: usedAt,
            usedByDeviceId: usedByDeviceId
        )
    }

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
        let childRecordName = (record["childRef"] as? CKRecord.Reference)?.recordID.recordName
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
}
#endif
