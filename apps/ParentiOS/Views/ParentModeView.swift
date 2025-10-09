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
#if canImport(ParentiOS)
import ParentiOS
#endif
// SyncKit files are compiled directly into the target, no import needed

@available(iOS 16.0, *)
struct ParentModeView: View {
    @EnvironmentObject private var authorizationCoordinator: ScreenTimeAuthorizationCoordinator
    @EnvironmentObject private var pairingService: PairingService
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var rulesManager: CategoryRulesManager
    @EnvironmentObject private var ledger: PointsLedger
    @EnvironmentObject private var learningCoordinator: LearningSessionCoordinator
    @EnvironmentObject private var rewardCoordinator: RewardCoordinator

    @State private var showingPairingSheet = false
    @State private var pairingNotification: PairingNotification?
    @State private var showPairingSuccess = false

    var body: some View {
        VStack {
            if authorizationCoordinator.state != .approved {
                AuthorizationStatusBanner(state: authorizationCoordinator.state) {
                    Task { await authorizationCoordinator.requestAuthorization() }
                }
                .padding(.horizontal)
            }

            TabView {
                MultiChildDashboardView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

                ExportView(
                    childId: childrenManager.selectedChildId ?? ChildID("unknown"),
                    ledger: ledger
                )
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }

                AppCategorizationView()
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
        .task {
            // Sync with CloudKit whenever Parent Mode becomes active to ensure latest pairing state
            #if canImport(CloudKit)
            do {
                print("ParentModeView: Syncing with CloudKit on appear")
                try await pairingService.syncWithCloudKit(familyId: FamilyID("default-family"))
                print("ParentModeView: Completed CloudKit sync")
            } catch {
                print("ParentModeView: Failed to sync with CloudKit: \(error)")
            }
            #endif
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