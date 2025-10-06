import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    static let weeklySummary = Self("Weekly Summary")
}

struct WeeklySummaryReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .weeklySummary
    let content: (WeeklyReportConfiguration) -> WeeklyReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> WeeklyReportConfiguration {
        do {
            let (todaySeconds, totalSeconds) = try await summarize(data)
            return WeeklyReportConfiguration(
                todayMinutes: Int(todaySeconds / 60),
                weekMinutes: Int(totalSeconds / 60),
                errorMessage: nil
            )
        } catch {
            return WeeklyReportConfiguration(
                todayMinutes: 0,
                weekMinutes: 0,
                errorMessage: "Failed to load weekly activity."
            )
        }
    }

    private func summarize(_ results: DeviceActivityResults<DeviceActivityData>) async throws -> (today: TimeInterval, total: TimeInterval) {
        var today: TimeInterval = 0
        var total: TimeInterval = 0
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        for try await data in results {
            for segment in data.activitySegments {
                total += segment.totalActivityDuration
                if segment.dateInterval.start >= startOfToday {
                    today += segment.totalActivityDuration
                }
            }
        }

        return (today, total)
    }
}

@main
struct ReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        WeeklySummaryReport { configuration in
            WeeklyReportView(configuration: configuration)
        }
    }
}
