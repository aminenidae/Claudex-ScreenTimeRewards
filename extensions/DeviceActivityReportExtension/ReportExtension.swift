import DeviceActivity
import SwiftUI

@main
struct ReportExtension: DeviceActivityReportExtension {
    func makeConfiguration() -> DeviceActivityReport.Configuration {
        DeviceActivityReport.Configuration(
            userVisibleName: "Weekly Summary",
            userVisibleDescription: "Basic placeholder report"
        )
    }

    func makeView(controller: DeviceActivityReportController) -> some View {
        Text("Weekly Report Placeholder")
            .padding()
    }
}

