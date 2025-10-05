import SwiftUI
#if canImport(Core)
import Core
#endif

struct ChildRedemptionView: View {
    @ObservedObject var redemptionCoordinator: RedemptionCoordinator
    @State private var pointsToRedeem: String = ""

    let pointsBalance: Int
    let config: RedemptionConfiguration

    var body: some View {
        VStack(spacing: 20) {
            if let activeWindow = redemptionCoordinator.activeWindow {
                ActiveExemptionView(activeWindow: activeWindow)
            } else {
                RedemptionForm()
            }
        }
        .padding()
    }

    @ViewBuilder
    private func RedemptionForm() -> some View {
        VStack(spacing: 20) {
            Text("Points Balance: \(pointsBalance)")
                .font(.title)

            TextField("Points to redeem", text: $pointsToRedeem)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            if let points = Int(pointsToRedeem) {
                let minutes = redemptionCoordinator.calculateMinutes(points: points, config: config)
                Text("You will get \(Int(minutes)) minutes of screen time.")
                    .font(.headline)
            }

            Button("Redeem") {
                if let points = Int(pointsToRedeem) {
                    redemptionCoordinator.redeem(points: points, config: config)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(Int(pointsToRedeem) == nil)
        }
    }
}

struct ActiveExemptionView: View {
    let activeWindow: EarnedTimeWindow

    var body: some View {
        VStack(spacing: 20) {
            Text("Time Remaining")
                .font(.title)
            Text(formatTime(seconds: activeWindow.remainingSeconds))
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }

    private func formatTime(seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "00:00"
    }
}

extension RedemptionCoordinator {
    func calculateMinutes(points: Int, config: RedemptionConfiguration) -> Double {
        return Double(points) / Double(config.pointsPerMinute)
    }
}
