
import SwiftUI
#if canImport(Core)
import Core
#endif

@available(iOS 16.0, *)
struct ManageChildrenView: View {
    @ObservedObject var childrenManager: ChildrenManager
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            List {
                ForEach(childrenManager.children) { child in
                    Text(child.name)
                }
                .onDelete(perform: deleteChild)
            }
            .navigationTitle("Manage Children")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        }
    }

    private func deleteChild(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let child = childrenManager.children[index]
                await childrenManager.removeChild(child)
            }
        }
    }
}
