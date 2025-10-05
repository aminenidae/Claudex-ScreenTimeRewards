import SwiftUI

struct PointsBalanceCard: View {
    let balance: Int
    let todayPoints: Int
    let dailyCapProgress: Double

    var body: some View {
        DashboardCard(title: "Points Balance", systemImage: "star.fill") {
            VStack(alignment: .leading, spacing: 16) {
                // Main balance
                HStack(alignment: .firstTextBaseline) {
                    Text("\(balance)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("points")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Today's progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Today: \(todayPoints) points")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(dailyCapProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: dailyCapProgress)
                        .tint(.blue)
                }
            }
        }
    }
}

#Preview {
    PointsBalanceCard(balance: 250, todayPoints: 150, dailyCapProgress: 0.75)
        .padding()
}
