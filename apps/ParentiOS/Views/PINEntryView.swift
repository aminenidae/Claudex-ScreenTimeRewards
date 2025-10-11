import SwiftUI

/// View for PIN authentication to access Parent Mode
/// Shown when parent wants to access Parent Mode on child's device
@available(iOS 16.0, *)
struct PINEntryView: View {
    @EnvironmentObject private var pinManager: PINManager
    @Environment(\.dismiss) private var dismiss

    @State private var pin: String = ""
    @State private var shake: Bool = false
    @State private var showError: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("Parent Mode")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter your PIN to access Parent Mode")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                Spacer()

                // PIN Entry
                VStack(spacing: 16) {
                    // PIN Dots
                    HStack(spacing: 16) {
                        ForEach(0..<6, id: \.self) { index in
                            Circle()
                                .fill(pin.count > index ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 16, height: 16)
                        }
                    }
                    .offset(x: shake ? -10 : 0)
                    .animation(
                        shake ? .default.repeatCount(3).speed(6) : .default,
                        value: shake
                    )
                    .padding(.bottom, 24)

                    // Error or Lockout Message
                    if pinManager.isLockedOut, let lockoutEnd = pinManager.lockoutEndTime {
                        lockoutMessage(until: lockoutEnd)
                    } else if showError {
                        Text("Incorrect PIN (\(pinManager.failedAttempts)/\(3))")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Number Pad
                    if !pinManager.isLockedOut {
                        NumberPadView(text: $pin)
                    }
                }

                Spacer()

                // Biometric Option
                if !pinManager.isLockedOut {
                    Button(action: tryBiometricAuth) {
                        Label("Use Face ID", systemImage: "faceid")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: pin) { newValue in
                if newValue.count == 6 || (newValue.count >= 4 && newValue.allSatisfy({ $0.isNumber })) {
                    validatePIN()
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func lockoutMessage(until endTime: Date) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)

            Text("Too many failed attempts")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("Try again in \(timeRemaining(until: endTime))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func validatePIN() {
        let isValid = pinManager.validatePIN(pin)

        if isValid {
            // Success - dismiss and Parent Mode will be accessible
            dismiss()
        } else {
            // Failed - shake and clear
            showError = true
            shake = true
            pin = ""

            // Reset shake animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shake = false
            }

            // Hide error after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showError = false
            }
        }
    }

    private func tryBiometricAuth() {
        Task {
            let success = await pinManager.authenticateWithBiometrics()
            if success {
                dismiss()
            }
        }
    }

    private func timeRemaining(until endTime: Date) -> String {
        let remaining = Int(endTime.timeIntervalSinceNow)
        let minutes = remaining / 60
        let seconds = remaining % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Number Pad (Reuse from PINSetupView)

@available(iOS 16.0, *)
private struct NumberPadView: View {
    @Binding var text: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 3)
    private let buttons = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(buttons.flatMap { $0 }, id: \.self) { button in
                NumberButton(title: button, action: {
                    handleButtonTap(button)
                })
            }
        }
        .padding(.horizontal, 40)
    }

    private func handleButtonTap(_ button: String) {
        switch button {
        case "⌫":
            if !text.isEmpty {
                text.removeLast()
            }
        case "":
            break // Empty cell
        default:
            if text.count < 6 {
                text.append(button)
            }
        }
    }
}

@available(iOS 16.0, *)
private struct NumberButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title)
                .fontWeight(.medium)
                .foregroundStyle(title.isEmpty ? .clear : .primary)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(title.isEmpty ? Color.clear : Color(.tertiarySystemBackground))
                )
        }
        .disabled(title.isEmpty)
    }
}

// MARK: - Preview

#Preview {
    PINEntryView()
        .environmentObject(PINManager())
}
