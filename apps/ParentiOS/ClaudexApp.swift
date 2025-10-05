import SwiftUI
#if canImport(ScreenTimeService)
import ScreenTimeService
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

@main
struct ClaudexScreenTimeRewardsApp: App {
    @StateObject private var authorizationCoordinator = ScreenTimeAuthorizationCoordinator()
    @StateObject private var childrenManager = {
        let ledger = PointsLedger()
        let engine = PointsEngine()
        let exemptionManager = ExemptionManager()
        let redemptionService = RedemptionService(ledger: ledger)
        return ChildrenManager(
            ledger: ledger,
            engine: engine,
            exemptionManager: exemptionManager,
            redemptionService: redemptionService
        )
    }()
    @StateObject private var pairingService = PairingService()
    @State private var pendingPairingCode: String?

    var body: some Scene {
        WindowGroup {
            if #available(iOS 16.0, *) {
                ModeSelectionView(pendingPairingCode: $pendingPairingCode)
                    .environmentObject(authorizationCoordinator)
                    .environmentObject(childrenManager)
                    .environmentObject(pairingService)
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
            } else {
                Text("iOS 16 or newer is required.")
                    .padding()
            }
        }
    }
}

@available(iOS 16.0, *)
private extension ClaudexScreenTimeRewardsApp {
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
    @Binding var pendingPairingCode: String?
    @State private var navigateToChildMode = false

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
                    Text("Select how this device will be used. Parent mode requires Face ID / Touch ID / passcode; child mode shows their points and rewards.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    NavigationLink {
                        ParentModeView()
                            .environmentObject(authorizationCoordinator)
                            .environmentObject(childrenManager)
                            .environmentObject(pairingService)
                    } label: {
                        ModeButton(title: "Parent Mode", subtitle: "Configure rules, review points, approve redemptions")
                    }

                    NavigationLink(isActive: $navigateToChildMode) {
                        ChildModeView(pendingPairingCode: $pendingPairingCode)
                            .environmentObject(authorizationCoordinator)
                            .environmentObject(childrenManager)
                            .environmentObject(pairingService)
                    } label: {
                        ModeButton(title: "Child Mode", subtitle: "Earn points, see rewards, request more time")
                    }
                }

                Spacer()
            }
            .padding()
            .task { await authorizationCoordinator.refreshStatus() }
            .onChange(of: pendingPairingCode) { newValue in
                if newValue != nil {
                    navigateToChildMode = true
                }
            }
        }
    }
}

@available(iOS 16.0, *)
struct ChildModeView: View {
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var pairingService: PairingService
    @Binding var pendingPairingCode: String?

    @State private var currentPairing: ChildDevicePairing?
    @State private var revokeError: Error?
    @State private var showingUnlinkConfirmation = false

    private let deviceId: String

    init(pendingPairingCode: Binding<String?>) {
        self._pendingPairingCode = pendingPairingCode
        #if canImport(UIKit)
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        self.deviceId = ProcessInfo.processInfo.globallyUniqueString
        #endif
    }

    var body: some View {
        content
            .navigationTitle("Child Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentPairing != nil {
                        Button("Unlink") {
                            showingUnlinkConfirmation = true
                        }
                    }
                }
            }
            .confirmationDialog("Unlink device?", isPresented: $showingUnlinkConfirmation, titleVisibility: .visible) {
                Button("Unlink Device", role: .destructive) {
                    unlinkDevice()
                }
                Button("Cancel", role: .cancel) { showingUnlinkConfirmation = false }
            }
            .alert("Unable to unlink", isPresented: .constant(revokeError != nil), presenting: revokeError) { _ in
                Button("OK", role: .cancel) { revokeError = nil }
            } message: { error in
                Text(error.localizedDescription)
            }
            .onAppear(perform: refreshPairing)
            .onReceive(pairingService.objectWillChange) { _ in
                refreshPairing()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let pairing = currentPairing {
            pairedContent(for: pairing)
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

        return ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Device Linked")
                    .font(.title)
                    .fontWeight(.semibold)

                if let childProfile {
                    Text("You're paired as \(childProfile.name)")
                        .font(.headline)
                } else {
                    Text("Paired child ID: \(pairing.childId.rawValue)")
                        .font(.headline)
                }

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

                Button(role: .destructive) {
                    showingUnlinkConfirmation = true
                } label: {
                    Label("Unlink Device", systemImage: "link.badge.minus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)

                Spacer(minLength: 20)
            }
            .padding(.vertical, 32)
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
        defaults.removeObject(forKey: "com.claudex.deviceId")
    }

    private func handlePairingComplete(_ pairing: ChildDevicePairing) {
        currentPairing = pairing
        pendingPairingCode = nil
    }

    private func handlePairingCancelled() {
        pendingPairingCode = nil
    }

    private func unlinkDevice() {
        do {
            try pairingService.revokePairing(for: deviceId)
            clearStoredPairing()
            currentPairing = nil
            showingUnlinkConfirmation = false
        } catch {
            revokeError = error
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
