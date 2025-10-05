import SwiftUI
#if canImport(Core)
import Core
#endif

struct ShieldStatusCard: View {
    let shieldState: ShieldState
    let shieldedAppsCount: Int
    let activeWindow: EarnedTimeWindow?

    var body: some View {
        DashboardCard(title: "Shield Status", systemImage: "shield.fill") {
            HStack(spacing: 16) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    Image(systemName: statusIcon)
                        .font(.title)
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if shieldState == .active {
                        Text("\(shieldedAppsCount) apps shielded")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if shieldState == .exempted {
                        if let window = activeWindow {
                            CountdownTimerView(window: window, style: .compact)
                        } else {
                            Text("Reward apps accessible")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
        }
    }

    private var statusColor: Color {
        switch shieldState {
        case .active:
            return .blue
        case .exempted:
            return .green
        case .unknown:
            return .gray
        }
    }

    private var statusIcon: String {
        switch shieldState {
        case .active:
            return "shield.fill"
        case .exempted:
            return "play.circle.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var statusText: String {
        switch shieldState {
        case .active:
            return "Shields Active"
        case .exempted:
            return "Reward Time Active"
        case .unknown:
            return "Status Unknown"
        }
    }
}

#Preview("Active Shield") {
    ShieldStatusCard(
        shieldState: .active,
        shieldedAppsCount: 12,
        activeWindow: nil
    )
    .padding()
}

#Preview("Exempted with Countdown") {
    let window = EarnedTimeWindow(
        childId: ChildID("preview"),
        durationSeconds: 600,
        startTime: Date()
    )
    return ShieldStatusCard(
        shieldState: .exempted,
        shieldedAppsCount: 0,
        activeWindow: window
    )
    .padding()
}

#Preview("Exempted - Expiring Soon") {
    let window = EarnedTimeWindow(
        childId: ChildID("preview"),
        durationSeconds: 60,
        startTime: Date().addingTimeInterval(-30)
    )
    return ShieldStatusCard(
        shieldState: .exempted,
        shieldedAppsCount: 0,
        activeWindow: window
    )
    .padding()
}
