import SwiftUI
#if canImport(Core)
import Core
#endif

/// A live countdown timer showing remaining time in an earned time window
struct CountdownTimerView: View {
    let window: EarnedTimeWindow
    let style: CountdownStyle

    @State private var remainingSeconds: TimeInterval = 0
    @State private var timer: Timer?

    enum CountdownStyle {
        case compact    // "5:23 left"
        case expanded   // Large display with progress ring
        case minimal    // "5m 23s"
    }

    var body: some View {
        Group {
            switch style {
            case .compact:
                compactView
            case .expanded:
                expandedView
            case .minimal:
                minimalView
            }
        }
        .onAppear {
            updateRemainingTime()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Compact View

    private var compactView: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.caption)
                .foregroundColor(timeColor)

            Text(formattedTime)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(timeColor)

            Text("left")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(timeColor.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        VStack(spacing: 16) {
            ZStack {
                // Progress ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        timeColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: progress)

                // Time display
                VStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(timeColor)

                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 200)

            // Expiry time
            Text("Expires at \(window.endTime, style: .time)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Minimal View

    private var minimalView: some View {
        Text(formattedTimeMinimal)
            .font(.caption.monospacedDigit())
            .foregroundColor(timeColor)
    }

    // MARK: - Helpers

    private var formattedTime: String {
        let minutes = Int(remainingSeconds) / 60
        let seconds = Int(remainingSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedTimeMinimal: String {
        let minutes = Int(remainingSeconds) / 60
        let seconds = Int(remainingSeconds) % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    private var progress: CGFloat {
        guard window.durationSeconds > 0 else { return 0 }
        return CGFloat(remainingSeconds / window.durationSeconds)
    }

    private var timeColor: Color {
        if remainingSeconds < 60 {
            return .red
        } else if remainingSeconds < 180 {
            return .orange
        } else {
            return .green
        }
    }

    private func updateRemainingTime() {
        remainingSeconds = window.remainingSeconds
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateRemainingTime()

            // Stop timer when expired
            if remainingSeconds <= 0 {
                stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Previews

#Preview("Compact - 5 minutes left") {
    let window = EarnedTimeWindow(
        childId: ChildID("preview"),
        durationSeconds: 300,
        startTime: Date()
    )
    return CountdownTimerView(window: window, style: .compact)
        .padding()
}

#Preview("Expanded - 10 minutes left") {
    let window = EarnedTimeWindow(
        childId: ChildID("preview"),
        durationSeconds: 600,
        startTime: Date()
    )
    return CountdownTimerView(window: window, style: .expanded)
        .padding()
}

#Preview("Minimal - 45 seconds left") {
    let window = EarnedTimeWindow(
        childId: ChildID("preview"),
        durationSeconds: 60,
        startTime: Date().addingTimeInterval(-15)
    )
    return CountdownTimerView(window: window, style: .minimal)
        .padding()
}

#Preview("Warning state - 30 seconds left") {
    let window = EarnedTimeWindow(
        childId: ChildID("preview"),
        durationSeconds: 60,
        startTime: Date().addingTimeInterval(-30)
    )
    return VStack(spacing: 20) {
        CountdownTimerView(window: window, style: .compact)
        CountdownTimerView(window: window, style: .expanded)
        CountdownTimerView(window: window, style: .minimal)
    }
    .padding()
}
