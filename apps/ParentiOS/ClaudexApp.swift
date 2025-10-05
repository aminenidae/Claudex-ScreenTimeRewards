import SwiftUI
#if canImport(ScreenTimeService)
import ScreenTimeService
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

@main
struct ClaudexScreenTimeRewardsApp: App {
    @StateObject private var authorizationCoordinator = ScreenTimeAuthorizationCoordinator()
    @StateObject private var childrenManager = ChildrenManager(
        ledger: PointsLedger(), // Assuming PointsLedger is initialized here or passed in
        engine: PointsEngine(),
        exemptionManager: ExemptionManager(),
        rewardCoordinator: nil // RewardCoordinator will be passed later if needed
    )

    var body: some Scene {
        WindowGroup {
            if #available(iOS 16.0, *) {
                ModeSelectionView()
                    .environmentObject(authorizationCoordinator)
                    .environmentObject(childrenManager)
            } else {
                Text("iOS 16 or newer is required.")
                    .padding()
            }
        }
    }
}

@available(iOS 16.0, *)
struct ModeSelectionView: View {
    @EnvironmentObject private var authorizationCoordinator: ScreenTimeAuthorizationCoordinator
    @EnvironmentObject private var childrenManager: ChildrenManager

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
                    } label: {
                        ModeButton(title: "Parent Mode", subtitle: "Configure rules, review points, approve redemptions")
                    }

                    NavigationLink {
                        ChildModeView()
                            .environmentObject(authorizationCoordinator)
                            .environmentObject(childrenManager)
                    } label: {
                        ModeButton(title: "Child Mode", subtitle: "Earn points, see rewards, request more time")
                    }
                }

                Spacer()
            }
            .padding()
            .task { await authorizationCoordinator.refreshStatus() }
        }
    }
}

@available(iOS 16.0, *)
struct ChildModeView: View {
    @EnvironmentObject private var authorizationCoordinator: ScreenTimeAuthorizationCoordinator
    @EnvironmentObject private var childrenManager: ChildrenManager

    var body: some View {
        Text("Child Mode View Placeholder")
            .font(.largeTitle)
            .navigationTitle("Child Mode")
            .navigationBarTitleDisplayMode(.inline)
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
