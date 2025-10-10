import SwiftUI
import FamilyControls
#if canImport(Core)
import Core
#endif
#if canImport(SyncKit)
import SyncKit
#endif

@available(iOS 16.0, *)
struct AppCategorizationView: View {
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var rulesManager: CategoryRulesManager
    @EnvironmentObject private var pairingService: PairingService

    @State private var selectedChildIndex: Int = 0
    @State private var showingLearningPicker = false
    @State private var showingRewardPicker = false
    @State private var showingAddChildSheet = false
    @State private var showingManageChildrenSheet = false
    @State private var showingConflictAlert = false
    @State private var conflictResolutionChoice = 0 // 0 = keep learning, 1 = keep reward
    @State private var isPairingSyncInProgress = false

    // Phase 3a: App Inventory
    @State private var appInventory: ChildAppInventoryPayload?
    @State private var isLoadingInventory = false
    @State private var showingValidationSummary = false
    @State private var validationMessage = ""

    var selectedChild: ChildProfile? {
        guard !childrenManager.children.isEmpty else { return nil }
        guard selectedChildIndex < childrenManager.children.count else { return nil }
        return childrenManager.children[selectedChildIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if childrenManager.children.count > 1 {
                ChildSelectorView(
                    children: childrenManager.children,
                    selectedIndex: $selectedChildIndex
                )
                .padding(.horizontal)
                .padding(.vertical, 12)

                Divider()
            }

            if let child = selectedChild {
                ScrollView {
                    VStack(spacing: 20) {
                        InstructionsCard()
                            .padding(.horizontal)
                            .padding(.top, 20)

                        // Phase 3a: Show app inventory info
                        InventoryInfoCard(
                            inventory: appInventory,
                            isLoading: isLoadingInventory,
                            childName: child.name
                        )
                        .padding(.horizontal)

                        // Show conflict warning if there are conflicts
                        let summary = rulesManager.getSummary(for: child.id)
                        let canConfigureCategories = isChildPaired(child.id)
                        if summary.hasConflicts {
                            ConflictWarningCard(
                                conflictCount: summary.conflictCount,
                                onResolve: { showingConflictAlert = true }
                            )
                            .padding(.horizontal)
                        }

                        if !canConfigureCategories {
                            PairingRequiredCard(childName: child.name)
                                .padding(.horizontal)
                        }

                        CategorySection(
                            title: "Learning Apps",
                            subtitle: "Earn points when used",
                            icon: "graduationcap.fill",
                            iconColor: .green,
                            summary: summary.learningDescription,
                            isEnabled: canConfigureCategories,
                            action: { showingLearningPicker = true }
                        )
                        .padding(.horizontal)

                        CategorySection(
                            title: "Reward Apps",
                            subtitle: "Require points to unlock",
                            icon: "star.fill",
                            iconColor: .orange,
                            summary: summary.rewardDescription,
                            isEnabled: canConfigureCategories,
                            action: { showingRewardPicker = true }
                        )
                        .padding(.horizontal)

                        if FeatureFlags.enablesFamilyAuthorization {
                            VStack {
                                Button {
                                    showingAddChildSheet = true
                                } label: {
                                    Label("Add Another Child", systemImage: "plus")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    showingManageChildrenSheet = true
                                } label: {
                                    Label("Manage Children", systemImage: "person.crop.circle.badge.xmark")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: 600)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("No Children Linked")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Link a child to start configuring learning and reward apps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if FeatureFlags.enablesFamilyAuthorization {
                        Button {
                            showingAddChildSheet = true
                        } label: {
                            Label("Add Child", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal, 40)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("App Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if FeatureFlags.enablesFamilyAuthorization {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddChildSheet = true
                    } label: {
                        Label("Add Child", systemImage: "plus")
                    }
                    .disabled(showingLearningPicker || showingRewardPicker)
                }
            }
        }
        .task {
            await syncPairingsFromCloud()
        }
        .task(id: selectedChild?.id) {
            // Phase 3a: Fetch inventory when child changes
            if let child = selectedChild {
                await fetchAppInventory(for: child.id)
            }
        }
        .sheet(isPresented: $showingLearningPicker) {
            if let child = selectedChild, isChildPaired(child.id) {
                FamilyActivityPicker(
                    selection: learningSelectionBinding
                )
                .onAppear {
                    print("🎯 FamilyActivityPicker (Learning) opened for child: \(child.name) (\(child.id.rawValue))")
                }
                .onDisappear {
                    print("🎯 FamilyActivityPicker (Learning) closed for child: \(child.name)")
                }
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showingRewardPicker) {
            if let child = selectedChild, isChildPaired(child.id) {
                FamilyActivityPicker(
                    selection: rewardSelectionBinding
                )
                .onAppear {
                    print("🎯 FamilyActivityPicker (Reward) opened for child: \(child.name) (\(child.id.rawValue))")
                }
                .onDisappear {
                    print("🎯 FamilyActivityPicker (Reward) closed for child: \(child.name)")
                }
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showingAddChildSheet) {
            if FeatureFlags.enablesFamilyAuthorization {
                AddChildSheet { name in
                    await childrenManager.addChild(named: name)
                } onSuccess: { profile in
                    rulesManager.getRules(for: profile.id)
                    if let idx = childrenManager.children.firstIndex(where: { $0.id == profile.id }) {
                        selectedChildIndex = idx
                    }
                }
            }
        }
        .sheet(isPresented: $showingManageChildrenSheet) {
            ManageChildrenView(childrenManager: childrenManager)
        }
        .alert("Conflict Resolution", isPresented: $showingConflictAlert) {
            Button("Keep Learning Apps") {
                if let child = selectedChild {
                    rulesManager.resolveConflicts(for: child.id, keepLearning: true)
                }
            }
            Button("Keep Reward Apps") {
                if let child = selectedChild {
                    rulesManager.resolveConflicts(for: child.id, keepLearning: false)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Some apps are classified as both learning and reward. Which category should take precedence?")
        }
        .alert("Selection Summary", isPresented: $showingValidationSummary) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .onReceive(childrenManager.$children) { newChildren in
            if selectedChildIndex >= newChildren.count {
                selectedChildIndex = max(0, newChildren.count - 1)
            }
        }
    }

    // MARK: - Helper Methods

    private func hasConflicts(for childId: ChildID) -> Bool {
        return !rulesManager.detectConflicts(for: childId).isEmpty
    }

    private func conflictCount(for childId: ChildID) -> Int {
        return rulesManager.detectConflicts(for: childId).count
    }

    private func isChildPaired(_ childId: ChildID) -> Bool {
        !pairingService.getPairings(for: childId).isEmpty
    }

    private func syncPairingsFromCloud() async {
        #if canImport(CloudKit)
        guard !isPairingSyncInProgress else { return }
        isPairingSyncInProgress = true
        defer { isPairingSyncInProgress = false }

        do {
            // Log start time for performance monitoring
            let startTime = CFAbsoluteTimeGetCurrent()
            print("AppCategorizationView: Starting syncPairingsFromCloud")
            // Call the sync method without blocking the main actor
            try await pairingService.syncWithCloudKit(familyId: FamilyID("default-family"))
            let endTime = CFAbsoluteTimeGetCurrent()
            print("AppCategorizationView: Completed syncPairingsFromCloud in \(endTime - startTime)s")
        } catch {
            print("AppCategorizationView: Failed to sync pairing state: \(error)")
        }
        #endif
    }

    // MARK: - Phase 3a: App Inventory

    private func fetchAppInventory(for childId: ChildID) async {
        #if canImport(CloudKit)
        isLoadingInventory = true
        defer { isLoadingInventory = false }

        guard let syncService = childrenManager.syncService else {
            print("⚠️ AppCategorizationView: No sync service available, skipping inventory fetch")
            await MainActor.run {
                self.appInventory = nil
            }
            return
        }

        do {
            print("📱 AppCategorizationView: Fetching app inventory for child: \(childId.rawValue)")
            let inventory = try await syncService.fetchAppInventory(
                familyId: FamilyID("default-family"),
                childId: childId
            )

            await MainActor.run {
                self.appInventory = inventory
                if let inv = inventory {
                    print("📱 AppCategorizationView: Loaded inventory - \(inv.appCount) apps, last updated: \(inv.lastUpdated)")
                } else {
                    print("📱 AppCategorizationView: No inventory found for child")
                }
            }
        } catch {
            print("❌ AppCategorizationView: Failed to fetch inventory: \(error)")
            await MainActor.run {
                self.appInventory = nil
            }
        }
        #endif
    }

    private func validateSelection(_ selection: FamilyActivitySelection, for childId: ChildID, category: String) {
        guard let inventory = appInventory else {
            print("📱 AppCategorizationView: No inventory to validate against")
            return
        }

        let selectedTokens = selection.applicationTokens.map { token in
            let data = withUnsafeBytes(of: token) { Data($0) }
            return data.base64EncodedString()
        }

        let inventoryTokens = Set(inventory.appTokens)
        let matchingCount = selectedTokens.filter { inventoryTokens.contains($0) }.count
        let totalCount = selectedTokens.count

        if totalCount == 0 {
            return // No apps selected, nothing to validate
        }

        let message: String
        if matchingCount == totalCount {
            message = "✅ All \(totalCount) selected \(category) apps are on \(selectedChild?.name ?? "child")'s device"
        } else if matchingCount == 0 {
            message = "⚠️ None of the \(totalCount) selected \(category) apps were found on \(selectedChild?.name ?? "child")'s device. They may not be categorized yet."
        } else {
            let notMatching = totalCount - matchingCount
            message = "⚠️ \(matchingCount) of \(totalCount) selected \(category) apps are on \(selectedChild?.name ?? "child")'s device. \(notMatching) app\(notMatching == 1 ? "" : "s") may not be installed or categorized yet."
        }

        validationMessage = message
        showingValidationSummary = true
        print("📱 AppCategorizationView: Validation - \(message)")
    }

    // MARK: - Bindings

    private var learningSelectionBinding: Binding<FamilyActivitySelection> {
        Binding(
            get: {
                guard let child = selectedChild else {
                    return FamilyActivitySelection()
                }
                return rulesManager.getRules(for: child.id).learningSelection
            },
            set: { newValue in
                guard let child = selectedChild else { return }
                rulesManager.updateLearningApps(for: child.id, selection: newValue)
                // Phase 3a: Validate selection against inventory
                validateSelection(newValue, for: child.id, category: "learning")
            }
        )
    }

    private var rewardSelectionBinding: Binding<FamilyActivitySelection> {
        Binding(
            get: {
                guard let child = selectedChild else {
                    return FamilyActivitySelection()
                }
                return rulesManager.getRules(for: child.id).rewardSelection
            },
            set: { newValue in
                guard let child = selectedChild else { return }
                rulesManager.updateRewardApps(for: child.id, selection: newValue)
                // Phase 3a: Validate selection against inventory
                validateSelection(newValue, for: child.id, category: "reward")
            }
        )
    }
}

// MARK: - Supporting Views

@available(iOS 16.0, *)
private struct InstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works")
                .font(.headline)
            Text("Learning apps earn points automatically. Reward apps stay blocked until children redeem their points for screen time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

@available(iOS 16.0, *)
private struct ConflictWarningCard: View {
    let conflictCount: Int
    let onResolve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("App Conflicts Detected")
                    .font(.headline)
                Spacer()
            }
            
            Text("There \(conflictCount == 1 ? "is" : "are") \(conflictCount) app\(conflictCount == 1 ? "" : "s") classified as both learning and reward. This may cause unexpected behavior.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: onResolve) {
                Text("Resolve Conflicts")
                    .font(.callout)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

@available(iOS 16.0, *)
private struct CategorySection: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let summary: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .overlay {
            if !isEnabled {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(Color.secondary.opacity(0.4))
            }
        }
    }
}

@available(iOS 16.0, *)
private struct PairingRequiredCard: View {
    let childName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 6) {
                Text("Link \(childName)'s device to choose apps")
                    .font(.headline)
                Text("Pair the child's device first, then come back to assign learning and reward apps.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Phase 3a: Inventory Info Card

@available(iOS 16.0, *)
private struct InventoryInfoCard: View {
    let inventory: ChildAppInventoryPayload?
    let isLoading: Bool
    let childName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "apps.iphone")
                    .foregroundStyle(.blue)
                Text("App Inventory")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let inventory = inventory {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(childName) has categorized \(inventory.appCount) app\(inventory.appCount == 1 ? "" : "s")")
                            .font(.subheadline)
                    }

                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text("Last synced: \(formattedDate(inventory.lastUpdated))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if !isLoading {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("No app inventory synced yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("After categorizing apps, the inventory will sync automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
