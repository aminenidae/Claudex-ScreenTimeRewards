import SwiftUI
#if canImport(ScreenTimeService)
import ScreenTimeService
#endif
#if canImport(ManagedSettings)
import ManagedSettings
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif
#if canImport(Core)
import Core
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FamilyControls)
import FamilyControls
#endif
#if canImport(SyncKit)
import SyncKit
#endif

// PINManager is available directly in the ParentiOS module
// import PINManager

@main
struct ClaudexScreenTimeRewardsApp: App {
    @StateObject private var authorizationCoordinator = ScreenTimeAuthorizationCoordinator()
    @StateObject private var childrenManager: ChildrenManager
    @StateObject private var pairingService: PairingService
    @StateObject private var deviceRoleManager: DeviceRoleManager
    @StateObject private var rulesManager = CategoryRulesManager()
    @StateObject private var ledger: PointsLedger
    @StateObject private var learningCoordinator: LearningSessionCoordinator
    @StateObject private var rewardCoordinator: RewardCoordinator
    @StateObject private var perAppStore: PerAppConfigurationStore
    @StateObject private var syncService = SyncService()
    @StateObject private var pinManager = PINManager()

    @State private var pendingPairingCode: String?
    @State private var isPriming = true

    init() {
        let ledger = PointsLedger()
        self._ledger = StateObject(wrappedValue: ledger)

        let engine = PointsEngine()
        let exemptionManager = ExemptionManager()
        let perAppStore = PerAppConfigurationStore()
        self._perAppStore = StateObject(wrappedValue: perAppStore)

        let redemptionService = RedemptionService(ledger: ledger) { childId, rewardAppId, points in
            Task { @MainActor in
                perAppStore.recordRewardRedemption(childId: childId, appId: rewardAppId, pointsSpent: points)
            }
        }

        let childrenManager = ChildrenManager(
            ledger: ledger,
            engine: engine,
            exemptionManager: exemptionManager,
            redemptionService: redemptionService
        )
        self._childrenManager = StateObject(wrappedValue: childrenManager)

        // Note: CategoryRulesManager will be connected to syncService in .task block
        let rulesManager = CategoryRulesManager()
        self._rulesManager = StateObject(wrappedValue: rulesManager)

        let learningCoordinator = LearningSessionCoordinator(
            rulesManager: rulesManager,
            pointsEngine: engine,
            pointsLedger: ledger,
            configurationProvider: { childId, appId in
                perAppStore.pointsConfiguration(for: childId, appId: appId)
            }
        )
        self._learningCoordinator = StateObject(wrappedValue: learningCoordinator)

        #if canImport(ScreenTimeService)
        let shieldController = ShieldController()
        let rewardCoordinator = RewardCoordinator(
            rulesManager: rulesManager,
            redemptionService: redemptionService,
            shieldController: shieldController,
            exemptionManager: exemptionManager,
            perAppStore: perAppStore
        )
        self._rewardCoordinator = StateObject(wrappedValue: rewardCoordinator)
        #else
        self._rewardCoordinator = StateObject(wrappedValue: RewardCoordinator())
        #endif

        let pairingService = PairingService()
        self._pairingService = StateObject(wrappedValue: pairingService)

        let deviceRoleManager = DeviceRoleManager(pairingService: pairingService)
        self._deviceRoleManager = StateObject(wrappedValue: deviceRoleManager)

        rulesManager.setPerAppStore(perAppStore)
    }

    var body: some Scene {
        WindowGroup {
            if #available(iOS 16.0, *) {
                Group {
                    if isPriming {
                        ProgressView("Preparing...")
                    } else if !deviceRoleManager.isRoleSet {
                        DeviceRoleSetupView()
                            .environmentObject(deviceRoleManager)
                            .environmentObject(childrenManager)
                            .task {
                                await deviceRoleManager.loadDeviceRole()
                            }
                    } else {
                        ModeSelectionView(pendingPairingCode: $pendingPairingCode)
                            .environmentObject(authorizationCoordinator)
                            .environmentObject(childrenManager)
                            .environmentObject(pairingService)
                            .environmentObject(rulesManager)
                            .environmentObject(ledger)
                            .environmentObject(learningCoordinator)
                            .environmentObject(rewardCoordinator)
                            .environmentObject(perAppStore)
                            .environmentObject(syncService)
                            .environmentObject(pinManager)
                            .environmentObject(deviceRoleManager)
                            .onOpenURL { url in
                                handleDeepLink(url)
                            }
                    }
                }
                .task {
                    #if canImport(CloudKit)
                    // Log start time for performance monitoring
                    let startTime = CFAbsoluteTimeGetCurrent()
                    print("ClaudexApp: Starting primeCloudKit")
                    await syncService.primeCloudKit()
                    let endTime = CFAbsoluteTimeGetCurrent()
                    print("ClaudexApp: Completed primeCloudKit in \(endTime - startTime)s")
                    isPriming = false
                    // Connect services
                    print("Connecting services")
                    pairingService.setSyncService(syncService)
                    childrenManager.setSyncService(syncService)
                    rulesManager.setSyncService(syncService)
                    print("✅ All services connected to CloudKit sync")
                    #else
                    isPriming = false
                    #endif
                }
            } else {
                Text("iOS 16 or newer is required.")
                    .padding()
            }
        }
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "claudex" else { return }

        // Expected format claudex://pair/<code>
        if url.host?.lowercased() == "pair" {
            let code = url.lastPathComponent
            let digitsOnly = code.filter { $0.isNumber }
            if digitsOnly.count == 6 {
                pendingPairingCode = digitsOnly
            }
        }
    }
}

@available(iOS 16.0, *)
struct ModeSelectionView: View {
    @EnvironmentObject private var authorizationCoordinator: ScreenTimeAuthorizationCoordinator
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var pairingService: PairingService
    @EnvironmentObject private var rulesManager: CategoryRulesManager
    @EnvironmentObject private var learningCoordinator: LearningSessionCoordinator
    @EnvironmentObject private var rewardCoordinator: RewardCoordinator
    @EnvironmentObject private var pinManager: PINManager
    @EnvironmentObject private var deviceRoleManager: DeviceRoleManager
    @EnvironmentObject private var perAppStore: PerAppConfigurationStore
    @EnvironmentObject private var syncService: SyncService
    @Binding var pendingPairingCode: String?

    @State private var navigateToChildMode = false
    @State private var navigateToParentMode = false
    @State private var showingPINEntry = false
    @State private var showingPINSetup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                AuthorizationStatusBanner(state: authorizationCoordinator.state) {
                    Task { await authorizationCoordinator.requestAuthorization() }
                }

                VStack(spacing: 12) {
                    Text("Claudex Screen Time Rewards")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Select how this device will be used. Parent Mode is PIN-protected; Child Mode is available only on child devices.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    Button {
                        handleParentModeTap()
                    } label: {
                        ModeButton(title: "Parent Mode", subtitle: "Configure rules, review points, approve redemptions")
                    }

                    if deviceRoleManager.deviceRole == .child {
                        Button {
                            navigateToChildMode = true
                        } label: {
                            ModeButton(title: "Child Mode", subtitle: "Earn points, see rewards, request more time")
                        }
                    } else {
                        ModeInfoCard(
                            title: "Child Mode Hidden",
                            message: "Child Mode is available only on devices registered as child devices."
                        )
                    }
                }

                Spacer()
            }
            .padding()
            .task { await authorizationCoordinator.refreshStatus() }
            .task { await deviceRoleManager.loadDeviceRole() }
            .onChange(of: pendingPairingCode) { newValue in
                if newValue != nil, deviceRoleManager.deviceRole == .child {
                    navigateToChildMode = true
                }
            }
            .navigationDestination(isPresented: $navigateToParentMode) {
                if deviceRoleManager.deviceRole == .parent {
                    // Parent device → Family Dashboard (Level 1)
                    ParentDeviceParentModeView()
                        .environmentObject(authorizationCoordinator)
                        .environmentObject(childrenManager)
                        .environmentObject(pairingService)
                        .environmentObject(pinManager)
                        .onDisappear {
                            pinManager.lock()
                        }
                } else {
                    // Child device → Direct to child configuration (Level 2)
                    ChildDeviceParentModeView()
                        .environmentObject(childrenManager)
                        .environmentObject(rulesManager)
                        .environmentObject(perAppStore)
                        .environmentObject(pinManager)
                        .environmentObject(learningCoordinator)
                        .environmentObject(rewardCoordinator)
                        .environmentObject(pairingService)
                        .environmentObject(syncService)
                        .onDisappear {
                            pinManager.lock()
                        }
                }
            }
            .navigationDestination(isPresented: $navigateToChildMode) {
                ChildModeView(pendingPairingCode: $pendingPairingCode)
                    .environmentObject(authorizationCoordinator)
                    .environmentObject(childrenManager)
                    .environmentObject(pairingService)
                    .environmentObject(rulesManager)
                    .environmentObject(learningCoordinator)
                    .environmentObject(rewardCoordinator)
                    .environmentObject(syncService)
                    .environmentObject(perAppStore)
            }

        }
        .sheet(isPresented: $showingPINEntry, onDismiss: openParentModeIfAuthenticated) {
            PINEntryView()
                .environmentObject(pinManager)
        }
        .sheet(isPresented: $showingPINSetup, onDismiss: openParentModeIfAuthenticated) {
            PINSetupView()
                .environmentObject(pinManager)
        }
    }

    private func handleParentModeTap() {
        if !pinManager.isPINSet {
            showingPINSetup = true
        } else if pinManager.isAuthenticated {
            navigateToParentMode = true
        } else {
            showingPINEntry = true
        }
    }

    private func openParentModeIfAuthenticated() {
        if pinManager.isAuthenticated {
            navigateToParentMode = true
        }
    }
}

@available(iOS 16.0, *)
struct ChildModeView: View {
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var pairingService: PairingService
    @EnvironmentObject private var rulesManager: CategoryRulesManager
    @EnvironmentObject private var learningCoordinator: LearningSessionCoordinator
    @EnvironmentObject private var rewardCoordinator: RewardCoordinator
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var perAppStore: PerAppConfigurationStore
    @Binding var pendingPairingCode: String?

    @State private var currentPairing: ChildDevicePairing?
    @State private var alertContext: AlertContext?
    @State private var isLoadingChildren = false
    @State private var showAppEnumeration = false
    @State private var appEnumerationComplete = false

    private let deviceId: String

    init(pendingPairingCode: Binding<String?>) {
        self._pendingPairingCode = pendingPairingCode
        let defaults = UserDefaults.standard

        if let storedDeviceId = defaults.string(forKey: "com.claudex.deviceId") {
            self.deviceId = storedDeviceId
        } else {
            #if canImport(UIKit)
            let resolvedId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            #else
            let resolvedId = ProcessInfo.processInfo.globallyUniqueString
            #endif
            self.deviceId = resolvedId
            defaults.set(resolvedId, forKey: "com.claudex.deviceId")
        }
    }

    var body: some View {
        content
            .navigationTitle("Child Mode")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: refreshPairing)
            .onReceive(pairingService.objectWillChange) { _ in
                refreshPairing()
            }
            .alert(item: $alertContext) { context in
                makeAlert(for: context)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let pairing = currentPairing {
            if showAppEnumeration && !appEnumerationComplete {
                // Show app enumeration step
               AppEnumerationView(
                   childId: pairing.childId,
                   deviceId: deviceId,
                   onComplete: {
                       appEnumerationComplete = true
                       showAppEnumeration = false
                   }
                )
                .environmentObject(syncService)
                .environmentObject(perAppStore)
            } else {
                pairedContent(for: pairing)
            }
        } else {
            ChildLinkingView(
                prefilledCode: pendingPairingCode,
                onPairingComplete: handlePairingComplete,
                onCancel: handlePairingCancelled
            )
            .environmentObject(pairingService)
            .onAppear {
                if pendingPairingCode != nil {
                    pendingPairingCode = nil
                }
            }
        }
    }

    private func pairedContent(for pairing: ChildDevicePairing) -> some View {
        let childProfile = childrenManager.children.first { $0.id == pairing.childId }

        return Group {
            if isLoadingChildren {
                ProgressView("Loading Child Profile...")
            } else if let childProfile = childProfile {
                ChildModeHomeView(
                    childProfile: childProfile,
                    ledger: childrenManager.ledger,
                    exemptionManager: childrenManager.exemptionManager,
                    redemptionService: childrenManager.redemptionService
                )
            } else {
                // Fallback to original view if child profile not found
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "person.fill.checkmark")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)

                        Text("Device Linked")
                            .font(.title)
                            .fontWeight(.semibold)

                        Text("Paired child ID: \(pairing.childId.rawValue)")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Device ID", systemImage: "iphone")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(pairing.deviceId)
                                .font(.footnote)
                                .textSelection(.enabled)

                            Label("Paired", systemImage: "clock")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(pairing.pairedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.horizontal)

                        /*
                        Button(role: .destructive) {
                            alertContext = .confirmUnlink
                        } label: {
                            Label("Unlink Device", systemImage: unlinkIconName)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        */

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 32)
                }
            }
        }
    }

    private func refreshPairing() {
        if let pairing = pairingService.getPairing(for: deviceId) {
            currentPairing = pairing
            return
        }

        if let storedPairing = loadStoredPairing(), storedPairing.deviceId == deviceId {
            currentPairing = storedPairing
        } else {
            currentPairing = nil
        }
    }

    private func loadStoredPairing() -> ChildDevicePairing? {
        guard let data = UserDefaults.standard.data(forKey: PairingService.localPairingDefaultsKey) else {
            return nil
        }

        return try? JSONDecoder().decode(ChildDevicePairing.self, from: data)
    }

    private func clearStoredPairing() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: PairingService.localPairingDefaultsKey)
        defaults.removeObject(forKey: "com.claudex.pairedChildId")
    }

    private func handlePairingComplete(_ pairing: ChildDevicePairing) {
        currentPairing = pairing
        pendingPairingCode = nil
        isLoadingChildren = true

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await childrenManager.refreshChildrenFromCloud(familyId: FamilyID("default-family"))
            isLoadingChildren = false

            // Check if app inventory already exists
            #if canImport(CloudKit)
            if let syncService = childrenManager.syncService {
                do {
                    let inventory = try await syncService.fetchAppInventory(
                        familyId: FamilyID("default-family"),
                        childId: pairing.childId
                    )

                    if inventory == nil || inventory!.appCount == 0 {
                        // No inventory or empty inventory - show enumeration step
                        showAppEnumeration = true
                        appEnumerationComplete = false
                        print("📱 No app inventory found - showing enumeration step")
                    } else {
                        // Inventory exists - skip enumeration
                        showAppEnumeration = false
                        appEnumerationComplete = true
                        print("📱 App inventory exists (\(inventory!.appCount) apps) - skipping enumeration")
                    }
                } catch {
                    // Error fetching inventory - show enumeration to be safe
                    showAppEnumeration = true
                    appEnumerationComplete = false
                    print("📱 Error checking inventory - showing enumeration step: \(error)")
                }
            }
            #else
            showAppEnumeration = false
            appEnumerationComplete = true
            #endif
        }
    }

    private func handlePairingCancelled() {
        pendingPairingCode = nil
    }

    private func unlinkDevice() {
        print("Attempting to unlink device with ID: \(deviceId)")
        do {
            let pairing = try pairingService.revokePairing(for: deviceId)
            clearStoredPairing()
            currentPairing = nil
            alertContext = nil
            print("Device successfully unlinked.")

            Task {
                let familyId = FamilyID("default-family")
                try await pairingService.removePairingFromCloud(pairing, familyId: familyId)
            }
        } catch {
            print("Error unlinking device: \(error.localizedDescription)")
            alertContext = .unlinkError(error.localizedDescription)
        }
    }
}

@available(iOS 16.0, *)
private extension ChildModeView {
    enum AlertContext: Identifiable {
        case confirmUnlink
        case unlinkError(String)

        var id: String {
            switch self {
            case .confirmUnlink: return "confirmUnlink"
            case .unlinkError: return "unlinkError"
            }
        }
    }

    var unlinkIconName: String {
        if #available(iOS 17.0, *) {
            return "link.badge.minus"
        } else {
            return "link"
        }
    }

    func makeAlert(for context: AlertContext) -> Alert {
        switch context {
        case .confirmUnlink:
            return Alert(
                title: Text("Unlink device?"),
                message: Text("This device will no longer be associated with this child."),
                primaryButton: .destructive(Text("Unlink")) {
                    unlinkDevice()
                },
                secondaryButton: .cancel {
                    alertContext = nil
                }
            )
        case .unlinkError(let message):
            return Alert(
                title: Text("Unable to unlink"),
                message: Text(message),
                dismissButton: .default(Text("OK")) {
                    alertContext = nil
                }
            )
        }
    }
}

@available(iOS 16.0, *)
struct AuthorizationStatusBanner: View {
    let state: ScreenTimeAuthorizationState
    let requestAction: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(stateTitle, systemImage: stateIcon)
                    .font(.headline)
                Spacer()
                if needsAction {
                    Button("Request Access") {
                        Task { await requestAction() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Text(stateDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var needsAction: Bool {
        switch state {
        case .notDetermined, .denied:
            return true
        default:
            return false
        }
    }

    private var stateTitle: String {
        switch state {
        case .approved:
            return "Family Controls authorized"
        case .notDetermined:
            return "Authorization required"
        case .denied:
            return "Authorization denied"
        case .approvedChild:
            return "Child device authorized"
        case .error:
            return "Authorization error"
        }
    }

    private var stateDescription: String {
        switch state {
        case .approved:
            return "Parent mode can categorize apps, award points, and manage shields."
        case .notDetermined:
            return "Parents must grant Family Controls access before linking child devices."
        case .denied:
            return "Authorization was declined. Open Settings → Screen Time → Apps to grant access."
        case .approvedChild:
            return "This device is authorized as a child device. Child mode is active."
        case .error(let error):
            return "Error requesting access: \(error)"
        }
    }

    private var stateIcon: String {
        switch state {
        case .approved:
            return "checkmark.circle.fill"
        case .notDetermined:
            return "exclamationmark.circle"
        case .denied:
            return "xmark.octagon"
        case .approvedChild:
            return "person.fill.checkmark"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

@available(iOS 16.0, *)
private struct ModeInfoCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

@available(iOS 16.0, *)
struct ModeButton: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

@available(iOS 16.0, *)
struct AuthorizationLoadingView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)

            VStack(spacing: 8) {
                Text("Setting Up")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Checking Family Controls permissions...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
