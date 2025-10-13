import SwiftUI
#if canImport(Core)
import Core
#endif
#if canImport(UIKit)
import UIKit
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
    @EnvironmentObject private var pairingService: PairingService

    @State private var selectedTab: Tab = .apps
    @State private var showingAddChildSheet = false
    @State private var pairedChildId: ChildID?

    private let deviceId: String

    init() {
        let defaults = UserDefaults.standard
        if let storedDeviceId = defaults.string(forKey: "com.claudex.deviceId") {
            self.deviceId = storedDeviceId
        } else {
            #if canImport(UIKit)
            let resolvedId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            #else
            let resolvedId = ProcessInfo.processInfo.globallyUniqueString
            #endif
            self.deviceId = resolvedId
            defaults.set(resolvedId, forKey: "com.claudex.deviceId")
        }
    }

    private var child: ChildProfile? {
        // On child device, only show the paired child
        if let pairedId = pairedChildId {
            return childrenManager.children.first(where: { $0.id == pairedId })
        }

        // Fallback to selected or first child
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
                        AppCategorizationView(hideChildSelector: true)
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

                    Text("Add your first child to start configuring learning apps, points, and rewards.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Button {
                        showingAddChildSheet = true
                    } label: {
                        Label("Add Child", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .navigationTitle("Parent Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if child == nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAddChildSheet = true
                    } label: {
                        Label("Add Child", systemImage: "person.badge.plus")
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button { pinManager.lock() } label: {
                    Label("Lock", systemImage: "lock.fill")
                }
            }
        }
        .sheet(isPresented: $showingAddChildSheet) {
            AddChildSheet { name in
                await childrenManager.addChild(named: name)
            } onSuccess: { newChild in
                childrenManager.selectedChildId = newChild.id
            }
            .environmentObject(childrenManager)
        }
        .onAppear {
            pinManager.updateLastActivity()
            loadPairing()
        }
        .onReceive(pairingService.objectWillChange) { _ in
            loadPairing()
        }
        .onChange(of: selectedTab) { _ in
            pinManager.updateLastActivity()
        }
    }

    private func loadPairing() {
        // Look up which child is paired to this device
        if let pairing = pairingService.getPairing(for: deviceId) {
            pairedChildId = pairing.childId
            childrenManager.selectedChildId = pairing.childId
            print("📱 ChildDeviceParentModeView: Device paired to child \(pairing.childId.rawValue)")
        } else {
            // Fallback: check local pairing storage
            if let data = UserDefaults.standard.data(forKey: PairingService.localPairingDefaultsKey),
               let storedPairing = try? JSONDecoder().decode(ChildDevicePairing.self, from: data),
               storedPairing.deviceId == deviceId {
                pairedChildId = storedPairing.childId
                childrenManager.selectedChildId = storedPairing.childId
                print("📱 ChildDeviceParentModeView: Using local pairing for child \(storedPairing.childId.rawValue)")
            } else {
                print("⚠️ ChildDeviceParentModeView: No pairing found for device \(deviceId)")
            }
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

    private var discoveredLearningApps: [(appId: AppIdentifier, balance: Int, todayPoints: Int)] {
        // Get all apps that have point entries for this child
        let allEntries = childrenManager.ledger.getEntries(childId: child.id, limit: 1000)

        // Group by appId, filter out nil (global entries)
        var appsMap: [AppIdentifier: (balance: Int, todayPoints: Int)] = [:]
        let today = Calendar.current.startOfDay(for: Date())

        for entry in allEntries {
            guard let appId = entry.appId else { continue }

            // Calculate balance
            let currentBalance = appsMap[appId]?.balance ?? 0
            let newBalance = currentBalance + entry.amount

            // Calculate today's points
            let currentToday = appsMap[appId]?.todayPoints ?? 0
            let isToday = Calendar.current.isDate(entry.timestamp, inSameDayAs: today)
            let newToday = currentToday + (isToday && entry.type == .accrual ? entry.amount : 0)

            appsMap[appId] = (balance: newBalance, todayPoints: newToday)
        }

        return appsMap.map { (appId: $0.key, balance: $0.value.balance, todayPoints: $0.value.todayPoints) }
            .sorted { $0.balance > $1.balance }  // Sort by balance descending
    }

    var body: some View {
        List {
            if discoveredLearningApps.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("No Learning Apps Detected Yet")
                                .font(.headline)
                        }

                        Text("Learning apps will appear here automatically when \(child.name) uses them. Points are tracked individually for each app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Divider()
                            .padding(.vertical, 4)

                        Text("How it works:")
                            .font(.caption)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text("1.")
                                    .fontWeight(.medium)
                                Text("Categories classify which apps are for learning")
                            }
                            HStack(alignment: .top) {
                                Text("2.")
                                    .fontWeight(.medium)
                                Text("\(child.name) uses an app (e.g., Khan Academy)")
                            }
                            HStack(alignment: .top) {
                                Text("3.")
                                    .fontWeight(.medium)
                                Text("System detects it → app appears here with balance")
                            }
                            HStack(alignment: .top) {
                                Text("4.")
                                    .fontWeight(.medium)
                                Text("You can then configure rates per individual app")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Section("Discovered Learning Apps") {
                    ForEach(discoveredLearningApps, id: \.appId) { app in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "app.fill")
                                    .foregroundStyle(.green)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("App \(app.appId.rawValue)")
                                        .font(.headline)
                                    Text("Detected through usage")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Total Balance")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(app.balance) pts")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Earned Today")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(app.todayPoints) pts")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Configuration (Coming Soon)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Text("• Points per minute: 10 pts/min (default)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text("• Daily cap: 300 pts (default)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Note") {
                    Text("Per-app configuration controls (adjust rates, set caps) will be added in the next phase. For now, all apps use default settings: 10 pts/min, 300 pts daily cap.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    private var discoveredRewardApps: [(appId: AppIdentifier, timesRedeemed: Int, pointsSpent: Int)] {
        // Get all redemption entries for this child
        let allEntries = childrenManager.ledger.getEntries(childId: child.id, limit: 1000)

        // Group by appId, count redemptions
        var appsMap: [AppIdentifier: (timesRedeemed: Int, pointsSpent: Int)] = [:]

        for entry in allEntries where entry.type == .redemption {
            guard let appId = entry.appId else { continue }

            let current = appsMap[appId] ?? (timesRedeemed: 0, pointsSpent: 0)
            appsMap[appId] = (
                timesRedeemed: current.timesRedeemed + 1,
                pointsSpent: current.pointsSpent + abs(entry.amount)
            )
        }

        return appsMap.map { (appId: $0.key, timesRedeemed: $0.value.timesRedeemed, pointsSpent: $0.value.pointsSpent) }
            .sorted { $0.timesRedeemed > $1.timesRedeemed }  // Sort by usage
    }

    var body: some View {
        List {
            if discoveredRewardApps.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.orange)
                            Text("No Reward Apps Redeemed Yet")
                                .font(.headline)
                        }

                        Text("Reward apps will appear here after \(child.name) redeems points to unlock them. Each app can have custom unlock rules.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Divider()
                            .padding(.vertical, 4)

                        Text("How it works:")
                            .font(.caption)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text("1.")
                                    .fontWeight(.medium)
                                Text("Categories classify which apps need points to unlock")
                            }
                            HStack(alignment: .top) {
                                Text("2.")
                                    .fontWeight(.medium)
                                Text("\(child.name) redeems points (e.g., 100 pts for TikTok)")
                            }
                            HStack(alignment: .top) {
                                Text("3.")
                                    .fontWeight(.medium)
                                Text("System detects it → app appears here")
                            }
                            HStack(alignment: .top) {
                                Text("4.")
                                    .fontWeight(.medium)
                                Text("You can then configure costs per individual app")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Section("Discovered Reward Apps") {
                    ForEach(discoveredRewardApps, id: \.appId) { app in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "app.fill")
                                    .foregroundStyle(.orange)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("App \(app.appId.rawValue)")
                                        .font(.headline)
                                    Text("Detected through redemptions")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Times Unlocked")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(app.timesRedeemed)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Total Points Spent")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(app.pointsSpent) pts")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.orange)
                                }
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Configuration (Coming Soon)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Text("• Cost: 100 pts = 30 minutes (default)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text("• Min/Max: 10-120 minutes (default)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text("• Stacking: Replace (default)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Note") {
                    Text("Per-app redemption controls (adjust costs, min/max times, stacking policies) will be added in the next phase. For now, all apps use default settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
