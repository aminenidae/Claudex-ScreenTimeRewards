import SwiftUI
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

@available(iOS 16.0, *)
struct ParentModeView: View {
    // Services (should be dependency-injected in production)
    @StateObject private var childrenManager: ChildrenManager
    @StateObject private var rulesManager: CategoryRulesManager
#if canImport(DeviceActivity) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
    @StateObject private var learningCoordinator: LearningSessionCoordinator
#endif
    private let ledger: PointsLedger

    init() {
        // For MVP, create services here
        // In production, these would be injected via environment or DI container
        let ledger = PointsLedger()
        let engine = PointsEngine()
        let exemptionManager = ExemptionManager()

        let manager = ChildrenManager(ledger: ledger, engine: engine, exemptionManager: exemptionManager)
        manager.loadDemoChildren()

        let rulesManager = CategoryRulesManager()
#if canImport(DeviceActivity) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
        let learningCoordinator = LearningSessionCoordinator(
            rulesManager: rulesManager,
            pointsEngine: engine,
            pointsLedger: ledger
        )
        _learningCoordinator = StateObject(wrappedValue: learningCoordinator)
#endif

        self.ledger = ledger
        _childrenManager = StateObject(wrappedValue: manager)
        _rulesManager = StateObject(wrappedValue: rulesManager)
    }

    var body: some View {
        TabView {
            MultiChildDashboardView(childrenManager: childrenManager)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            ExportView(
                childId: childrenManager.selectedChildId ?? ChildID("unknown"),
                ledger: ledger
            )
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

            AppCategorizationView(childrenManager: childrenManager, rulesManager: rulesManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .navigationTitle("Parent Mode")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Coming soon: App categorization, point rates, and family settings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        ParentModeView()
    }
}
