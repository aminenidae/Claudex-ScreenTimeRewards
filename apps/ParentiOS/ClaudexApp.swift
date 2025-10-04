import SwiftUI
import ScreenTimeService

@main
struct ClaudexScreenTimeRewardsApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 16.0, *) {
                ModeSelectionView()
            } else {
                Text("iOS 16 or newer is required.")
                    .padding()
            }
        }
    }
}

@available(iOS 16.0, *)
struct ModeSelectionView: View {
    @StateObject private var authorizationCoordinator = ScreenTimeAuthorizationCoordinator()
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
                        Text("Parent mode placeholder")
                            .font(.headline)
                            .navigationTitle("Parent Mode")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        ModeButton(title: "Parent Mode", subtitle: "Configure rules, review points, approve redemptions")
                    }

                    NavigationLink {
                        Text("Child mode placeholder")
                            .font(.headline)
                            .navigationTitle("Child Mode")
                            .navigationBarTitleDisplayMode(.inline)
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
private struct AuthorizationStatusBanner: View {
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
        case .notDetermined, .denied, .restricted:
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
        case .restricted:
            return "Authorization restricted"
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
        case .restricted:
            return "Family Controls is restricted (Screen Time/MDM policy). Resolve in Settings then retry."
        case .error(let error):
            return "Error requesting access: \(error.localizedDescription)"
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
        case .restricted:
            return "lock.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

private struct ModeButton: View {
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
