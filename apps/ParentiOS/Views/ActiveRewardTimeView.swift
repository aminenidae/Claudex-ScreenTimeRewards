import SwiftUI
#if canImport(Core)
import Core
#endif

/// Full-screen view shown to child when reward time is active
struct ActiveRewardTimeView: View {
    let window: EarnedTimeWindow
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.green.opacity(0.3), .blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text("Reward Time Active!")
                        .font(.largeTitle.bold())

                    Text("Enjoy your earned screen time")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                // Large countdown timer
                CountdownTimerView(window: window, style: .expanded)
                    .padding(.vertical, 32)

                // Info card
                VStack(spacing: 16) {
                    HStack {
                        Label("Started", systemImage: "clock")
                        Spacer()
                        Text(window.startTime, style: .time)
                            .fontWeight(.semibold)
                    }

                    Divider()

                    HStack {
                        Label("Expires", systemImage: "clock.badge.exclamationmark")
                        Spacer()
                        Text(window.endTime, style: .time)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }

                    Divider()

                    HStack {
                        Label("Duration", systemImage: "timer")
                        Spacer()
                        Text(formattedDuration)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color(uiColor: .systemBackground).opacity(0.8))
                .cornerRadius(16)
                .padding(.horizontal)

                Spacer()

                // Dismiss button
                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    private var formattedDuration: String {
        let minutes = Int(window.durationSeconds) / 60
        return "\(minutes) minutes"
    }
}

#Preview("10 minutes remaining") {
    let window = EarnedTimeWindow(
        childId: ChildID("preview"),
        durationSeconds: 600,
        startTime: Date()
    )
    return ActiveRewardTimeView(window: window, onDismiss: {})
}

#Preview("About to expire") {
    let window = EarnedTimeWindow(
        childId: ChildID("preview"),
        durationSeconds: 60,
        startTime: Date().addingTimeInterval(-50)
    )
    return ActiveRewardTimeView(window: window, onDismiss: {})
}
