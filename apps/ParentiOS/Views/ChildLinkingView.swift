import SwiftUI
#if canImport(Core)
import Core
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Child view for entering pairing code to link device
struct ChildLinkingView: View {
    let prefilledCode: String?
    let onPairingComplete: (ChildDevicePairing) -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var pairingService: PairingService
    @State private var codeDigits: [String]
    @State private var isLoading = false
    @State private var error: Error?
    @State private var focusedIndex: Int
    @State private var shouldAutoSubmit: Bool
    @State private var isSyncing = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("Link to Parent Account")
                    .font(.title.bold())

                Text("Enter the 6-digit pairing code from your parent's device")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Code input
            codeInputSection

            // Submit button
            submitButtonSection

            Spacer()

            // Help text
            VStack(spacing: 8) {
                Text("Don't have a code?")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Text("Ask your parent to generate a pairing code in the Claudex app")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Sync status
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
        .padding(.bottom, 32)
        .padding()
        .navigationTitle("Link Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
            }
        }
        .alert("Pairing Error", isPresented: .constant(error != nil), presenting: error) { _ in
            Button("OK") {
                error = nil
                clearCode()
            }
        } message: { err in
            Text(err.localizedDescription)
        }
        .overlay {
            if isLoading {
                LoadingOverlay()
            }
        }
        .onAppear {
            autoSubmitIfNeeded()
            Task {
                await syncWithCloudKit()
            }
        }
    }

    // MARK: - Sections

    private var codeInputSection: some View {
        HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
                CodeDigitField(
                    digit: $codeDigits[index],
                    isFocused: focusedIndex == index,
                    onSubmit: {
                        handleDigitInput(at: index)
                    }
                )
            }
        }
        .padding(.horizontal)
    }

    private var submitButtonSection: some View {
        Button(action: submitCode) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Link Device")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isCodeComplete ? Color.green : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!isCodeComplete || isLoading)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var isCodeComplete: Bool {
        codeDigits.allSatisfy { !$0.isEmpty }
    }

    private var enteredCode: String {
        codeDigits.joined()
    }

    private func handleDigitInput(at index: Int) {
        // Auto-advance to next field
        if !codeDigits[index].isEmpty && index < 5 {
            focusedIndex = index + 1
        }

        // Auto-submit when complete
        if isCodeComplete && index == 5 {
            submitCode()
        }
    }

    private func syncWithCloudKit() async {
        #if canImport(CloudKit)
        guard !isSyncing else { 
            print("Child device: Sync already in progress, skipping")
            return 
        }
        isSyncing = true
        defer { 
            isSyncing = false
            print("Child device: Finished CloudKit sync attempt")
        }

        do {
            // Use the same family ID as the parent device
            let familyId = FamilyID("default-family")
            print("Child device: Attempting to sync pairing codes with CloudKit for family: \(familyId)")
            
            // First, try to fetch the family record to verify CloudKit is working
            if let syncService = pairingService.syncService as? SyncService {
                print("Child device: Testing CloudKit connectivity...")
                do {
                    let family = try await syncService.fetchFamily(id: familyId)
                    print("Child device: Successfully fetched family record: \(family)")
                } catch {
                    print("Child device: Failed to fetch family record: \(error)")
                }
            }
            
            try await pairingService.syncWithCloudKit(familyId: familyId)
            print("Child device: Successfully synced pairing codes with CloudKit")
            
            // Add a small delay to ensure sync completes
            print("Child device: Waiting for sync to settle...")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Print available codes after sync
            await MainActor.run {
                print("Child device: Available codes after sync: \(pairingService.activeCodes.keys)")
                if pairingService.activeCodes.isEmpty {
                    print("Child device: No pairing codes are currently available after sync. If this device is already paired, this is expected.")
                }
            }
        } catch let error as SyncError {
            print("Child device: CloudKit sync failed with SyncError: \(error)")
            switch error {
            case .notAuthenticated:
                print("Child device: iCloud not authenticated. Please check iCloud settings.")
            case .networkUnavailable:
                print("Child device: Network unavailable. Please check internet connection.")
            case .quotaExceeded:
                print("Child device: iCloud quota exceeded.")
            case .serverError(let message):
                print("Child device: CloudKit server error: \(message)")
            case .conflictResolutionFailed:
                print("Child device: Conflict resolution failed.")
            case .invalidRecord(let message):
                print("Child device: Invalid record: \(message)")
            }
        } catch {
            print("Child device: CloudKit sync failed with unexpected error: \(error)")
        }
        #else
        print("Child device: CloudKit not available, skipping CloudKit sync")
        #endif
    }

    private func submitCode() {
        guard isCodeComplete else { 
            print("Child device: Code not complete, skipping submission")
            return 
        }

        isLoading = true
        print("Child device: Attempting to submit pairing code: \(enteredCode)")

        Task {
            // Add a small delay to ensure any ongoing sync completes
            print("Child device: Waiting briefly to ensure sync completion...")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            
            do {
                let deviceId = await getDeviceIdentifier()
                print("Child device: Attempting to pair with code: \(enteredCode) for device: \(deviceId)")
                
                // First, let's check what codes are available locally
                await MainActor.run {
                    print("Child device: Available local codes before consumption attempt: \(pairingService.activeCodes.keys)")
                }
                
                let pairing = try await MainActor.run {
                    return try pairingService.consumePairingCode(enteredCode, deviceId: deviceId)
                }

                // Store pairing locally
                await storePairingLocally(pairing)

                // Success
                await MainActor.run {
                    isLoading = false
                    print("Child device: Successfully paired with code \(enteredCode)")
                    onPairingComplete(pairing)
                }
            } catch {
                print("Child device: Pairing failed with error: \(error)")
                await MainActor.run {
                    isLoading = false
                    self.error = error
                }
            }
        }
    }

    private func clearCode() {
        codeDigits = ["", "", "", "", "", ""]
        focusedIndex = 0
        shouldAutoSubmit = false
    }

    private func getDeviceIdentifier() async -> String {
        // Use platform-specific identifier for repeatable device binding
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        return ProcessInfo.processInfo.globallyUniqueString
        #endif
    }

    private func storePairingLocally(_ pairing: ChildDevicePairing) async {
        let defaults = UserDefaults.standard
        // Persist full pairing for child mode to restore after relaunch
        if let encoded = try? JSONEncoder().encode(pairing) {
            defaults.set(encoded, forKey: PairingService.localPairingDefaultsKey)
        }

        // Legacy keys kept for compatibility with earlier builds
        defaults.set(pairing.childId.rawValue, forKey: "com.claudex.pairedChildId")
        defaults.set(pairing.deviceId, forKey: "com.claudex.deviceId")
    }
}

// MARK: - Initializers & Helpers

extension ChildLinkingView {
    init(
        prefilledCode: String? = nil,
        onPairingComplete: @escaping (ChildDevicePairing) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.prefilledCode = Self.cleanedCode(prefilledCode)
        self.onPairingComplete = onPairingComplete
        self.onCancel = onCancel

        let digits = Self.initialDigits(from: self.prefilledCode)
        _codeDigits = State(initialValue: digits)
        _focusedIndex = State(initialValue: Self.initialFocusIndex(for: digits))
        _shouldAutoSubmit = State(initialValue: digits.allSatisfy { !$0.isEmpty })
    }

    private func autoSubmitIfNeeded() {
        guard shouldAutoSubmit else { return }
        shouldAutoSubmit = false
        submitCode()
    }

    private static func cleanedCode(_ code: String?) -> String? {
        guard let code, code.count == 6 else { return nil }
        let digits = code.filter { $0.isNumber }
        return digits.count == 6 ? digits : nil
    }

    private static func initialDigits(from code: String?) -> [String] {
        guard let code else { return Array(repeating: "", count: 6) }
        return code.map { String($0) }
    }

    private static func initialFocusIndex(for digits: [String]) -> Int {
        if let firstEmpty = digits.firstIndex(where: { $0.isEmpty }) {
            return firstEmpty
        }
        return 5
    }
}

// MARK: - Code Digit Field

private struct CodeDigitField: View {
    @Binding var digit: String
    let isFocused: Bool
    let onSubmit: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        TextField("", text: $digit)
            .font(.system(size: 48, weight: .bold, design: .monospaced))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .frame(width: 50, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .focused($isTextFieldFocused)
            .onChange(of: digit) { newValue in
                // Limit to a single numeric character for iOS 16 compatibility
                let cleaned = String(newValue.filter { $0.isNumber }.prefix(1))

                if digit != cleaned {
                    digit = cleaned
                }

                // Auto-submit on input once the value is sanitized
                if !cleaned.isEmpty {
                    onSubmit()
                }
            }
            .onChange(of: isFocused) { newValue in
                if isTextFieldFocused != newValue {
                    isTextFieldFocused = newValue
                }
            }
            .onAppear {
                if isFocused {
                    isTextFieldFocused = true
                }
            }
    }
}

// MARK: - Loading Overlay

private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Linking device...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
            )
        }
    }
}

// MARK: - Previews

#Preview("Initial State") {
    NavigationStack {
        ChildLinkingView(
            onPairingComplete: { _ in },
            onCancel: {}
        )
        .environmentObject(PairingService())
    }
}

#Preview("Prefilled Code") {
    NavigationStack {
        ChildLinkingView(
            prefilledCode: "123456",
            onPairingComplete: { _ in },
            onCancel: {}
        )
        .environmentObject(PairingService())
    }
}
