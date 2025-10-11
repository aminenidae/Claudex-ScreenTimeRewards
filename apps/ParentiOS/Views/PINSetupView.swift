import SwiftUI

/// View for initial PIN setup on child's device
/// Shown when parent wants to configure Parent Mode for the first time
@available(iOS 16.0, *)
struct PINSetupView: View {
    @EnvironmentObject private var pinManager: PINManager
    @Environment(\.dismiss) private var dismiss

    @State private var pin: String = ""
    @State private var confirmPIN: String = ""
    @State private var currentStep: SetupStep = .enterPIN
    @State private var errorMessage: String?
    @State private var enableBiometrics: Bool = false

    enum SetupStep {
        case enterPIN
        case confirmPIN
        case biometricOption
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: headerIcon)
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text(headerTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                Spacer()

                // PIN Entry Section
                VStack(spacing: 16) {
                    if currentStep == .biometricOption {
                        biometricOptionView
                    } else {
                        pinInputView
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                // Action Button
                Button(action: handleAction) {
                    Text(actionButtonTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(actionButtonEnabled ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!actionButtonEnabled)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Setup Parent Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var pinInputView: some View {
        VStack(spacing: 12) {
            // PIN Dots
            HStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(currentPIN.count > index ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.bottom, 24)

            // Number Pad
            NumberPadView(text: binding(for: currentStep))
        }
    }

    private var biometricOptionView: some View {
        VStack(spacing: 20) {
            Toggle(isOn: $enableBiometrics) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Face ID")
                        .font(.headline)
                    Text("Use Face ID to quickly access Parent Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )

            Text("You can always change this in settings later")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
    }

    // MARK: - Computed Properties

    private var currentPIN: String {
        switch currentStep {
        case .enterPIN, .biometricOption:
            return pin
        case .confirmPIN:
            return confirmPIN
        }
    }

    private var headerIcon: String {
        switch currentStep {
        case .enterPIN:
            return "lock.shield"
        case .confirmPIN:
            return "checkmark.shield"
        case .biometricOption:
            return "faceid"
        }
    }

    private var headerTitle: String {
        switch currentStep {
        case .enterPIN:
            return "Create Your PIN"
        case .confirmPIN:
            return "Confirm Your PIN"
        case .biometricOption:
            return "Enable Biometrics?"
        }
    }

    private var headerSubtitle: String {
        switch currentStep {
        case .enterPIN:
            return "Create a 4-6 digit PIN to protect Parent Mode on this device"
        case .confirmPIN:
            return "Enter your PIN again to confirm"
        case .biometricOption:
            return "Use Face ID for faster access to Parent Mode"
        }
    }

    private var actionButtonTitle: String {
        switch currentStep {
        case .enterPIN, .confirmPIN:
            return "Continue"
        case .biometricOption:
            return "Complete Setup"
        }
    }

    private var actionButtonEnabled: Bool {
        switch currentStep {
        case .enterPIN:
            return pin.count >= 4 && pin.count <= 6
        case .confirmPIN:
            return confirmPIN.count >= 4 && confirmPIN.count <= 6
        case .biometricOption:
            return true
        }
    }

    // MARK: - Actions

    private func handleAction() {
        errorMessage = nil

        switch currentStep {
        case .enterPIN:
            // Validate PIN format
            guard pin.allSatisfy({ $0.isNumber }) else {
                errorMessage = "PIN must contain only numbers"
                return
            }
            currentStep = .confirmPIN

        case .confirmPIN:
            // Check if PINs match
            guard pin == confirmPIN else {
                errorMessage = "PINs do not match. Please try again."
                confirmPIN = ""
                return
            }

            // Move to biometric option
            currentStep = .biometricOption

        case .biometricOption:
            // Save PIN
            do {
                try pinManager.setPIN(pin)

                // Automatically authenticate after setup
                pinManager.isAuthenticated = true

                print("🔐 PINSetupView: PIN setup complete (biometrics: \(enableBiometrics))")
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func binding(for step: SetupStep) -> Binding<String> {
        switch step {
        case .enterPIN, .biometricOption:
            return $pin
        case .confirmPIN:
            return $confirmPIN
        }
    }
}

// MARK: - Number Pad

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
    PINSetupView()
        .environmentObject(PINManager())
}
