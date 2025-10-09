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
// SyncKit files are compiled directly into the target, no import needed

@available(iOS 16.0, *)
struct ParentModeView: View {
    @EnvironmentObject private var authorizationCoordinator: ScreenTimeAuthorizationCoordinator
    @EnvironmentObject private var pairingService: PairingService
    @StateObject private var childrenManager: ChildrenManager
    @StateObject private var rulesManager: CategoryRulesManager
#if canImport(DeviceActivity) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
    @StateObject private var learningCoordinator: LearningSessionCoordinator
#endif
#if canImport(ManagedSettings) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
    @StateObject private var rewardCoordinator: RewardCoordinator
#endif
    @StateObject private var syncService: SyncService
    private let ledger: PointsLedger
    @State private var showingPairingSheet = false
    @State private var pairingNotification: PairingNotification?
    @State private var showPairingSuccess = false

    init() {
        let ledger: PointsLedger
        if let appGroupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.claudex.screentimerewards") {
            let ledgerFileURL = appGroupContainerURL.appendingPathComponent("points_ledger.json")
            let auditLog = AuditLog()
            ledger = PointsLedger(fileURL: ledgerFileURL, auditLog: auditLog)
        } else {
            ledger = PointsLedger()
        }
        let engine = PointsEngine()
        let exemptionManager = ExemptionManager()
        let rulesManager = CategoryRulesManager()
        let redemptionService = RedemptionService(ledger: ledger)

        var rewardCoordinatorConcrete: RewardCoordinator?

#if canImport(ManagedSettings) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
        let shieldController = ShieldController()
        let coordinator = RewardCoordinator(
            rulesManager: rulesManager,
            redemptionService: redemptionService,
            shieldController: shieldController,
            exemptionManager: exemptionManager
        )
        rewardCoordinatorConcrete = coordinator
#endif

        let manager = ChildrenManager(
            ledger: ledger,
            engine: engine,
            exemptionManager: exemptionManager,
            redemptionService: redemptionService
        )

        // SyncKit is always available - files are compiled into the target
        print("ParentModeView.init: Creating SyncService for CloudKit sync")
        let syncServiceInstance = SyncService()
        manager.setSyncService(syncServiceInstance)
        _syncService = StateObject(wrappedValue: syncServiceInstance)
        print("ParentModeView.init: SyncService created and set on ChildrenManager")

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingPairingSheet = true
                } label: {
                    Label("Link Child Device", systemImage: "qrcode")
                }
                .disabled(selectedChild == nil)
            }
        }
        .sheet(isPresented: $showingPairingSheet) {
            if let child = selectedChild {
                PairingCodeView(
                    childId: child.id,
                    childDisplayName: child.name,
                    onDismiss: { showingPairingSheet = false }
                )
                .environmentObject(pairingService)
            }
        }
        .onReceive(pairingService.$lastPairingNotification) { notification in
            if let notification = notification {
                handlePairingNotification(notification)
            }
        }
        .alert("Device Paired!", isPresented: $showPairingSuccess) {
            Button("OK") {
                showPairingSuccess = false
                pairingNotification = nil
            }
        } message: {
            if let notification = pairingNotification {
                Text("Successfully paired device \"\(notification.deviceName)\" to \(getChildName(childId: notification.childId))")
            } else {
                Text("Device successfully paired!")
            }
        }
    }
}

@available(iOS 16.0, *)
private extension ParentModeView {
    var selectedChild: ChildProfile? {
        guard let selectedId = childrenManager.selectedChildId else { return nil }
        return childrenManager.children.first(where: { $0.id == selectedId })
    }
    
    func handlePairingNotification(_ notification: PairingNotification) {
        // Update UI to show pairing success
        pairingNotification = notification
        showPairingSuccess = true
        
        // Refresh the children manager to show updated pairing status
        // This will cause the UI to update with the new pairing information
        childrenManager.objectWillChange.send()
    }
    
    func getChildName(childId: ChildID) -> String {
        return childrenManager.children.first { $0.id == childId }?.name ?? "Unknown Child"
    }
}

#Preview {
    NavigationStack {
        ParentModeView()
            .environmentObject(ScreenTimeAuthorizationCoordinator())
            .environmentObject(PairingService())
    }
}