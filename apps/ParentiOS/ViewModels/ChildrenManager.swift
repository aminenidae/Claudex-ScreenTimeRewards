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
        didSet { persistChildren() } 
    }
    @Published var selectedChildId: ChildID? {
        didSet {
            let appGroupId = "group.com.claudex.ScreentimeRewards"
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
    private let ledger: PointsLedger
    private let engine: PointsEngine
    private let exemptionManager: ExemptionManager
    private let redemptionService: RedemptionServiceProtocol

    private let storageURL: URL?

    // Cache of view models (one per child)
    private var viewModels: [ChildID: DashboardViewModel] = [:]

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
            if children.isEmpty {
                loadDemoChildren()
            }
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
            try await AuthorizationCenter.shared.requestAuthorization(for: .child)
            let childId = ChildID(UUID().uuidString)
            let storeName = "child-\(childId.rawValue)"
            let profile = ChildProfile(id: childId, name: displayName, storeName: storeName)
            children.append(profile)
            selectedChildId = childId
            return .success(profile)
        } catch {
            return .failure(error)
        }
    }

    func removeChild(_ child: ChildProfile) {
        children.removeAll { $0.id == child.id }
        viewModels[child.id] = nil
        if selectedChildId == child.id {
            selectedChildId = children.first?.id
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
}
