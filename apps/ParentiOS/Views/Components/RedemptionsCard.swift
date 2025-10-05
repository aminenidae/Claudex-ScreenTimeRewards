import SwiftUI
#if canImport(Core)
import Core
#endif

struct RedemptionsCard: View {
    let recentRedemptions: [PointsLedgerEntry]
    let activeWindow: EarnedTimeWindow?
    let remainingTime: String
    let onRedeem: (() -> Void)?

    var body: some View {
        DashboardCard(title: "Redemptions", systemImage: "clock.fill") {
            VStack(alignment: .leading, spacing: 12) {
                // Active exemption
                if let window = activeWindow, !window.isExpired {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active Reward Time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(remainingTime)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                } else {
                    HStack {
                        Text("No active reward time")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "pause.circle")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                // Recent redemptions list
                if !recentRedemptions.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(recentRedemptions.prefix(3)) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(abs(entry.amount)) points")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(entry.timestamp, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatMinutes(points: abs(entry.amount)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let onRedeem {
                    Button(action: onRedeem) {
                        HStack {
                            Image(systemName: "gift.fill")
                            Text("Redeem time")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func formatMinutes(points: Int) -> String {
        let minutes = points / 10 // Default ratio
        return "\(minutes) min"
    }
}

#Preview {
    let sampleRedemptions = [
        PointsLedgerEntry(childId: ChildID("test"), type: .redemption, amount: -50, timestamp: Date().addingTimeInterval(-3600)),
        PointsLedgerEntry(childId: ChildID("test"), type: .redemption, amount: -30, timestamp: Date().addingTimeInterval(-7200))
    ]

    RedemptionsCard(
        recentRedemptions: sampleRedemptions,
        activeWindow: nil,
        remainingTime: "No active time",
        onRedeem: nil
    )
    .padding()
}
