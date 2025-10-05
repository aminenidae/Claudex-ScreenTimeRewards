import Foundation
import Combine
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

/// Simple data structure representing a child in the system
struct ChildProfile: Identifiable, Hashable {
    let id: ChildID
    let name: String

    init(id: ChildID, name: String) {
        self.id = id
        self.name = name
    }
}

/// Manages the list of children and provides view models for each
@MainActor
class ChildrenManager: ObservableObject {
    @Published var children: [ChildProfile] = []
    @Published var selectedChildId: ChildID?

    // Shared services
    private let ledger: PointsLedger
    private let engine: PointsEngine
    private let exemptionManager: ExemptionManager
    private let rewardCoordinator: RewardCoordinatorProtocol?

    // Cache of view models (one per child)
    private var viewModels: [ChildID: DashboardViewModel] = [:]

    init(ledger: PointsLedger, engine: PointsEngine, exemptionManager: ExemptionManager, rewardCoordinator: RewardCoordinatorProtocol? = nil) {
        self.ledger = ledger
        self.engine = engine
        self.exemptionManager = exemptionManager
        self.rewardCoordinator = rewardCoordinator
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
            rewardCoordinator: rewardCoordinator
        )
        viewModels[childId] = vm
        return vm
    }

    /// Load demo children for MVP
    func loadDemoChildren() {
        // Create demo children
        children = [
            ChildProfile(id: ChildID("child-1"), name: "Alice"),
            ChildProfile(id: ChildID("child-2"), name: "Bob"),
            ChildProfile(id: ChildID("child-3"), name: "Charlie")
        ]

        // Add demo data for each child
        for (index, child) in children.enumerated() {
            let basePoints = 200 + (index * 50)
            _ = ledger.recordAccrual(childId: child.id, points: basePoints, timestamp: Date())
            _ = ledger.recordRedemption(childId: child.id, points: 80, timestamp: Date().addingTimeInterval(-3600))
            _ = ledger.recordAccrual(childId: child.id, points: 100, timestamp: Date().addingTimeInterval(TimeInterval(-86400 * (index + 1))))
        }

        // Select first child
        selectedChildId = children.first?.id
    }

    /// Get the index of the currently selected child
    var selectedChildIndex: Int {
        guard let selectedId = selectedChildId,
              let index = children.firstIndex(where: { $0.id == selectedId }) else {
            return 0
        }
        return index
    }

    /// Select child by index
    func selectChild(at index: Int) {
        guard index >= 0 && index < children.count else { return }
        selectedChildId = children[index].id
    }
}
