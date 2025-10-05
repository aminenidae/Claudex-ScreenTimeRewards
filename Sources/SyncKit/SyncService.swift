import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
#if canImport(Core)
import Core
#endif

// CloudKitMapper is in the same module, so it's automatically available

public enum SyncError: Error, Equatable {
    case notAuthenticated
    case networkUnavailable
    case quotaExceeded
    case serverError(String)
    case conflictResolutionFailed
    case invalidRecord(String)
}

public protocol SyncServiceProtocol {
    func ping() -> Bool
    #if canImport(CloudKit)
    func fetchFamily(id: FamilyID) async throws -> FamilyPayload
    func saveFamily(_ family: FamilyPayload) async throws
    func fetchChildren(familyId: FamilyID) async throws -> [ChildContextPayload]
    func saveChild(_ child: ChildContextPayload, familyId: FamilyID) async throws
    func fetchAppRules(familyId: FamilyID, childId: ChildID?) async throws -> [AppRulePayload]
    func saveAppRule(_ rule: AppRulePayload, familyId: FamilyID) async throws
    func syncChanges(since token: CKServerChangeToken?) async throws -> (changes: [CKRecord], newToken: CKServerChangeToken?)
    #endif
}

@MainActor
public final class SyncService: SyncServiceProtocol {
    #if canImport(CloudKit)
    private let container: CKContainer
    private let database: CKDatabase
    private let zoneName = "FamilyZone"
    private var customZone: CKRecordZone?

    public init(container: CKContainer = CKContainer.default()) {
        self.container = container
        self.database = container.privateCloudDatabase
    }

    // MARK: - Ping

    public func ping() -> Bool { true }

    // MARK: - Zone Management

    private func ensureCustomZone() async throws -> CKRecordZone {
        if let zone = customZone {
            return zone
        }

        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)

        do {
            let (savedResults, _) = try await database.modifyRecordZones(saving: [zone], deleting: [])
            for (_, result) in savedResults {
                switch result {
                case .success(let savedZone):
                    self.customZone = savedZone
                    return savedZone
                case .failure(let error):
                    throw SyncError.serverError("Zone save failed: \(error.localizedDescription)")
                }
            }
            throw SyncError.serverError("Failed to create custom zone")
        } catch {
            throw SyncError.serverError("Zone creation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Family Operations

    public func fetchFamily(id: FamilyID) async throws -> FamilyPayload {
        let _ = try await ensureCustomZone()
        let recordID = CKRecord.ID(recordName: id.rawValue, zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName))

        do {
            let record = try await database.record(for: recordID)
            return try CloudKitMapper.familyPayload(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            throw SyncError.invalidRecord("Family not found")
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    public func saveFamily(_ family: FamilyPayload) async throws {
        let _ = try await ensureCustomZone()
        let record = CloudKitMapper.familyRecord(for: family)

        do {
            _ = try await database.save(record)
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Child Operations

    public func fetchChildren(familyId: FamilyID) async throws -> [ChildContextPayload] {
        let _ = try await ensureCustomZone()
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue, zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName))
        let familyRef = CKRecord.Reference(recordID: familyRecordID, action: .none)

        let predicate = NSPredicate(format: "familyRef == %@", familyRef)
        let query = CKQuery(recordType: CloudKitRecordType.childContext, predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query)
            var children: [ChildContextPayload] = []

            for (_, result) in results {
                switch result {
                case .success(let record):
                    let child = try CloudKitMapper.childPayload(from: record)
                    children.append(child)
                case .failure(let error):
                    print("Failed to fetch child: \(error)")
                }
            }

            return children
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    public func saveChild(_ child: ChildContextPayload, familyId: FamilyID) async throws {
        let _ = try await ensureCustomZone()
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue, zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName))
        let record = CloudKitMapper.childRecord(for: child, familyID: familyRecordID)

        do {
            _ = try await database.save(record)
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    // MARK: - App Rule Operations

    public func fetchAppRules(familyId: FamilyID, childId: ChildID?) async throws -> [AppRulePayload] {
        let _ = try await ensureCustomZone()
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue, zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName))
        let familyRef = CKRecord.Reference(recordID: familyRecordID, action: .none)

        let predicate: NSPredicate
        if let childId = childId {
            let childRecordID = CKRecord.ID(recordName: childId.rawValue, zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName))
            let childRef = CKRecord.Reference(recordID: childRecordID, action: .none)
            predicate = NSPredicate(format: "familyRef == %@ AND childRef == %@", familyRef, childRef)
        } else {
            predicate = NSPredicate(format: "familyRef == %@", familyRef)
        }

        let query = CKQuery(recordType: CloudKitRecordType.appRule, predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query)
            var rules: [AppRulePayload] = []

            for (_, result) in results {
                switch result {
                case .success(let record):
                    let rule = try CloudKitMapper.appRulePayload(from: record)
                    rules.append(rule)
                case .failure(let error):
                    print("Failed to fetch app rule: \(error)")
                }
            }

            return rules
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    public func saveAppRule(_ rule: AppRulePayload, familyId: FamilyID) async throws {
        let _ = try await ensureCustomZone()
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue, zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName))
        let record = CloudKitMapper.appRuleRecord(for: rule, familyID: familyRecordID)

        do {
            _ = try await database.save(record)
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Change Tracking & Sync

    public func syncChanges(since token: CKServerChangeToken?) async throws -> (changes: [CKRecord], newToken: CKServerChangeToken?) {
        let zone = try await ensureCustomZone()

        var changedRecords: [CKRecord] = []
        var serverChangeToken: CKServerChangeToken?

        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = token

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zone.zoneID], configurationsByRecordZoneID: [zone.zoneID: configuration])

        operation.recordWasChangedBlock = { recordID, result in
            switch result {
            case .success(let record):
                changedRecords.append(record)
            case .failure(let error):
                print("Record change error: \(error)")
            }
        }

        operation.recordZoneFetchResultBlock = { zoneID, result in
            switch result {
            case .success(let (token, _, _)):
                serverChangeToken = token
            case .failure(let error):
                print("Zone fetch error: \(error)")
            }
        }

        operation.fetchRecordZoneChangesResultBlock = { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("Fetch changes failed: \(error)")
            }
        }

        database.add(operation)

        // Wait for operation to complete (simplified for async/await)
        // In production, use proper async operation handling
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second timeout

        return (changedRecords, serverChangeToken)
    }

    // MARK: - Conflict Resolution (Last-Writer-Wins)

    public func resolveConflict(local: CKRecord, server: CKRecord) -> CKRecord {
        let localModified = local["modifiedAt"] as? Date ?? Date.distantPast
        let serverModified = server["modifiedAt"] as? Date ?? Date.distantPast

        // Last-writer-wins: Choose record with most recent modifiedAt
        return serverModified > localModified ? server : local
    }

    #else
    // Non-CloudKit stub
    public init() {}
    public func ping() -> Bool { true }
    #endif
}
