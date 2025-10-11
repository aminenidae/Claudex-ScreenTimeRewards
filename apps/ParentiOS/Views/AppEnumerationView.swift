import SwiftUI
import FamilyControls
#if canImport(Core)
import Core
#endif
#if canImport(SyncKit)
import SyncKit
#endif

/// View for child device to select all installed apps during initial setup
@available(iOS 16.0, *)
struct AppEnumerationView: View {
    let childId: ChildID
    let deviceId: String
    let onComplete: () -> Void

    @EnvironmentObject private var syncService: SyncService
    @State private var selectedApps = FamilyActivitySelection()
    @State private var showingPicker = false
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "apps.iphone")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Select Your Apps")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Help us show your parent only the apps you have on this device. This is a one-time setup.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)

            // Selection Status
            VStack(spacing: 16) {
                if selectedApps.applicationTokens.isEmpty {
                    Text("No apps selected yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        Text("\(selectedApps.applicationTokens.count) apps selected")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if selectedApps.categoryTokens.count > 0 {
                            Text("+ \(selectedApps.categoryTokens.count) categories")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    showingPicker = true
                } label: {
                    Label(
                        selectedApps.applicationTokens.isEmpty ? "Select All Your Apps" : "Update Selection",
                        systemImage: "square.grid.2x2"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUploading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text("1️⃣")
                        .font(.title3)
                    Text("Tap 'Select All Your Apps' above")
                        .font(.subheadline)
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("2️⃣")
                        .font(.title3)
                    Text("Choose all the apps installed on this device")
                        .font(.subheadline)
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("3️⃣")
                        .font(.title3)
                    Text("Tap 'Continue' when done")
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.tertiarySystemBackground))
            )
            .padding(.horizontal)

            Spacer()

            // Error Message
            if let error = uploadError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Continue Button
            Button {
                uploadInventory()
            } label: {
                if isUploading {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text("Uploading...")
                    }
                } else {
                    Text("Continue")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedApps.applicationTokens.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(selectedApps.applicationTokens.isEmpty || isUploading)

            // Skip Option
            Button {
                onComplete()
            } label: {
                Text("Skip for Now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom)
            .disabled(isUploading)
        }
        .navigationTitle("App Setup")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showingPicker) {
            FamilyActivityPicker(selection: $selectedApps)
        }
    }

    private func uploadInventory() {
        #if canImport(CloudKit)
        guard !selectedApps.applicationTokens.isEmpty else { return }

        isUploading = true
        uploadError = nil

        Task {
            do {
                print("📱 AppEnumerationView: Starting app inventory upload")

                // Convert tokens to base64
                let appTokens = selectedApps.applicationTokens.map { token in
                    let data = withUnsafeBytes(of: token) { Data($0) }
                    return data.base64EncodedString()
                }

                let categoryTokens = selectedApps.categoryTokens.map { token in
                    let data = withUnsafeBytes(of: token) { Data($0) }
                    return data.base64EncodedString()
                }

                let inventoryId = "\(childId.rawValue):\(deviceId)"
                let payload = ChildAppInventoryPayload(
                    id: inventoryId,
                    childId: childId,
                    deviceId: deviceId,
                    appTokens: appTokens,
                    categoryTokens: categoryTokens,
                    lastUpdated: Date(),
                    appCount: appTokens.count + categoryTokens.count
                )

                try await syncService.saveAppInventory(payload, familyId: FamilyID("default-family"))

                print("📱 AppEnumerationView: Successfully uploaded \(payload.appCount) apps to CloudKit")

                await MainActor.run {
                    isUploading = false
                    onComplete()
                }
            } catch {
                print("❌ AppEnumerationView: Failed to upload inventory: \(error)")
                await MainActor.run {
                    isUploading = false
                    uploadError = error.localizedDescription
                }
            }
        }
        #else
        onComplete()
        #endif
    }
}
