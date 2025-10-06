import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WeeklyReportConfiguration: Equatable {
    let todayMinutes: Int
    let weekMinutes: Int
    let errorMessage: String?
}

struct WeeklyReportView: View {
    let configuration: WeeklyReportConfiguration

    var body: some View {
        if let errorMessage = configuration.errorMessage {
            Text(errorMessage)
                .multilineTextAlignment(.center)
                .padding()
        } else {
            WeeklyLearningSummary(
                todayMinutes: configuration.todayMinutes,
                weekMinutes: configuration.weekMinutes
            )
            .padding()
        }
    }
}

private struct WeeklyLearningSummary: View {
    let todayMinutes: Int
    let weekMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Learning Time")
                .font(.headline)

            HStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(todayMinutes) min")
                        .font(.title2.weight(.semibold))
                }

                Divider()
                    .frame(height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(weekMinutes) min")
                        .font(.title2.weight(.semibold))
                }

                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    WeeklyReportView(
        configuration: WeeklyReportConfiguration(
            todayMinutes: 45,
            weekMinutes: 320,
            errorMessage: nil
        )
    )
}
