import Foundation
#if canImport(CloudKit)
import CloudKit
private let defaultCloudContainerIdentifier = "iCloud.com.claudex.screentimerewards"
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
    func deleteChild(_ childId: ChildID, familyId: FamilyID) async throws
    func fetchAppRules(familyId: FamilyID, childId: ChildID?) async throws -> [AppRulePayload]
    func saveAppRule(_ rule: AppRulePayload, familyId: FamilyID) async throws
    func fetchAppInventory(familyId: FamilyID, childId: ChildID) async throws -> ChildAppInventoryPayload?
    func saveAppInventory(_ inventory: ChildAppInventoryPayload, familyId: FamilyID) async throws
    func fetchPairingCodes(familyId: FamilyID) async throws -> [PairingCode]
    func savePairingCode(_ code: PairingCode, familyId: FamilyID) async throws
    func deletePairingCode(_ code: String, familyId: FamilyID) async throws
    func purgeExpiredPairingCodes() async throws
    func primeCloudKit() async
    #endif
}

public final class SyncService: ObservableObject, SyncServiceProtocol, PairingSyncServiceProtocol {
    #if canImport(CloudKit)
    private let container: CKContainer
    private let publicDatabase: CKDatabase

    public init(container: CKContainer? = nil) {
        let resolvedContainer = container ?? CKContainer(identifier: defaultCloudContainerIdentifier)
        self.container = resolvedContainer
        self.publicDatabase = resolvedContainer.publicCloudDatabase
    }

    // MARK: - Ping

    public func ping() -> Bool { true }

    // MARK: - Family Operations

    public func fetchFamily(id: FamilyID) async throws -> FamilyPayload {
        let recordID = CKRecord.ID(recordName: id.rawValue)

        do {
            let record = try await self.publicDatabase.record(for: recordID)
            return try CloudKitMapper.familyPayload(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            throw SyncError.invalidRecord("Family not found")
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    public func saveFamily(_ family: FamilyPayload) async throws {
        let record = CloudKitMapper.familyRecord(for: family)

        do {
            _ = try await self.publicDatabase.save(record)
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Child Operations

    public func fetchChildren(familyId: FamilyID) async throws -> [ChildContextPayload] {
        print("SyncService: Fetching children from CloudKit for family \(familyId.rawValue)")
        // Log start time for performance monitoring
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("SyncService: Performing CloudKit fetch on background task")
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue)
        let familyRef = CKRecord.Reference(recordID: familyRecordID, action: .none)

        let predicate = NSPredicate(format: "familyRef == %@", familyRef)
        let query = CKQuery(recordType: CloudKitRecordType.childContext, predicate: predicate)

        do {
            let (results, _) = try await self.publicDatabase.records(matching: query)
            var children: [ChildContextPayload] = []

            for (_, result) in results {
                switch result {
                case .success(let record):
                    let child = try CloudKitMapper.childPayload(from: record)
                    children.append(child)
                case .failure(let error):
                    print("SyncService: Failed to fetch child record: \(error)")
                }
            }

            let endTime = CFAbsoluteTimeGetCurrent()
            print("SyncService: CloudKit fetch completed in \(endTime - startTime)s")
            print("SyncService: Successfully fetched \(children.count) children from CloudKit")
            return children
        } catch {
            let endTime = CFAbsoluteTimeGetCurrent()
            print("SyncService: CloudKit fetch failed after \(endTime - startTime)s: \(error)")
            print("SyncService: Failed to fetch children from CloudKit: \(error)")
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    public func saveChild(_ child: ChildContextPayload, familyId: FamilyID) async throws {
        print("SyncService: Saving child \(child.displayName ?? "Unknown") (ID: \(child.id.rawValue)) to CloudKit for family \(familyId.rawValue)")
        // Log start time for performance monitoring
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("SyncService: Performing CloudKit save on background task")
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue)
        let record = CloudKitMapper.childRecord(for: child, familyID: familyRecordID)

        do {
            _ = try await self.publicDatabase.save(record)
            let endTime = CFAbsoluteTimeGetCurrent()
            print("SyncService: CloudKit save completed in \(endTime - startTime)s")
            print("SyncService: Successfully saved child \(child.displayName ?? "Unknown") to CloudKit")
        } catch {
            let endTime = CFAbsoluteTimeGetCurrent()
            print("SyncService: CloudKit save failed after \(endTime - startTime)s: \(error)")
            print("SyncService: Failed to save child \(child.displayName ?? "Unknown") to CloudKit: \(error)")
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    public func deleteChild(_ childId: ChildID, familyId: FamilyID) async throws {
        print("SyncService: Deleting child \(childId.rawValue) from CloudKit for family \(familyId.rawValue)")
        // Log start time for performance monitoring
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("SyncService: Performing CloudKit delete on background task")
        let recordID = CKRecord.ID(recordName: childId.rawValue)

        do {
            _ = try await self.publicDatabase.deleteRecord(withID: recordID)
            let endTime = CFAbsoluteTimeGetCurrent()
            print("SyncService: CloudKit delete completed in \(endTime - startTime)s")
            print("SyncService: Successfully deleted child \(childId.rawValue) from CloudKit")
        } catch {
            let endTime = CFAbsoluteTimeGetCurrent()
            print("SyncService: CloudKit delete failed after \(endTime - startTime)s: \(error)")
            print("SyncService: Failed to delete child \(childId.rawValue) from CloudKit: \(error)")
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    // MARK: - App Rule Operations

    public func fetchAppRules(familyId: FamilyID, childId: ChildID?) async throws -> [AppRulePayload] {
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue)
        let familyRef = CKRecord.Reference(recordID: familyRecordID, action: .none)

        let predicate: NSPredicate
        if let childId = childId {
            let childRecordID = CKRecord.ID(recordName: childId.rawValue)
            let childRef = CKRecord.Reference(recordID: childRecordID, action: .none)
            predicate = NSPredicate(format: "familyRef == %@ AND childRef == %@", familyRef, childRef)
        } else {
            predicate = NSPredicate(format: "familyRef == %@", familyRef)
        }

        let query = CKQuery(recordType: CloudKitRecordType.appRule, predicate: predicate)

        do {
            let (results, _) = try await self.publicDatabase.records(matching: query)
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
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue)
        let record = CloudKitMapper.appRuleRecord(for: rule, familyID: familyRecordID)

        do {
            _ = try await self.publicDatabase.save(record)
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    // MARK: - App Inventory Operations

    public func fetchAppInventory(familyId: FamilyID, childId: ChildID) async throws -> ChildAppInventoryPayload? {
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue)
        let familyRef = CKRecord.Reference(recordID: familyRecordID, action: .none)
        let childRecordID = CKRecord.ID(recordName: childId.rawValue)
        let childRef = CKRecord.Reference(recordID: childRecordID, action: .none)

        let predicate = NSPredicate(format: "familyRef == %@ AND childRef == %@", familyRef, childRef)
        let query = CKQuery(recordType: CloudKitRecordType.childAppInventory, predicate: predicate)

        do {
            let (results, _) = try await self.publicDatabase.records(matching: query)

            // Return the first (and should be only) inventory for this child
            for (_, result) in results {
                switch result {
                case .success(let record):
                    return try CloudKitMapper.childAppInventoryPayload(from: record)
                case .failure(let error):
                    print("Failed to fetch app inventory: \(error)")
                }
            }

            return nil // No inventory found
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    public func saveAppInventory(_ inventory: ChildAppInventoryPayload, familyId: FamilyID) async throws {
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue)
        let recordID = CKRecord.ID(recordName: inventory.id)
        var record: CKRecord

        print("☁️ SyncService: Saving app inventory for child \(inventory.childId.rawValue) (\(inventory.appCount) apps)")

        do {
            record = try await self.publicDatabase.record(for: recordID)
            // Update existing record
            let updatedRecord = CloudKitMapper.childAppInventoryRecord(for: inventory, familyID: familyRecordID)
            for key in updatedRecord.allKeys() {
                record[key] = updatedRecord[key]
            }
            print("☁️   Updating existing app inventory record")
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // Create new record
            record = CloudKitMapper.childAppInventoryRecord(for: inventory, familyID: familyRecordID)
            print("☁️   Creating new app inventory record")
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }

        do {
            _ = try await self.publicDatabase.save(record)
            print("☁️ SyncService: Successfully saved app inventory to CloudKit")
        } catch {
            print("❌ SyncService: Failed to save app inventory: \(error)")
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Pairing Code Operations
    public func fetchPairingCodes(familyId: FamilyID) async throws -> [PairingCode] {
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue)
        let familyRef = CKRecord.Reference(recordID: familyRecordID, action: .none)

        let predicate = NSPredicate(format: "familyRef == %@", familyRef)
        let query = CKQuery(recordType: CloudKitRecordType.pairingCode, predicate: predicate)
        
        print("Fetching pairing codes from CloudKit public database for family: \(familyId)")

        do {
            let (results, _) = try await self.publicDatabase.records(matching: query)
            var codes: [PairingCode] = []
            print("Found \(results.count) results from CloudKit public database")

            for (_, result) in results {
                switch result {
                case .success(let record):
                    do {
                        let code = try CloudKitMapper.pairingCode(from: record)
                        print("Successfully parsed pairing code: \(code.code)")
                        codes.append(code)
                    } catch {
                        print("Failed to parse pairing code from record: \(error)")
                    }
                case .failure(let error):
                    print("Failed to fetch pairing code record: \(error)")
                }
            }
            
            print("Returning \(codes.count) pairing codes")
            return codes
        } catch let ckError as CKError {
            if ckError.code == .unknownItem {
                print("No pairing code records found yet in CloudKit; returning empty set")
                return []
            }
            print("Error fetching pairing codes from CloudKit public database: \(ckError)")
            throw SyncError.serverError(ckError.localizedDescription)
        } catch {
            print("Error fetching pairing codes from CloudKit public database: \(error)")
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    public func savePairingCode(_ code: PairingCode, familyId: FamilyID) async throws {
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue)
        let recordID = CKRecord.ID(recordName: code.code)
        var record: CKRecord

        print("Saving pairing code \(code.code) to CloudKit public database for family: \(familyId)")

        // Perform CloudKit operations on a background task
        do {
            record = try await self.publicDatabase.record(for: recordID)
            CloudKitMapper.applyPairingCode(code, to: record, familyID: familyRecordID)
            print("Updating existing pairing code record \(code.code) in CloudKit")
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("Existing pairing code not found; creating new record for code \(code.code)")
            record = CloudKitMapper.pairingCodeRecord(for: code, familyID: familyRecordID)
        } catch {
            print("Failed to fetch pairing code record \(code.code) before save: \(error)")
            throw SyncError.serverError(error.localizedDescription)
        }

        do {
            _ = try await self.publicDatabase.modifyRecords(saving: [record], deleting: [])
            print("Successfully saved pairing code \(code.code) to CloudKit public database")
        } catch {
            print("Error saving pairing code \(code.code) to CloudKit public database: \(error)")
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    public func deletePairingCode(_ code: String, familyId: FamilyID) async throws {
        let recordID = CKRecord.ID(recordName: code)
        print("Deleting pairing code \(code) from CloudKit public database")
        do {
            let result = try await self.publicDatabase.deleteRecord(withID: recordID)
            print("Successfully deleted pairing code \(code) from CloudKit public database. Result: Record deleted")
            
            // Add verification step to ensure the record is actually deleted
            do {
                _ = try await self.publicDatabase.record(for: recordID)
                // If we reach here, the record still exists
                print("WARNING: Record \(code) still exists after deletion attempt")
                throw SyncError.serverError("Failed to delete pairing code \(code) from CloudKit - record still exists")
            } catch let ckError as CKError where ckError.code == .unknownItem {
                // This is expected - the record should not be found
                print("Verified: Pairing code \(code) successfully deleted from CloudKit")
            } catch {
                print("Error verifying deletion of pairing code \(code): \(error)")
                throw SyncError.serverError("Failed to verify deletion of pairing code \(code) from CloudKit: \(error)")
            }
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("Pairing code \(code) not found in CloudKit; treating as already deleted")
        } catch let ckError as CKError {
            print("CloudKit error deleting pairing code \(code) from CloudKit public database: \(ckError)")
            print("CloudKit error code: \(ckError.code)")
            print("CloudKit error description: \(ckError.localizedDescription)")
            // Re-throw CloudKit errors so they can be handled by the caller
            throw SyncError.serverError(ckError.localizedDescription)
        } catch {
            // Don't throw here as this is a cleanup operation
            print("Error deleting pairing code \(code) from CloudKit public database: \(error)")
        }
    }

    public func primeCloudKit() async {
        print("Priming CloudKit container...")
        do {
            let dummyId = ChildID("dummy-child-for-priming")
            let dummyPayload = ChildContextPayload(id: dummyId, childOpaqueId: "dummy-opaque-id", displayName: "Dummy")
            try await self.saveChild(dummyPayload, familyId: FamilyID("default-family"))
            try await self.deleteChild(dummyId, familyId: FamilyID("default-family"))
            print("CloudKit container primed successfully.")
        } catch {
            print("Failed to prime CloudKit container: \(error)")
        }
    }

    // MARK: - Change Tracking & Sync

    public func syncChanges(since token: CKServerChangeToken?) async throws -> (changes: [CKRecord], newToken: CKServerChangeToken?) {
        return ([], nil)
    }

    public func purgeExpiredPairingCodes() async throws {
        // Query for expired pairing codes directly using predicate
        let now = Date()
        let predicate = NSPredicate(format: "expiresAt < %@", now as NSDate)
        let query = CKQuery(recordType: CloudKitRecordType.pairingCode, predicate: predicate)
        
        do {
            let (results, _) = try await self.publicDatabase.records(matching: query)
            var expiredRecordIDs: [CKRecord.ID] = []
            
            for (recordID, result) in results {
                switch result {
                case .success:
                    expiredRecordIDs.append(recordID)
                case .failure(let error):
                    print("Failed to fetch pairing code record for expiration check: \(error)")
                }
            }
            
            // Delete expired codes
            if !expiredRecordIDs.isEmpty {
                print("Purging \(expiredRecordIDs.count) expired pairing codes from CloudKit")
                _ = try await self.publicDatabase.modifyRecords(saving: [], deleting: expiredRecordIDs)
            }
        } catch {
            print("Error during pairing code purge: \(error)")
            // Don't throw here as this is a cleanup operation that shouldn't break sync
        }
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
    public func fetchPairingCodes(familyId: FamilyID) async throws -> [PairingCode] { return [] }
    public func savePairingCode(_ code: PairingCode, familyId: FamilyID) async throws { }
    public func deletePairingCode(_ code: String, familyId: FamilyID) async throws { }
    #endif
}
