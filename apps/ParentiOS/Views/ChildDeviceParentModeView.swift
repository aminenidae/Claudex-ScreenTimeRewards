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
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var rulesManager: CategoryRulesManager
    @EnvironmentObject private var pinManager: PINManager
    @EnvironmentObject private var learningCoordinator: LearningSessionCoordinator
    @EnvironmentObject private var rewardCoordinator: RewardCoordinator

    var body: some View {
        NavigationStack {
            TabView {
                // Tab 1: App Categorization (uses local tokens!)
                AppCategorizationView()
                    .tabItem {
                        Label("Apps", systemImage: "square.grid.2x2")
                    }

                // Tab 2: Points Configuration
                PointsConfigurationView()
                    .tabItem {
                        Label("Points", systemImage: "star.fill")
                    }

                // Tab 3: Redemption Rules
                RedemptionRulesView()
                    .tabItem {
                        Label("Rewards", systemImage: "gift.fill")
                    }

                // Tab 4: Parent Mode Settings
                ParentModeSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .navigationTitle("Parent Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        pinManager.lock()
                    }) {
                        Label("Lock", systemImage: "lock.fill")
                    }
                }
            }
            .onAppear {
                pinManager.updateLastActivity()
            }
        }
    }
}

// MARK: - Points Configuration View

@available(iOS 16.0, *)
struct PointsConfigurationView: View {
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var pinManager: PINManager

    @State private var pointsPerMinute: Int = 10
    @State private var dailyCapPoints: Int = 600
    @State private var idleTimeoutMinutes: Int = 3
    @State private var showingSaveConfirmation = false

    var body: some View {
        Form {
            Section {
                Text("Configure how children earn points for using learning apps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Point Accrual") {
                Stepper("Points per minute: \(pointsPerMinute)", value: $pointsPerMinute, in: 1...50)

                Stepper("Daily cap: \(dailyCapPoints) points", value: $dailyCapPoints, in: 100...2000, step: 50)

                Picker("Idle timeout", selection: $idleTimeoutMinutes) {
                    Text("1 minute").tag(1)
                    Text("3 minutes").tag(3)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                }
            }

            Section("Preview") {
                HStack {
                    Text("1 hour of learning earns")
                    Spacer()
                    Text("\(pointsPerMinute * 60) points")
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Daily cap reached after")
                    Spacer()
                    Text("\(dailyCapPoints / pointsPerMinute) minutes")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Points stop accruing after \(idleTimeoutMinutes) minute\(idleTimeoutMinutes == 1 ? "" : "s") of inactivity")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button("Save Configuration") {
                saveConfiguration()
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Points Configuration")
        .alert("Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Points configuration has been saved and will sync to other devices")
        }
        .onAppear {
            pinManager.updateLastActivity()
            loadConfiguration()
        }
    }

    private func loadConfiguration() {
        // TODO: Load from CloudKit or local storage
        // For now, use defaults from PointsConfiguration
        let defaultConfig = PointsConfiguration.default
        pointsPerMinute = defaultConfig.pointsPerMinute
        dailyCapPoints = defaultConfig.dailyCapPoints
        idleTimeoutMinutes = Int(defaultConfig.idleTimeoutSeconds / 60)
    }

    private func saveConfiguration() {
        // TODO: Save to CloudKit
        let config = PointsConfiguration(
            pointsPerMinute: pointsPerMinute,
            dailyCapPoints: dailyCapPoints,
            idleTimeoutSeconds: TimeInterval(idleTimeoutMinutes * 60)
        )

        print("⚙️ PointsConfigurationView: Saving config: \(config)")
        // TODO: Sync to CloudKit

        showingSaveConfirmation = true
        pinManager.updateLastActivity()
    }
}

// MARK: - Redemption Rules View

@available(iOS 16.0, *)
struct RedemptionRulesView: View {
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var pinManager: PINManager

    @State private var pointsPerMinute: Int = 10
    @State private var minRedemptionPoints: Int = 30
    @State private var maxRedemptionPoints: Int = 600
    @State private var stackingPolicy: ExemptionStackingPolicy = .extend
    @State private var showingSaveConfirmation = false

    var body: some View {
        Form {
            Section {
                Text("Configure how children convert points into reward time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Redemption Rates") {
                Stepper("Points per minute: \(pointsPerMinute)", value: $pointsPerMinute, in: 1...50)

                Stepper("Minimum: \(minRedemptionPoints) points", value: $minRedemptionPoints, in: 10...100, step: 10)

                Stepper("Maximum: \(maxRedemptionPoints) points", value: $maxRedemptionPoints, in: 100...1000, step: 50)
            }

            Section("Stacking Policy") {
                Picker("When redeeming during active time", selection: $stackingPolicy) {
                    Text("Replace current time").tag(ExemptionStackingPolicy.replace)
                    Text("Extend current time").tag(ExemptionStackingPolicy.extend)
                    Text("Queue for later").tag(ExemptionStackingPolicy.queue)
                    Text("Block until expired").tag(ExemptionStackingPolicy.block)
                }
            }

            Section("Preview") {
                HStack {
                    Text("\(minRedemptionPoints) points")
                    Spacer()
                    Text("\(minRedemptionPoints / pointsPerMinute) minutes")
                        .foregroundStyle(.green)
                }

                HStack {
                    Text("\(maxRedemptionPoints) points")
                    Spacer()
                    Text("\(maxRedemptionPoints / pointsPerMinute) minutes")
                        .foregroundStyle(.green)
                }
            }

            Button("Save Configuration") {
                saveConfiguration()
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Redemption Rules")
        .alert("Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Redemption configuration has been saved and will sync to other devices")
        }
        .onAppear {
            pinManager.updateLastActivity()
            loadConfiguration()
        }
    }

    private func loadConfiguration() {
        // TODO: Load from CloudKit or local storage
        let defaultConfig = RedemptionConfiguration.default
        pointsPerMinute = defaultConfig.pointsPerMinute
        minRedemptionPoints = defaultConfig.minRedemptionPoints
        maxRedemptionPoints = defaultConfig.maxRedemptionPoints
        // stackingPolicy = .extend // Default
    }

    private func saveConfiguration() {
        // TODO: Save to CloudKit
        let config = RedemptionConfiguration(
            pointsPerMinute: pointsPerMinute,
            minRedemptionPoints: minRedemptionPoints,
            maxRedemptionPoints: maxRedemptionPoints,
            maxTotalMinutes: 120 // Default
        )

        print("⚙️ RedemptionRulesView: Saving config: \(config)")
        // TODO: Sync to CloudKit

        showingSaveConfirmation = true
        pinManager.updateLastActivity()
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
