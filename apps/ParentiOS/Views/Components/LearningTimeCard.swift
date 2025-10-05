import SwiftUI

struct LearningTimeCard: View {
    let todayMinutes: Int
    let weekMinutes: Int

    var body: some View {
        DashboardCard(title: "Learning Time", systemImage: "book.fill") {
            HStack(spacing: 32) {
                // Today
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(todayMinutes)")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("min")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
                    .frame(height: 40)

                // This Week
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(weekMinutes)")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("min")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
    }
}

#Preview {
    LearningTimeCard(todayMinutes: 45, weekMinutes: 320)
        .padding()
}
