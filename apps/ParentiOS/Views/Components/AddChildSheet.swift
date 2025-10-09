import SwiftUI
import FamilyControls
#if canImport(Core)
import Core
#endif

@available(iOS 16.0, *)
struct AddChildSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    let onSubmit: (String) async -> Result<ChildProfile, Error>
    let onSuccess: (ChildProfile) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Child name", text: $name)
                    .disabled(isProcessing)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add Child")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isProcessing)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Button("Link") { Task { await handleSubmit() } }
                            .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedName.isEmpty
    }

    private func handleSubmit() async {
        guard canSubmit else { return }
        isProcessing = true
        errorMessage = nil

        let result = await onSubmit(trimmedName)
        switch result {
        case .success(let profile):
            onSuccess(profile)
            dismiss()
        case .failure(let error):
            errorMessage = friendlyMessage(for: error)
        }

        isProcessing = false
    }

    private func friendlyMessage(for error: Error) -> String {
        if let fcError = error as? FamilyControlsError {
            switch fcError {
            case .restricted:
                return "Screen Time settings restrict adding this child." 
            case .authorizationCanceled:
                return "Authorization was canceled."
            case .authorizationConflict:
                return "A conflicting authorization exists. Try again."
            case .invalidAccountType:
                return "Requires an organizer/parent account with Family Sharing."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}

#Preview {
    AddChildSheet { name in
        let profile = ChildProfile(id: ChildID(UUID().uuidString), name: name, storeName: "preview")
        return .success(profile)
    } onSuccess: { _ in }
}
