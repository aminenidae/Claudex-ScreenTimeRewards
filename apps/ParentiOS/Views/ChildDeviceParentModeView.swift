import SwiftUI
#if canImport(Core)
import Core
#endif

/// Parent Mode view on child's device
/// PIN-protected configuration interface where parents can:
/// - Categorize apps (Learning vs Reward) using local tokens
/// - Configure points accrual settings
/// - Set redemption rules
/// - Manage Parent Mode settings
@available(iOS 16.0, *)
struct ChildDeviceParentModeView: View {
    enum Tab: Hashable { case apps, points, rewards, settings }

    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var rulesManager: CategoryRulesManager
    @EnvironmentObject private var pinManager: PINManager
    @EnvironmentObject private var learningCoordinator: LearningSessionCoordinator
    @EnvironmentObject private var rewardCoordinator: RewardCoordinator

    @State private var selectedTab: Tab = .apps

    private var child: ChildProfile? {
        if let id = childrenManager.selectedChildId {
            return childrenManager.children.first(where: { $0.id == id })
        }
        return childrenManager.children.first
    }

    var body: some View {
        NavigationStack {
            if let child {
                VStack(spacing: 16) {
                    HeaderView(child: child)

                    TabView(selection: $selectedTab) {
                        AppCategorizationView()
                            .tag(Tab.apps)
                            .tabItem { Label("Apps", systemImage: "square.grid.2x2") }

                        PerAppPointsConfigurationView(child: child)
                            .tag(Tab.points)
                            .tabItem { Label("Points", systemImage: "star.fill") }

                        PerAppRewardsConfigurationView(child: child)
                            .tag(Tab.rewards)
                            .tabItem { Label("Rewards", systemImage: "gift.fill") }

                        ParentModeSettingsView()
                            .tag(Tab.settings)
                            .tabItem { Label("Settings", systemImage: "gear") }
                    }
                }
                .padding(.top)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 72))
                        .foregroundStyle(.secondary)

                    Text("No Child Selected")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Select a child from the parent dashboard to configure their rules, or pair a device to create a new profile.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Parent Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { pinManager.lock() } label: {
                    Label("Lock", systemImage: "lock.fill")
                }
            }
        }
        .onAppear {
            pinManager.updateLastActivity()
            if childrenManager.selectedChildId == nil, let child {
                childrenManager.selectedChildId = child.id
            }
        }
        .onChange(of: selectedTab) { _ in
            pinManager.updateLastActivity()
        }
    }

    @ViewBuilder
    private func HeaderView(child: ChildProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(child.name)
                .font(.title2)
                .fontWeight(.semibold)
            Text("Configure learning apps, points, rewards, and settings for this child.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

// MARK: - Points Configuration View

@available(iOS 16.0, *)
struct PerAppPointsConfigurationView: View {
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var pinManager: PINManager
    let child: ChildProfile

    var body: some View {
        List {
            Section("Per-App Point Rates") {
                Text("Per-app point configuration will live here. Phase 3 will surface each learning app with adjustable points-per-minute and daily caps once the per-app ledger lands.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Coming Soon") {
                Text("• List each learning app with current point rate\n• Allow parents to adjust rate and daily cap per app\n• Show when the child hits the reward cap for the day")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Current Defaults") {
                Text("Points accrue using the global settings until per-app controls are implemented.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Points")
        .onAppear { pinManager.updateLastActivity() }
    }
}

// MARK: - Redemption Rules View

@available(iOS 16.0, *)
struct PerAppRewardsConfigurationView: View {
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var pinManager: PINManager
    let child: ChildProfile

    var body: some View {
        List {
            Section("Per-App Reward Rules") {
                Text("Future work will list each reward app, allowing parents to set points required, partial redemption thresholds, and stacking policies.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Coming Soon") {
                Text("• Configure conversion rates per reward app\n• Support partial vs. full unlocks\n• Manage stacking/queueing policies")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Current Behaviour") {
                Text("Global redemption settings remain in effect until per-app controls are implemented.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Rewards")
        .onAppear { pinManager.updateLastActivity() }
    }
}

// MARK: - Parent Mode Settings View

@available(iOS 16.0, *)
struct ParentModeSettingsView: View {
    @EnvironmentObject private var pinManager: PINManager
    @EnvironmentObject private var childrenManager: ChildrenManager
    @State private var showingChangePIN = false
    @State private var showingRemovePINConfirmation = false
    @State private var showingCleanupConfirmation = false
    @State private var cleanupInProgress = false
    @State private var cleanupError: String?

    var body: some View {
        Form {
            Section("Parent Mode") {
                Button(action: { showingChangePIN = true }) {
                    Label("Change PIN", systemImage: "lock.rotation")
                }

                Button(role: .destructive, action: { showingRemovePINConfirmation = true }) {
                    Label("Remove PIN", systemImage: "lock.slash")
                }
            }

            Section {
                Button(action: { showingCleanupConfirmation = true }) {
                    if cleanupInProgress {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Cleaning up...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label("Clean Up Duplicate Children", systemImage: "trash")
                    }
                }
                .disabled(cleanupInProgress)

                if let error = cleanupError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("CloudKit Maintenance")
            } footer: {
                Text("Remove duplicate child profiles from CloudKit. This will keep only one profile per child name.")
                    .font(.caption)
            }

            Section("About") {
                HStack {
                    Text("Device Role")
                    Spacer()
                    Text("Child Device")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Configuration")
                    Spacer()
                    Text("Local + CloudKit Sync")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Parent Mode on this device allows you to configure app categories and rules. Changes sync automatically to monitoring dashboards on parent devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingChangePIN) {
            PINSetupView()
                .environmentObject(pinManager)
        }
        .alert("Remove PIN?", isPresented: $showingRemovePINConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                do {
                    try pinManager.removePIN()
                } catch {
                    print("Error removing PIN: \(error)")
                }
            }
        } message: {
            Text("Are you sure you want to remove the PIN? Parent Mode will no longer be protected on this device.")
        }
        .alert("Clean Up Duplicates?", isPresented: $showingCleanupConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean Up", role: .destructive) {
                cleanupDuplicates()
            }
        } message: {
            Text("This will delete all duplicate child profiles from CloudKit, keeping only one of each name. This action cannot be undone.")
        }
        .onAppear {
            pinManager.updateLastActivity()
        }
    }

    private func cleanupDuplicates() {
        cleanupInProgress = true
        cleanupError = nil

        Task {
            do {
                try await childrenManager.cleanupDuplicateChildrenInCloud(familyId: FamilyID("default-family"))
                await MainActor.run {
                    cleanupInProgress = false
                }
            } catch {
                await MainActor.run {
                    cleanupInProgress = false
                    cleanupError = "Cleanup failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let ledger = PointsLedger()
    let engine = PointsEngine()
    let rulesManager = CategoryRulesManager()
    
    ChildDeviceParentModeView()
        .environmentObject(ChildrenManager(ledger: ledger, engine: engine, exemptionManager: ExemptionManager(), redemptionService: RedemptionService(ledger: ledger)))
        .environmentObject(rulesManager)
        .environmentObject(PINManager())
        .environmentObject(LearningSessionCoordinator(rulesManager: rulesManager, pointsEngine: engine, pointsLedger: ledger))
        .environmentObject(RewardCoordinator())
}
