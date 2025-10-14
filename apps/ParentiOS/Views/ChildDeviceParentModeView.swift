import SwiftUI
#if canImport(Core)
import Core
#endif
#if canImport(ScreenTimeService)
import ScreenTimeService
#endif
#if canImport(FamilyControls)
import FamilyControls
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(ManagedSettings)
import ManagedSettings
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
    @EnvironmentObject private var perAppStore: PerAppConfigurationStore
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

                        PerAppPointsConfigurationView(child: child, deviceId: deviceId)
                            .tag(Tab.points)
                            .tabItem { Label("Points", systemImage: "star.fill") }

                        PerAppRewardsConfigurationView(child: child, deviceId: deviceId)
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
    @EnvironmentObject private var rulesManager: CategoryRulesManager
    @EnvironmentObject private var perAppStore: PerAppConfigurationStore
    @EnvironmentObject private var pinManager: PINManager
    let child: ChildProfile
    let deviceId: String

    private let calendar = Calendar.current
    @State private var showingInventorySync = false

    private var learningMetrics: [AppIdentifier: (balance: Int, todayPoints: Int)] {
        var metrics: [AppIdentifier: (balance: Int, todayPoints: Int)] = [:]
        let entries = childrenManager.ledger.getEntries(childId: child.id, limit: 1000)
        for entry in entries {
            guard let appId = entry.appId else { continue }
            var current = metrics[appId] ?? (balance: 0, todayPoints: 0)
            current.balance += entry.amount
            if calendar.isDate(entry.timestamp, inSameDayAs: Date()), entry.type == .accrual {
                current.todayPoints += entry.amount
            }
            metrics[appId] = current
        }
        return metrics
    }

    private var learningAppIds: [AppIdentifier] {
        var identifiers = Set<AppIdentifier>()

        #if canImport(FamilyControls)
        let rules = rulesManager.getRules(for: child.id)
        for token in rules.learningSelection.applicationTokens {
            let data = withUnsafeBytes(of: token) { Data($0) }
            let hex = data.map { String(format: "%02x", $0) }.joined()
            identifiers.insert(AppIdentifier("app-\(hex)"))
        }
        #endif

        identifiers.formUnion(learningMetrics.keys)
        identifiers.formUnion(perAppStore.pointsAppIdentifiers(for: child.id))

        return identifiers.sorted { $0.rawValue < $1.rawValue }
    }

    private var learningAppNames: [AppIdentifier: String] {
        var names: [AppIdentifier: String] = [:]
        #if canImport(FamilyControls)
        for (appId, metadata) in rulesManager.appMetadata(for: child.id) {
            names[appId] = metadata.name
        }
        #endif
        for appId in learningAppIds {
            if let stored = perAppStore.displayName(childId: child.id, appId: appId) {
                names[appId] = stored
            }
        }
        return names
    }

    private var needsInventorySync: Bool {
        learningAppIds.contains { perAppStore.displayName(childId: child.id, appId: $0) == nil }
    }

    var body: some View {
        List {
            if needsInventorySync {
                Section {
                    Button("Sync App Info") {
                        showingInventorySync = true
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                } footer: {
                    Text("Run once to capture app names and icons from this device. Takes under a minute.")
                        .font(.caption)
                }
            }

            if learningAppIds.isEmpty {
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
                Section("Learning Apps") {
                    ForEach(learningAppIds, id: \.self) { appId in
                        let metrics = learningMetrics[appId] ?? (balance: 0, todayPoints: 0)
                        let displayName = learningAppNames[appId] ?? friendlyName(for: appId)
                        let iconData = perAppStore.iconData(childId: child.id, appId: appId)

                        PerAppPointsEditorRow(
                            appId: appId,
                            displayName: displayName,
                            iconData: iconData,
                            metrics: metrics,
                            isUsingDefault: perAppStore.isUsingDefaultPointsRule(childId: child.id, appId: appId),
                            pointsPerMinute: Binding(
                                get: { perAppStore.pointsRule(for: child.id, appId: appId).pointsPerMinute },
                                set: { newValue in
                                    pinManager.updateLastActivity()
                                    perAppStore.updatePointsRule(childId: child.id, appId: appId) { rule in
                                        rule.pointsPerMinute = newValue
                                    }
                                }
                            ),
                            dailyCapPoints: Binding(
                                get: { perAppStore.pointsRule(for: child.id, appId: appId).dailyCapPoints },
                                set: { newValue in
                                    pinManager.updateLastActivity()
                                    perAppStore.updatePointsRule(childId: child.id, appId: appId) { rule in
                                        rule.dailyCapPoints = newValue
                                    }
                                }
                            ),
                            onReset: {
                                pinManager.updateLastActivity()
                                perAppStore.resetPointsRule(childId: child.id, appId: appId)
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Points")
        .onAppear { pinManager.updateLastActivity() }
        .sheet(isPresented: $showingInventorySync) {
            NavigationStack {
                AppEnumerationView(
                    childId: child.id,
                    deviceId: deviceId,
                    onComplete: { showingInventorySync = false }
                )
            }
        }
    }
}

@available(iOS 16.0, *)
private struct PerAppPointsEditorRow: View {
    let appId: AppIdentifier
    let displayName: String
    let iconData: Data?
    let metrics: (balance: Int, todayPoints: Int)
    let isUsingDefault: Bool
    let pointsPerMinute: Binding<Int>
    let dailyCapPoints: Binding<Int>
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                #if canImport(UIKit)
                if let iconData, let image = UIImage(data: iconData) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .cornerRadius(6)
                } else {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.green)
                }
                #else
                Image(systemName: "app.fill")
                    .foregroundStyle(.green)
                #endif
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                    Text(isUsingDefault ? "Using default settings" : "Custom settings applied")
                        .font(.caption)
                        .foregroundStyle(isUsingDefault ? .secondary : .primary)
                }
                Spacer()
                Button("Reset") {
                    onReset()
                }
                .buttonStyle(.bordered)
                .disabled(isUsingDefault)
            }

            HStack(spacing: 20) {
                MetricView(title: "Balance", value: "\(metrics.balance) pts")
                MetricView(title: "Today", value: "\(metrics.todayPoints) pts", color: .green)
            }

            VStack(alignment: .leading, spacing: 8) {
                Stepper(value: pointsPerMinute, in: 1...60) {
                    Text("Points per minute: \(pointsPerMinute.wrappedValue) pts")
                }

                Stepper(value: dailyCapPoints, in: 50...2400, step: 10) {
                    Text("Daily cap: \(dailyCapPoints.wrappedValue) pts")
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }

    private struct MetricView: View {
        let title: String
        let value: String
        var color: Color = .primary

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
        }
    }
}

// MARK: - Redemption Rules View

@available(iOS 16.0, *)
struct PerAppRewardsConfigurationView: View {
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var rulesManager: CategoryRulesManager
    @EnvironmentObject private var perAppStore: PerAppConfigurationStore
    @EnvironmentObject private var pinManager: PINManager
    let child: ChildProfile
    let deviceId: String

    @State private var showingInventorySync = false

    private var rewardUsageMap: [AppIdentifier: RewardUsage] {
        perAppStore.rewardUsageMap(for: child.id)
    }

    private var rewardAppIds: [AppIdentifier] {
        var identifiers = Set<AppIdentifier>()

        #if canImport(FamilyControls)
        let rules = rulesManager.getRules(for: child.id)
        for token in rules.rewardSelection.applicationTokens {
            let data = withUnsafeBytes(of: token) { Data($0) }
            let hex = data.map { String(format: "%02x", $0) }.joined()
            identifiers.insert(AppIdentifier("app-\(hex)"))
        }
        #endif

        identifiers.formUnion(rewardUsageMap.keys)
        identifiers.formUnion(perAppStore.rewardAppIdentifiers(for: child.id))

        return identifiers.sorted { $0.rawValue < $1.rawValue }
    }

    private var rewardAppNames: [AppIdentifier: String] {
        var names: [AppIdentifier: String] = [:]
        #if canImport(FamilyControls)
        for (appId, metadata) in rulesManager.appMetadata(for: child.id) {
            names[appId] = metadata.name
        }
        #endif
        for appId in rewardAppIds {
            if let stored = perAppStore.displayName(childId: child.id, appId: appId) {
                names[appId] = stored
            }
        }
        return names
    }

    private var needsInventorySync: Bool {
        rewardAppIds.contains { perAppStore.displayName(childId: child.id, appId: $0) == nil }
    }

    var body: some View {
        List {
            if rewardAppIds.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.orange)
                            Text("No Reward Apps Configured Yet")
                                .font(.headline)
                        }

                        Text("Select reward apps in the Apps tab or wait for \(child.name) to redeem points. Each app will appear here with customisable unlock rules.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Divider()
                            .padding(.vertical, 4)

                        Text("Tips:")
                            .font(.caption)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Use categories (Games, Entertainment) to auto-populate apps.")
                            Text("• Configure cost, minimum, and maximum redemption per app.")
                            Text("• Choose how new unlock time combines with existing time.")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            } else {
                if needsInventorySync {
                    Section {
                        Button("Sync App Info") {
                            showingInventorySync = true
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                    } footer: {
                        Text("Sync once to capture reward app names/icons from this device.")
                            .font(.caption)
                    }
                }

                Section("Reward Apps") {
                    ForEach(rewardAppIds, id: \.self) { appId in
                        let usage = rewardUsageMap[appId] ?? RewardUsage()
                        let displayName = rewardAppNames[appId] ?? friendlyName(for: appId)
                        let iconData = perAppStore.iconData(childId: child.id, appId: appId)

                        PerAppRewardEditorRow(
                            appId: appId,
                            displayName: displayName,
                            iconData: iconData,
                            metrics: (usage.timesRedeemed, usage.pointsSpent),
                            isUsingDefault: perAppStore.isUsingDefaultRewardRule(childId: child.id, appId: appId),
                            pointsPerMinute: Binding(
                                get: { perAppStore.rewardRule(for: child.id, appId: appId).pointsPerMinute },
                                set: { newValue in
                                    pinManager.updateLastActivity()
                                    perAppStore.updateRewardRule(childId: child.id, appId: appId) { rule in
                                        rule.pointsPerMinute = newValue
                                    }
                                }
                            ),
                            minPoints: Binding(
                                get: { perAppStore.rewardRule(for: child.id, appId: appId).minRedemptionPoints },
                                set: { newValue in
                                    pinManager.updateLastActivity()
                                    perAppStore.updateRewardRule(childId: child.id, appId: appId) { rule in
                                        rule.minRedemptionPoints = newValue
                                    }
                                }
                            ),
                            maxPoints: Binding(
                                get: { perAppStore.rewardRule(for: child.id, appId: appId).maxRedemptionPoints },
                                set: { newValue in
                                    pinManager.updateLastActivity()
                                    perAppStore.updateRewardRule(childId: child.id, appId: appId) { rule in
                                        rule.maxRedemptionPoints = newValue
                                    }
                                }
                            ),
                            stackingPolicy: Binding(
                                get: { perAppStore.rewardRule(for: child.id, appId: appId).stackingPolicy },
                                set: { newValue in
                                    pinManager.updateLastActivity()
                                    perAppStore.updateRewardRule(childId: child.id, appId: appId) { rule in
                                        rule.stackingPolicy = newValue
                                    }
                                }
                            ),
                            onReset: {
                                pinManager.updateLastActivity()
                                perAppStore.resetRewardRule(childId: child.id, appId: appId)
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Rewards")
        .onAppear { pinManager.updateLastActivity() }
        .sheet(isPresented: $showingInventorySync) {
            NavigationStack {
                AppEnumerationView(
                    childId: child.id,
                    deviceId: deviceId,
                    onComplete: { showingInventorySync = false }
                )
            }
        }
    }
}

@available(iOS 16.0, *)
private struct PerAppRewardEditorRow: View {
    let appId: AppIdentifier
    let displayName: String
    let iconData: Data?
    let metrics: (timesRedeemed: Int, pointsSpent: Int)
    let isUsingDefault: Bool
    let pointsPerMinute: Binding<Int>
    let minPoints: Binding<Int>
    let maxPoints: Binding<Int>
    let stackingPolicy: Binding<ExemptionStackingPolicy>
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                #if canImport(UIKit)
                if let iconData, let image = UIImage(data: iconData) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .cornerRadius(6)
                } else {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.orange)
                }
                #else
                Image(systemName: "app.fill")
                    .foregroundStyle(.orange)
                #endif
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                    Text(isUsingDefault ? "Using default settings" : "Custom settings applied")
                        .font(.caption)
                        .foregroundStyle(isUsingDefault ? .secondary : .primary)
                }
                Spacer()
                Button("Reset") {
                    onReset()
                }
                .buttonStyle(.bordered)
                .disabled(isUsingDefault)
            }

            HStack(spacing: 20) {
                MetricView(title: "Times Unlocked", value: "\(metrics.timesRedeemed)")
                MetricView(title: "Points Spent", value: "\(metrics.pointsSpent) pts", color: .orange)
            }

            VStack(alignment: .leading, spacing: 8) {
                Stepper(value: pointsPerMinute, in: 5...300, step: 5) {
                    Text("Cost: \(pointsPerMinute.wrappedValue) pts per minute")
                }

                Stepper(value: minPoints, in: 10...600, step: 10) {
                    Text("Minimum redemption: \(minPoints.wrappedValue) pts")
                }

                Stepper(value: maxPoints, in: 50...2000, step: 10) {
                    Text("Maximum redemption: \(maxPoints.wrappedValue) pts")
                }

                Picker("Stacking", selection: stackingPolicy) {
                    Text("Replace current time").tag(ExemptionStackingPolicy.replace)
                    Text("Extend current time").tag(ExemptionStackingPolicy.extend)
                    Text("Queue after current time").tag(ExemptionStackingPolicy.queue)
                    Text("Block until expired").tag(ExemptionStackingPolicy.block)
                }
                .pickerStyle(.menu)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }

    private struct MetricView: View {
        let title: String
        let value: String
        var color: Color = .primary

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
        }
    }
}

#if canImport(FamilyControls)
private func friendlyName(for appId: AppIdentifier) -> String {
    if let suffix = appId.rawValue.split(separator: "-").last {
        return "App \(suffix.prefix(6))"
    }
    return appId.rawValue
}
#else
private func friendlyName(for appId: AppIdentifier) -> String { appId.rawValue }
#endif

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
    let perAppStore = PerAppConfigurationStore()
    
    let redemptionService = RedemptionService(ledger: ledger) { childId, appId, points in
        perAppStore.recordRewardRedemption(childId: childId, appId: appId, pointsSpent: points)
    }

    let childrenManager = ChildrenManager(
        ledger: ledger,
        engine: engine,
        exemptionManager: ExemptionManager(),
        redemptionService: redemptionService
    )

    let rewardCoordinator: RewardCoordinator = {
        #if canImport(ScreenTimeService)
        return RewardCoordinator(
            rulesManager: rulesManager,
            redemptionService: redemptionService,
            shieldController: ShieldController(),
            exemptionManager: ExemptionManager(),
            perAppStore: perAppStore
        )
        #else
        return RewardCoordinator()
        #endif
    }()

    rulesManager.setPerAppStore(perAppStore)

    return ChildDeviceParentModeView()
        .environmentObject(childrenManager)
        .environmentObject(rulesManager)
        .environmentObject(perAppStore)
        .environmentObject(PINManager())
        .environmentObject(LearningSessionCoordinator(rulesManager: rulesManager, pointsEngine: engine, pointsLedger: ledger, configurationProvider: { childId, appId in
            perAppStore.pointsConfiguration(for: childId, appId: appId)
        }))
        .environmentObject(rewardCoordinator)
}
