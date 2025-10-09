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
    @State private var showPairingSuccess = false

    init(prefilledCode: String?, onPairingComplete: @escaping (ChildDevicePairing) -> Void, onCancel: @escaping () -> Void) {
        self.prefilledCode = prefilledCode
        self.onPairingComplete = onPairingComplete
        self.onCancel = onCancel
        
        if let code = prefilledCode, code.count == 6 {
            self._codeDigits = State(initialValue: code.map { String($0) })
            self._focusedIndex = State(initialValue: 5) // Focus at the end
            self._shouldAutoSubmit = State(initialValue: true)
        } else {
            self._codeDigits = State(initialValue: Array(repeating: "", count: 6))
            self._focusedIndex = State(initialValue: 0)
            self._shouldAutoSubmit = State(initialValue: false)
        }
    }

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
        .alert("Success!", isPresented: $showPairingSuccess) {
            Button("Continue") {
                // The onPairingComplete callback will be called in the submitCode function
            }
        } message: {
            Text("Device successfully linked to parent account!")
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
        guard isCodeComplete else { return }
        
        let deviceId = getDeviceId()
        isLoading = true
        error = nil
        
        Task {
            do {
                // Try to consume the pairing code
                let pairing = try pairingService.consumePairingCode(enteredCode, deviceId: deviceId)
                
                await MainActor.run {
                    isLoading = false
                    showPairingSuccess = true
                    
                    // Delay calling onPairingComplete to allow the success alert to be shown
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onPairingComplete(pairing)
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    self.error = error
                }
            }
        }
    }

    private func autoSubmitIfNeeded() {
        if shouldAutoSubmit && isCodeComplete {
            submitCode()
        }
    }

    private func clearCode() {
        codeDigits = Array(repeating: "", count: 6)
        focusedIndex = 0
    }

    private func getDeviceId() -> String {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        return ProcessInfo.processInfo.globallyUniqueString
        #endif
    }
}

// MARK: - Code Digit Field

private struct CodeDigitField: View {
    @Binding var digit: String
    let isFocused: Bool
    let onSubmit: () -> Void

    var body: some View {
        TextField("", text: $digit)
            .multilineTextAlignment(.center)
            .font(.system(size: 32, weight: .bold, design: .monospaced))
            .frame(width: 50, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue : Color.gray, lineWidth: 2)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.clear))
            )
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .onChange(of: digit) { newValue in
                // Limit to single digit
                if newValue.count > 1 {
                    digit = String(newValue.prefix(1))
                }
                
                // Filter non-numeric characters
                if let number = Int(newValue), number >= 0 && number <= 9 {
                    // Valid digit, allow it
                } else if !newValue.isEmpty {
                    // Invalid character, clear it
                    digit = ""
                }
                
                // Auto-submit when we have a digit
                if !newValue.isEmpty {
                    onSubmit()
                }
            }
    }
}

// MARK: - Loading Overlay

private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 10)
                )
        }
    }
}

#Preview("Child Linking View") {
    NavigationStack {
        ChildLinkingView(
            prefilledCode: nil,
            onPairingComplete: { _ in },
            onCancel: {}
        )
        .environmentObject(PairingService())
    }
}

#Preview("Child Linking View with Prefilled Code") {
    NavigationStack {
        ChildLinkingView(
            prefilledCode: "123456",
            onPairingComplete: { _ in },
            onCancel: {}
        )
        .environmentObject(PairingService())
    }
}