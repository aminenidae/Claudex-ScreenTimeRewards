import SwiftUI
#if canImport(Core)
import Core
#endif

/// Parent view for generating and displaying pairing codes
struct PairingCodeView: View {
    let childId: ChildID
    let childDisplayName: String?
    let onDismiss: () -> Void

    @EnvironmentObject private var pairingService: PairingService
    @State private var pairingCode: PairingCode?
    @State private var error: Error?
    @State private var timeRemaining: TimeInterval = 0
    @State private var isExpired = false
    @State private var isGenerating = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("Pair Child Device")
                        .font(.title.bold())

                    if let name = childDisplayName {
                        Text("For \(name)")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 32)

                if let code = pairingCode {
                    // Pairing code display
                    codeDisplaySection(code: code)
                } else {
                    // Generate button
                    generateButtonSection
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(error != nil), presenting: error) { _ in
                Button("OK") { error = nil }
            } message: { err in
                Text(err.localizedDescription)
            }
            .onReceive(timer) { _ in
                updateTimeRemaining()
            }
            .onAppear(perform: loadActiveCode)
            .onReceive(pairingService.objectWillChange) { _ in
                loadActiveCode()
            }
        }
    }

    // MARK: - Sections

    private var generateButtonSection: some View {
        VStack(spacing: 16) {
            Text("Generate a pairing code to link your child's device")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button(action: generateCode) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Generate Pairing Code")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isGenerating ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(isGenerating)
        }
    }

    private func codeDisplaySection(code: PairingCode) -> some View {
        VStack(spacing: 24) {
            // Large code display
            Text(formattedCode(code.code))
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .foregroundColor(isExpired ? .red : .blue)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8)
                )

            // Expiry timer
            VStack(spacing: 8) {
                if isExpired {
                    Label("Code Expired", systemImage: "clock.badge.exclamationmark.fill")
                        .font(.headline)
                        .foregroundColor(.red)
                } else {
                    Label(timeRemainingText, systemImage: "clock")
                        .font(.headline)
                        .foregroundColor(timeRemaining < 180 ? .orange : .green)
                }
            }

            // Instructions
            VStack(spacing: 12) {
                Text("To pair your child's device:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    InstructionRow(number: 1, text: "Open Claudex on child's device")
                    InstructionRow(number: 2, text: "Tap \"Link to Parent Account\"")
                    InstructionRow(number: 3, text: "Enter this 6-digit code")
                    InstructionRow(number: 4, text: "Complete setup")
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)

            // Deep link
            ShareLink(
                item: pairingService.deepLinkURL(for: code),
                subject: Text("Claudex Pairing Link"),
                message: Text("Tap to pair your device with Claudex")
            ) {
                HStack {
                    Image(systemName: "link")
                    Text("Share Pairing Link")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }

            // Regenerate button
            if isExpired {
                Button(action: generateCode) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Generate New Code")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formattedCode(_ code: String) -> String {
        // Format as "123 456" for readability
        guard code.count == 6 else { return code }
        let firstThree = code.prefix(3)
        let lastThree = code.suffix(3)
        return "\(firstThree) \(lastThree)"
    }

    private var timeRemainingText: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return "Expires in \(minutes):\(String(format: "%02d", seconds))"
    }

    private func generateCode() {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        do {
            let code = try pairingService.generatePairingCode(for: childId, ttlMinutes: 15)
            pairingCode = code
            isExpired = false
            updateTimeRemaining()
        } catch {
            self.error = error
        }
    }

    private func updateTimeRemaining() {
        guard let code = pairingCode else { return }

        let remaining = code.expiresAt.timeIntervalSince(Date())
        timeRemaining = max(0, remaining)

        if timeRemaining == 0 && !isExpired {
            isExpired = true
        }
    }

    private func loadActiveCode() {
        if let active = pairingService.activeCode(for: childId) {
            pairingCode = active
            isExpired = active.isExpired
            updateTimeRemaining()
        } else if pairingCode != nil {
            pairingCode = nil
            isExpired = false
            timeRemaining = 0
        }
    }
}

// MARK: - Instruction Row

private struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Initial State") {
    PairingCodeView(
        childId: ChildID("preview-child"),
        childDisplayName: "Emma",
        onDismiss: {}
    )
    .environmentObject(PairingService())
}

#Preview("Code Generated") {
    struct PreviewWrapper: View {
        @State var code = PairingCode(
            code: "123456",
            childId: ChildID("preview-child")
        )

        var body: some View {
            NavigationView {
                VStack {
                    Text(code.code)
                }
            }
        }
    }

    return PreviewWrapper()
}
