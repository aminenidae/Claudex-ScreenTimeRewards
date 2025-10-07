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
    func fetchAppRules(familyId: FamilyID, childId: ChildID?) async throws -> [AppRulePayload]
    func saveAppRule(_ rule: AppRulePayload, familyId: FamilyID) async throws
    func fetchPairingCodes(familyId: FamilyID) async throws -> [PairingCode]
    func savePairingCode(_ code: PairingCode, familyId: FamilyID) async throws
    func deletePairingCode(_ code: String, familyId: FamilyID) async throws
    func syncChanges(since token: CKServerChangeToken?) async throws -> (changes: [CKRecord], newToken: CKServerChangeToken?)
    #endif
}

@MainActor
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
            let record = try await publicDatabase.record(for: recordID)
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
            _ = try await publicDatabase.save(record)
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Child Operations

    public func fetchChildren(familyId: FamilyID) async throws -> [ChildContextPayload] {
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue)
        let familyRef = CKRecord.Reference(recordID: familyRecordID, action: .none)

        let predicate = NSPredicate(format: "familyRef == %@", familyRef)
        let query = CKQuery(recordType: CloudKitRecordType.childContext, predicate: predicate)

        do {
            let (results, _) = try await publicDatabase.records(matching: query)
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
        let familyRecordID = CKRecord.ID(recordName: familyId.rawValue)
        let record = CloudKitMapper.childRecord(for: child, familyID: familyRecordID)

        do {
            _ = try await publicDatabase.save(record)
        } catch {
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
            let (results, _) = try await publicDatabase.records(matching: query)
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
            _ = try await publicDatabase.save(record)
        } catch {
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
            let (results, _) = try await publicDatabase.records(matching: query)
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
        let record: CKRecord

        print("Saving pairing code \(code.code) to CloudKit public database for family: \(familyId)")

        do {
            record = try await publicDatabase.record(for: recordID)
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
            _ = try await publicDatabase.modifyRecords(saving: [record], deleting: [])
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
            _ = try await publicDatabase.deleteRecord(withID: recordID)
            print("Successfully deleted pairing code \(code) from CloudKit public database")
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("Pairing code \(code) not found in CloudKit; treating as already deleted")
        } catch {
            print("Error deleting pairing code \(code) from CloudKit public database: \(error)")
            throw SyncError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Change Tracking & Sync

    public func syncChanges(since token: CKServerChangeToken?) async throws -> (changes: [CKRecord], newToken: CKServerChangeToken?) {
        return ([], nil)
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
