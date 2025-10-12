import SwiftUI
#if canImport(Core)
import Core
#endif
#if canImport(ScreenTimeService)
import ScreenTimeService
#endif

@available(iOS 16.0, *)
struct ParentDeviceParentModeView: View {
    @EnvironmentObject private var authorizationCoordinator: ScreenTimeAuthorizationCoordinator
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var pairingService: PairingService
    @EnvironmentObject private var pinManager: PINManager

    @State private var selectedChildIndex: Int = 0
    @State private var showingPairingSheet = false
    @State private var pairingNotification: PairingNotification?
    @State private var showPairingSuccess = false

    private var children: [ChildProfile] { childrenManager.children }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                AuthorizationStatusBanner(state: authorizationCoordinator.state) {
                    Task { await authorizationCoordinator.requestAuthorization() }
                }
                .padding(.horizontal)

                if children.isEmpty {
                    noChildrenView
                } else {
                    TabView(selection: $selectedChildIndex) {
                        ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                            ChildDashboardTab(child: child)
                                .environmentObject(childrenManager)
                                .tag(index)
                                .tabItem {
                                    Label(child.name, systemImage: "person.circle")
                                }
                        }

                        AccountTabView()
                            .tabItem { Label("Account", systemImage: "gear") }
                            .tag(children.count)
                    }
                }
            }
            .navigationTitle("Family Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingPairingSheet = true
                    } label: {
                        Label("Link Device", systemImage: "qrcode")
                    }
                    .disabled(children.isEmpty)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        pinManager.lock()
                    } label: {
                        Label("Lock", systemImage: "lock.fill")
                    }
                }
            }
        }
        .onAppear {
            selectedChildIndex = min(childrenManager.selectedChildIndex, max(children.count - 1, 0))
            if let child = selectedChild {
                childrenManager.selectedChildId = child.id
            }
        }
        .onChange(of: selectedChildIndex) { newValue in
            if children.indices.contains(newValue) {
                childrenManager.selectedChildId = children[newValue].id
            }
        }
        .onChange(of: children.count) { _ in
            selectedChildIndex = min(selectedChildIndex, max(children.count - 1, 0))
            if let child = selectedChild {
                childrenManager.selectedChildId = child.id
            }
        }
        .sheet(isPresented: $showingPairingSheet) {
            if let child = selectedChild {
                PairingCodeView(
                    childId: child.id,
                    childDisplayName: child.name,
                    onDismiss: { showingPairingSheet = false }
                )
                .environmentObject(pairingService)
            }
        }
        .onReceive(pairingService.$lastPairingNotification) { notification in
            if let notification {
                pairingNotification = notification
                showPairingSuccess = true
            }
        }
        .alert("Device Paired!", isPresented: $showPairingSuccess) {
            Button("OK") {
                showPairingSuccess = false
                pairingNotification = nil
            }
        } message: {
            if let notification = pairingNotification {
                let childName = children.first(where: { $0.id == notification.childId })?.name ?? "Unknown Child"
                Text("Successfully paired device \"\(notification.deviceName)\" to \(childName)")
            } else {
                Text("Device successfully paired!")
            }
        }
    }

    private var selectedChild: ChildProfile? {
        guard children.indices.contains(selectedChildIndex) else { return children.first }
        return children[selectedChildIndex]
    }

    @ViewBuilder
    private var noChildrenView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            Text("No children yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Use the \"Link Device\" button to generate a pairing code, then link the child’s device to start configuring rules.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                showingPairingSheet = true
            } label: {
                Label("Link Child Device", systemImage: "qrcode")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

@available(iOS 16.0, *)
private struct ChildDashboardTab: View {
    let child: ChildProfile
    @EnvironmentObject private var childrenManager: ChildrenManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DashboardCard(title: "Total Points") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(aggregatedPoints) pts")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Lifetime balance")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                DashboardCard(title: "Recent Activity") {
                    let recentEntries = childrenManager.ledger.getEntries(childId: child.id, limit: 5)

                    if recentEntries.isEmpty {
                        Text("No point activity yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(recentEntries, id: \.id) { entry in
                                HStack {
                                    Text(entry.type == .accrual ? "Earned" : entry.type == .redemption ? "Redeemed" : "Adjusted")
                                    Spacer()
                                    Text("\(entry.amount) pts")
                                        .foregroundStyle(entry.amount >= 0 ? .green : .red)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }

                DashboardCard(title: "Next Steps", systemImage: "lightbulb") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Configure learning & reward apps", systemImage: "square.and.pencil")
                        Label("Review redemption history", systemImage: "clock.arrow.circlepath")
                        Label("Adjust points rules", systemImage: "slider.horizontal.3")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                NavigationLink {
                    ChildDeviceParentModeView()
                        .environmentObject(childrenManager)
                } label: {
                    Label("Configure \(child.name)'s Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    childrenManager.selectedChildId = child.id
                })
                .padding(.horizontal)
            }
            .padding()
        }
    }

    private var aggregatedPoints: Int {
        childrenManager.ledger.getBalance(childId: child.id)
    }
}

@available(iOS 16.0, *)
private struct AccountTabView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Account & Subscription")
                .font(.headline)
            Text("Subscription management and family account settings will appear here in a future release.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
