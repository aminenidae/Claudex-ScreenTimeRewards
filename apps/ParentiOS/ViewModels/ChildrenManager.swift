import Foundation
import Combine
#if canImport(Core)
import Core
#endif
#if canImport(FamilyControls)
import FamilyControls
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

// CloudKitDebugger is compiled directly into the ParentiOS target from Sources/Core/CloudKitDebugger.swift

/// Represents a managed child profile
struct ChildProfile: Identifiable, Hashable, Codable {
    let id: ChildID
    var name: String
    var storeName: String

    init(id: ChildID, name: String, storeName: String) {
        self.id = id
        self.name = name
        self.storeName = storeName
    }
}

/// Manages the list of children and provides view models for each
@MainActor
class ChildrenManager: ObservableObject {
    @Published var children: [ChildProfile] = [] {
        didSet {
            persistChildren()
        }
    }
    @Published var selectedChildId: ChildID? {
        didSet {
            let appGroupId = "group.com.claudex.screentimerewards"
            if let userDefaults = UserDefaults(suiteName: appGroupId) {
                if let childId = selectedChildId {
                    userDefaults.set(childId.rawValue, forKey: "com.claudex.pairedChildId")
                } else {
                    userDefaults.removeObject(forKey: "com.claudex.pairedChildId")
                }
            }
        }
    }

    // Shared services
    let ledger: PointsLedger
    let engine: PointsEngine
    let exemptionManager: ExemptionManager
    let redemptionService: RedemptionServiceProtocol

    private let storageURL: URL?

    // Cache of view models (one per child)
    private var viewModels: [ChildID: DashboardViewModel] = [:]
    private var _syncService: SyncService?

    // Public accessor for sync service
    var syncService: SyncService? {
        return _syncService
    }

    init(ledger: PointsLedger, engine: PointsEngine, exemptionManager: ExemptionManager, redemptionService: RedemptionServiceProtocol) {
        self.ledger = ledger
        self.engine = engine
        self.exemptionManager = exemptionManager
        self.redemptionService = redemptionService

        if FeatureFlags.enablesFamilyAuthorization {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.storageURL = documents.appendingPathComponent("children.json")
            loadPersistedChildren()
            if selectedChildId == nil {
                selectedChildId = children.first?.id
            }
            // Remove the demo children loading when feature flag is on
        } else {
            self.storageURL = nil
            loadDemoChildren()
        }
    }

    /// Get or create a view model for a specific child
    func getViewModel(for childId: ChildID) -> DashboardViewModel {
        if let existing = viewModels[childId] {
            return existing
        }

        let vm = DashboardViewModel(
            childId: childId,
            ledger: ledger,
            engine: engine,
            exemptionManager: exemptionManager,
            redemptionService: redemptionService
        )
        viewModels[childId] = vm
        return vm
    }

    func setSyncService(_ syncService: SyncService) {
        self._syncService = syncService
    }

    /// Select child by index
    func selectChild(at index: Int) {
        guard index >= 0 && index < children.count else { return }
        selectedChildId = children[index].id
    }

    /// Add demo data (used by previews/tests)
    func loadDemoChildren() {
        children = [
            ChildProfile(id: ChildID("child-1"), name: "Alice", storeName: "child-child-1"),
            ChildProfile(id: ChildID("child-2"), name: "Bob", storeName: "child-child-2"),
            ChildProfile(id: ChildID("child-3"), name: "Charlie", storeName: "child-child-3")
        ]

        for (index, child) in children.enumerated() {
            let basePoints = 200 + (index * 50)
            _ = ledger.recordAccrual(childId: child.id, points: basePoints, timestamp: Date())
            _ = ledger.recordRedemption(childId: child.id, points: 80, timestamp: Date().addingTimeInterval(-3600))
            _ = ledger.recordAccrual(childId: child.id, points: 100, timestamp: Date().addingTimeInterval(TimeInterval(-86400 * (index + 1))))
        }

        selectedChildId = children.first?.id
    }

    // MARK: - Child Management

    func addChild(named name: String) async -> Result<ChildProfile, Error> {
        guard FeatureFlags.enablesFamilyAuthorization else {
            return .failure(FamilyControlsError.unavailable)
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmed.isEmpty ? "Child" : trimmed

        do {
            // Authorization is now requested at app launch, so we can skip the check here
            // This prevents the 14s hang when adding a child
            let childId = ChildID(UUID().uuidString)
            let storeName = "child-\(childId.rawValue)"
            let profile = ChildProfile(id: childId, name: displayName, storeName: storeName)

            // Save to CloudKit
            if let syncService = _syncService {
                print("ChildrenManager: About to save child \(displayName) to CloudKit via SyncService")
                // Log start time for performance monitoring
                let startTime = CFAbsoluteTimeGetCurrent()
                let payload = ChildContextPayload(id: childId, childOpaqueId: storeName, displayName: displayName)
                try await syncService.saveChild(payload, familyId: FamilyID("default-family"))
                let endTime = CFAbsoluteTimeGetCurrent()
                print("ChildrenManager: Successfully saved child \(displayName) to CloudKit in \(endTime - startTime)s")
            } else {
                print("ChildrenManager: WARNING - SyncService is nil, child not saved to CloudKit!")
            }

            children.append(profile)
            selectedChildId = childId

            return .success(profile)
        } catch {
            return .failure(error)
        }
    }

    func removeChild(_ child: ChildProfile) async {
        children.removeAll { $0.id == child.id }
        viewModels[child.id] = nil
        if selectedChildId == child.id {
            selectedChildId = children.first?.id
        }

        if let syncService = _syncService {
            do {
                try await syncService.deleteChild(child.id, familyId: FamilyID("default-family"))
            } catch {
                print("Failed to delete child from cloud: \(error)")
            }
        }
    }

    func refreshChildrenFromCloud(familyId: FamilyID) async {
        guard let syncService = _syncService else {
            print("SyncService not available in ChildrenManager")
            return
        }

        let maxRetries = 3
        var attempt = 0

        // Log start time for performance monitoring
        let startTime = CFAbsoluteTimeGetCurrent()
        print("ChildrenManager: Starting refreshChildrenFromCloud")

        while attempt < maxRetries {
            attempt += 1
            do {
                let payloads = try await syncService.fetchChildren(familyId: familyId)
                let profiles = payloads.map { ChildProfile(id: $0.id, name: $0.displayName ?? "Child", storeName: $0.childOpaqueId) }
                
                await MainActor.run {
                    self.children = profiles
                    persistChildren()
                }

                let endTime = CFAbsoluteTimeGetCurrent()
                print("ChildrenManager: Completed refreshChildrenFromCloud in \(endTime - startTime)s")
                return // Success
            } catch let error as SyncError {
                if case .serverError(let message) = error, message.contains("Did not find record type") {
                    print("Failed to refresh children, record type not found. Retry attempt \(attempt)/\(maxRetries)...")
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                } else {
                    print("Failed to refresh children from cloud: \(error)")
                    let endTime = CFAbsoluteTimeGetCurrent()
                    print("ChildrenManager: Failed refreshChildrenFromCloud after \(endTime - startTime)s")
                    return
                }
            } catch {
                print("Failed to refresh children from cloud: \(error)")
                let endTime = CFAbsoluteTimeGetCurrent()
                print("ChildrenManager: Failed refreshChildrenFromCloud after \(endTime - startTime)s")
                return
            }
        }
    }


    var selectedChildIndex: Int {
        guard let selectedId = selectedChildId,
              let index = children.firstIndex(where: { $0.id == selectedId }) else {
            return 0
        }
        return index
    }

    // MARK: - Persistence

    private func loadPersistedChildren() {
        guard let storageURL, FileManager.default.fileExists(atPath: storageURL.path) else {
            children = []
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([ChildProfile].self, from: data)
            children = decoded
        } catch {
            print("ChildrenManager: failed to load children: \(error)")
            children = []
        }
    }

    private func persistChildren() {
        guard let storageURL else { return }

        do {
            let data = try JSONEncoder().encode(children)
            try data.write(to: storageURL)
        } catch {
            print("ChildrenManager: failed to save children: \(error)")
        }
    }
    
    #if canImport(FamilyControls)
    /// Get the managed environment for a specific child
    /// This is a placeholder implementation - FamilyActivityPicker works with the current authorization context
    func getManagedEnvironment(for childId: ChildID) -> Any? {
        // FamilyActivityPicker works with the currently authorized child context
        // We don't need to explicitly pass a managed environment for basic functionality
        return nil
    }
    #endif
}
