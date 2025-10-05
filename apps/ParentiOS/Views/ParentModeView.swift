import SwiftUI
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif
#if canImport(ScreenTimeService)
import ScreenTimeService
#endif

@available(iOS 16.0, *)
struct ParentModeView: View {
    @EnvironmentObject private var authorizationCoordinator: ScreenTimeAuthorizationCoordinator
    @StateObject private var childrenManager: ChildrenManager
    @StateObject private var rulesManager: CategoryRulesManager
#if canImport(DeviceActivity) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
    @StateObject private var learningCoordinator: LearningSessionCoordinator
#endif
#if canImport(ManagedSettings) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
    @StateObject private var rewardCoordinator: RewardCoordinator
#endif
    private let ledger: PointsLedger

    init() {
        let ledger = PointsLedger()
        let engine = PointsEngine()
        let exemptionManager = ExemptionManager()
        let rulesManager = CategoryRulesManager()

        var rewardCoordinatorConcrete: RewardCoordinator?
        var rewardCoordinatorProtocol: RewardCoordinatorProtocol?

#if canImport(ManagedSettings) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
        let shieldController = ShieldController()
        let redemptionService = RedemptionService(ledger: ledger)
        let coordinator = RewardCoordinator(
            rulesManager: rulesManager,
            redemptionService: redemptionService,
            shieldController: shieldController,
            exemptionManager: exemptionManager
        )
        rewardCoordinatorConcrete = coordinator
        rewardCoordinatorProtocol = coordinator
#endif

        let manager = ChildrenManager(
            ledger: ledger,
            engine: engine,
            exemptionManager: exemptionManager,
            rewardCoordinator: rewardCoordinatorProtocol
        )

#if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1", manager.children.isEmpty {
            manager.loadDemoChildren()
        }
#endif

#if canImport(DeviceActivity) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
        let learningCoordinator = LearningSessionCoordinator(
            rulesManager: rulesManager,
            pointsEngine: engine,
            pointsLedger: ledger
        )
        _learningCoordinator = StateObject(wrappedValue: learningCoordinator)
#endif
#if canImport(ManagedSettings) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
        if let rewardCoordinatorConcrete {
            _rewardCoordinator = StateObject(wrappedValue: rewardCoordinatorConcrete)
        }
#endif

        self.ledger = ledger
        _childrenManager = StateObject(wrappedValue: manager)
        _rulesManager = StateObject(wrappedValue: rulesManager)
    }

    var body: some View {
        VStack {
            if authorizationCoordinator.state != .approved {
                AuthorizationStatusBanner(state: authorizationCoordinator.state) {
                    Task { await authorizationCoordinator.requestAuthorization() }
                }
                .padding(.horizontal)
            }

            TabView {
                MultiChildDashboardView(childrenManager: childrenManager)
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

                ExportView(
                    childId: childrenManager.selectedChildId ?? ChildID("unknown"),
                    ledger: ledger
                )
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }

                AppCategorizationView(childrenManager: childrenManager, rulesManager: rulesManager)
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        }
        .navigationTitle("Parent Mode")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ParentModeView()
            .environmentObject(ScreenTimeAuthorizationCoordinator())
    }
}
