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
    @State private var isSyncing = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let syncTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect() // Sync every 5 seconds

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
            .onReceive(syncTimer) { _ in
                // Sync with CloudKit every 5 seconds to detect when child pairs
                Task {
                    await syncWithCloudKit()
                }
            }
            .onAppear(perform: onAppear)
            .onReceive(pairingService.objectWillChange) { _ in
                loadActiveCode()
            }
        }
    }

    // MARK: - Lifecycle

    private func onAppear() {
        loadActiveCode()
        Task {
            await syncWithCloudKit()
        }
    }

    private func syncWithCloudKit() async {
        #if canImport(CloudKit)
        guard !isSyncing else { 
            print("Parent device: Sync already in progress, skipping")
            return 
        }
        isSyncing = true
        defer { 
            isSyncing = false
            print("Parent device: Finished CloudKit sync attempt")
        }

        do {
            // Use the same family ID as the child device
            let familyId = FamilyID("default-family")
            print("Parent device: Attempting to sync pairing codes with CloudKit for family: \(familyId)")
            
            // First, try to fetch the family record to verify CloudKit is working
            if let syncService = pairingService.syncService as? SyncService {
                print("Parent device: Testing CloudKit connectivity...")
                do {
                    let family = try await syncService.fetchFamily(id: familyId)
                    print("Parent device: Successfully fetched family record: \(family)")
                } catch {
                    print("Parent device: Failed to fetch family record: \(error)")
                }
            }

            try await pairingService.syncWithCloudKit(familyId: familyId)
            print("Parent device: Successfully synced pairing codes with CloudKit")
            
            // Add a small delay to ensure sync completes
            print("Parent device: Waiting for sync to settle...")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await MainActor.run {
                loadActiveCode()
            }
        } catch let error as SyncError {
            print("Parent device: CloudKit sync failed with SyncError: \(error)")
            switch error {
            case .notAuthenticated:
                print("Parent device: iCloud not authenticated. Please check iCloud settings.")
            case .networkUnavailable:
                print("Parent device: Network unavailable. Please check internet connection.")
            case .quotaExceeded:
                print("Parent device: iCloud quota exceeded.")
            case .serverError(let message):
                print("Parent device: CloudKit server error: \(message)")
            case .conflictResolutionFailed:
                print("Parent device: Conflict resolution failed.")
            case .invalidRecord(let message):
                print("Parent device: Invalid record: \(message)")
            }
        } catch {
            print("Parent device: CloudKit sync failed with unexpected error: \(error)")
        }
        #else
        print("Parent device: CloudKit not available, skipping CloudKit sync")
        #endif
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

            #if canImport(CloudKit)
            if isSyncing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Syncing with CloudKit...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            #endif
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
        guard !isGenerating else { 
            print("Parent device: Code generation already in progress, skipping")
            return 
        }
        isGenerating = true
        defer { 
            isGenerating = false
            print("Parent device: Finished code generation attempt")
        }

        do {
            let code = try pairingService.generatePairingCode(for: childId, ttlMinutes: 15)
            print("Parent device: Generated new pairing code: \(code.code) for child: \(childId)")
            pairingCode = code
            isExpired = false
            updateTimeRemaining()
            
            // Sync the new code with CloudKit
            Task {
                await syncWithCloudKit()
            }
        } catch {
            print("Parent device: Failed to generate pairing code: \(error)")
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
