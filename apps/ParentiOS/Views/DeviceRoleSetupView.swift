import SwiftUI
#if canImport(Core)
import Core
#endif

@available(iOS 16.0, *)
struct DeviceRoleSetupView: View {
    @EnvironmentObject private var deviceRoleManager: DeviceRoleManager
    @EnvironmentObject private var childrenManager: ChildrenManager

    @State private var showingChildSelector = false
    @State private var isSettingRole = false
    @State private var isRefreshingChildren = false
    @State private var selectedChildId: ChildID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerSection

                if deviceRoleManager.isLoading || isSettingRole || isRefreshingChildren {
                    ProgressView(isRefreshingChildren ? "Loading child profiles..." : "Preparing...")
                }

                roleButtons

                if let errorMessage = deviceRoleManager.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Set Up Device")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await refreshChildrenIfNeeded()
            await deviceRoleManager.loadDeviceRole()
        }
        .sheet(isPresented: $showingChildSelector) {
            childSelector
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Who uses this device?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose whether this device is for a parent/guardian or for your child. We’ll tailor the experience and security based on this choice.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var roleButtons: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    await handleChildDeviceSelection()
                }
            } label: {
                RoleButtonContent(
                    title: "This is my child's device",
                    subtitle: "Shows both Parent Mode and Child Mode (with PIN protection)",
                    systemImage: "iphone"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(deviceRoleManager.isLoading || isSettingRole || isRefreshingChildren)

            Button {
                Task {
                    await setRole(.parent, childId: nil)
                }
            } label: {
                RoleButtonContent(
                    title: "This is my device (parent)",
                    subtitle: "Monitoring dashboard only; Child Mode hidden",
                    systemImage: "person.crop.circle"
                )
            }
            .buttonStyle(.bordered)
            .disabled(deviceRoleManager.isLoading || isSettingRole || isRefreshingChildren)
        }
    }

    private var childSelector: some View {
        NavigationStack {
            List {
                ForEach(Array(childrenManager.children.enumerated()), id: \.offset) { _, child in
                    Button {
                        selectedChildId = child.id
                        Task {
                            await setRole(.child, childId: child.id)
                        }
                        showingChildSelector = false
                    } label: {
                        HStack {
                            Text(child.name)
                            Spacer()
                            if selectedChildId == child.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Child")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingChildSelector = false
                    }
                }
            }
        }
    }

    private func setRole(_ role: DeviceRole, childId: ChildID?) async {
        isSettingRole = true
        defer { isSettingRole = false }
        await deviceRoleManager.setDeviceRole(role, childId: childId)
    }

    @MainActor
    private func handleChildDeviceSelection() async {
        deviceRoleManager.errorMessage = nil
        if childrenManager.children.isEmpty {
            await refreshChildren()
        }

        if childrenManager.children.isEmpty {
            deviceRoleManager.errorMessage = "Add a child profile in Parent Mode before configuring a child device."
        } else {
            showingChildSelector = true
        }
    }

    @MainActor
    private func refreshChildrenIfNeeded() async {
        if childrenManager.children.isEmpty {
            await refreshChildren()
        }
    }

    @MainActor
    private func refreshChildren() async {
        guard !isRefreshingChildren else { return }
        isRefreshingChildren = true
        defer { isRefreshingChildren = false }
        await childrenManager.refreshChildrenFromCloud(familyId: FamilyID("default-family"))
    }
}

@available(iOS 16.0, *)
private struct RoleButtonContent: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: systemImage)
                    .font(.title3)
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

@available(iOS 16.0, *)
#Preview {
    RoleButtonContent(
        title: "This is my child's device",
        subtitle: "Shows both modes",
        systemImage: "iphone"
    )
    .padding()
}
