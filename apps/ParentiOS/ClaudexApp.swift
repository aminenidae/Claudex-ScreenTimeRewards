import SwiftUI
import Core
import PointsEngine
import ScreenTimeService

@main
struct ClaudexScreenTimeRewardsApp: App {
    private let screenTimeService = ScreenTimeService()
    private let pointsEngine = PointsEngine()

    var body: some Scene {
        WindowGroup {
            ModeSelectionView(screenTimeService: screenTimeService, pointsEngine: pointsEngine)
        }
    }
}

struct ModeSelectionView: View {
    let screenTimeService: ScreenTimeService
    let pointsEngine: PointsEngine

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Claudex Screen Time Rewards")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Select how this device will be used today. Switch back to parent mode with Face ID/Touch ID or device passcode.")
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
