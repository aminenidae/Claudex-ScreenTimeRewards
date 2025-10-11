import SwiftUI
import FamilyControls
import ManagedSettings
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
            if let child = selectedChild, isChildPaired(child.id), let inventory = appInventory, !inventory.appTokens.isEmpty {
                // Use filtered picker only if inventory has individual app tokens
                FilteredAppPickerView(
                    childName: child.name,
                    inventory: inventory,
                    currentLearning: getCurrentLearningTokens(for: child.id),
                    currentReward: getCurrentRewardTokens(for: child.id),
                    onSave: { tokens in
                        updateLearningFromTokens(tokens, for: child.id)
                    },
                    category: .learning
                )
                .onAppear {
                    print("🎯 FilteredAppPickerView (Learning) opened with \(inventory.appTokens.count) individual apps")
                }
            } else if let child = selectedChild, isChildPaired(child.id) {
                // Fallback to regular picker if no inventory or only categories
                FamilyActivityPicker(
                    selection: learningSelectionBinding
                )
                .onAppear {
                    if let inventory = appInventory, inventory.appTokens.isEmpty && !inventory.categoryTokens.isEmpty {
                        print("🎯 FamilyActivityPicker (Learning) - inventory only has categories, using fallback picker")
                    } else {
                        print("🎯 FamilyActivityPicker (Learning) opened - no inventory available")
                    }
                }
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showingRewardPicker) {
            if let child = selectedChild, isChildPaired(child.id), let inventory = appInventory, !inventory.appTokens.isEmpty {
                // Use filtered picker only if inventory has individual app tokens
                FilteredAppPickerView(
                    childName: child.name,
                    inventory: inventory,
                    currentLearning: getCurrentLearningTokens(for: child.id),
                    currentReward: getCurrentRewardTokens(for: child.id),
                    onSave: { tokens in
                        updateRewardFromTokens(tokens, for: child.id)
                    },
                    category: .reward
                )
                .onAppear {
                    print("🎯 FilteredAppPickerView (Reward) opened with \(inventory.appTokens.count) individual apps")
                }
            } else if let child = selectedChild, isChildPaired(child.id) {
                // Fallback to regular picker if no inventory or only categories
                FamilyActivityPicker(
                    selection: rewardSelectionBinding
                )
                .onAppear {
                    if let inventory = appInventory, inventory.appTokens.isEmpty && !inventory.categoryTokens.isEmpty {
                        print("🎯 FamilyActivityPicker (Reward) - inventory only has categories, using fallback picker")
                    } else {
                        print("🎯 FamilyActivityPicker (Reward) opened - no inventory available")
                    }
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

    // MARK: - Token Management

    private func getCurrentLearningTokens(for childId: ChildID) -> Set<String> {
        let selection = rulesManager.getRules(for: childId).learningSelection
        return encodeSelectionToTokens(selection)
    }

    private func getCurrentRewardTokens(for childId: ChildID) -> Set<String> {
        let selection = rulesManager.getRules(for: childId).rewardSelection
        return encodeSelectionToTokens(selection)
    }

    private func encodeSelectionToTokens(_ selection: FamilyActivitySelection) -> Set<String> {
        var tokens = Set<String>()

        // Encode application tokens
        for token in selection.applicationTokens {
            let data = withUnsafeBytes(of: token) { Data($0) }
            tokens.insert(data.base64EncodedString())
        }

        // Encode category tokens
        for token in selection.categoryTokens {
            let data = withUnsafeBytes(of: token) { Data($0) }
            tokens.insert(data.base64EncodedString())
        }

        return tokens
    }

    private func updateLearningFromTokens(_ tokens: Set<String>, for childId: ChildID) {
        guard let inventory = appInventory else { return }
        let selection = createSelection(from: tokens, inventory: inventory)
        rulesManager.updateLearningApps(for: childId, selection: selection)
        print("📱 Updated learning apps: \(tokens.count) tokens selected")
    }

    private func updateRewardFromTokens(_ tokens: Set<String>, for childId: ChildID) {
        guard let inventory = appInventory else { return }
        let selection = createSelection(from: tokens, inventory: inventory)
        rulesManager.updateRewardApps(for: childId, selection: selection)
        print("📱 Updated reward apps: \(tokens.count) tokens selected")
    }

    private func createSelection(from tokens: Set<String>, inventory: ChildAppInventoryPayload) -> FamilyActivitySelection {
        var selection = FamilyActivitySelection()

        // Decode application tokens
        let appTokens = tokens.filter { inventory.appTokens.contains($0) }
        for tokenString in appTokens {
            if let token = decodeApplicationToken(from: tokenString) {
                selection.applicationTokens.insert(token)
            }
        }

        // Decode category tokens
        let catTokens = tokens.filter { inventory.categoryTokens.contains($0) }
        for tokenString in catTokens {
            if let token = decodeCategoryToken(from: tokenString) {
                selection.categoryTokens.insert(token)
            }
        }

        return selection
    }

    private func decodeApplicationToken(from base64: String) -> ApplicationToken? {
        guard let data = Data(base64Encoded: base64) else {
            print("⚠️ Failed to decode base64 for app token")
            return nil
        }

        let expectedSize = MemoryLayout<ApplicationToken>.size
        guard data.count == expectedSize else {
            print("⚠️ App token size mismatch: got \(data.count), expected \(expectedSize)")
            return nil
        }

        // ApplicationTokens from child device cannot be decoded on parent device
        // This is a Family Controls limitation - ALL tokens are device-specific
        print("⚠️ Skipping app token - cross-device tokens not supported by Family Controls")
        return nil
    }

    private func decodeCategoryToken(from base64: String) -> ManagedSettings.ActivityCategoryToken? {
        guard let data = Data(base64Encoded: base64) else {
            print("⚠️ Failed to decode base64 for category token")
            return nil
        }

        let expectedSize = MemoryLayout<ManagedSettings.ActivityCategoryToken>.size
        guard data.count == expectedSize else {
            print("⚠️ Category token size mismatch: got \(data.count), expected \(expectedSize)")
            return nil
        }

        // Category tokens from child device may not be decodable on parent device
        // This is a limitation of Family Controls cross-device token usage
        // For now, we skip categories in the filtered picker
        print("⚠️ Skipping category token - cross-device category tokens not supported")
        return nil
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
                    if inventory.appTokens.isEmpty && !inventory.categoryTokens.isEmpty {
                        // Warning: only categories selected (won't work cross-device)
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("\(childName) selected only categories (\(inventory.categoryTokens.count) items)")
                                .font(.subheadline)
                        }

                        Text("Categories don't work across devices. Ask \(childName) to select individual apps instead.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("\(childName) has categorized \(inventory.appTokens.count) app\(inventory.appTokens.count == 1 ? "" : "s")")
                                .font(.subheadline)
                        }
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
@available(iOS 16.0, *)
struct FilteredAppPickerView: View {
    let childName: String
    let inventory: ChildAppInventoryPayload
    let currentLearning: Set<String> // Base64 tokens already in learning
    let currentReward: Set<String> // Base64 tokens already in reward
    let onSave: (Set<String>) -> Void
    let category: AppClassification

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTokens: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header info
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(childName) has \(inventory.appCount) app\(inventory.appCount == 1 ? "" : "s") on their device")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Select which apps should be \(category == .learning ? "Learning" : "Reward") apps")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))

                Divider()

                // App list
                if inventory.appTokens.isEmpty && inventory.categoryTokens.isEmpty {
                    EmptyInventoryView(childName: childName)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Individual apps
                            ForEach(Array(inventory.appTokens.enumerated()), id: \.offset) { index, tokenString in
                                if let token = decodeToken(from: tokenString) {
                                    AppRow(
                                        token: token,
                                        tokenString: tokenString,
                                        isSelected: selectedTokens.contains(tokenString),
                                        badge: getBadge(for: tokenString),
                                        onToggle: { toggleSelection(tokenString) }
                                    )
                                    .onAppear {
                                        print("📱 Rendered app token at index \(index)")
                                    }

                                    if index < inventory.appTokens.count - 1 {
                                        Divider()
                                            .padding(.leading, 72)
                                    }
                                } else {
                                    Text("Failed to decode app \(index + 1)")
                                        .foregroundStyle(.red)
                                        .padding()
                                        .onAppear {
                                            print("❌ Failed to decode app token at index \(index): \(tokenString.prefix(20))...")
                                        }
                                }
                            }

                            // Categories
                            if !inventory.categoryTokens.isEmpty {
                                Section {
                                    ForEach(Array(inventory.categoryTokens.enumerated()), id: \.offset) { index, tokenString in
                                        if let token = decodeCategoryToken(from: tokenString) {
                                            CategoryRow(
                                                token: token,
                                                tokenString: tokenString,
                                                isSelected: selectedTokens.contains(tokenString),
                                                badge: getBadge(for: tokenString),
                                                onToggle: { toggleSelection(tokenString) }
                                            )

                                            if index < inventory.categoryTokens.count - 1 {
                                                Divider()
                                                    .padding(.leading, 72)
                                            }
                                        }
                                    }
                                } header: {
                                    Text("Categories")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Color(.tertiarySystemBackground))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(category == .learning ? "Learning Apps" : "Reward Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedTokens)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Initialize with current selection for this category
                selectedTokens = category == .learning ? currentLearning : currentReward
            }
        }
    }

    private func toggleSelection(_ token: String) {
        if selectedTokens.contains(token) {
            selectedTokens.remove(token)
        } else {
            selectedTokens.insert(token)
        }
    }

    private func getBadge(for token: String) -> String? {
        if category == .learning && currentReward.contains(token) {
            return "Reward"
        } else if category == .reward && currentLearning.contains(token) {
            return "Learning"
        }
        return nil
    }

    private func decodeToken(from base64: String) -> ApplicationToken? {
        guard let data = Data(base64Encoded: base64) else {
            print("⚠️ FilteredPicker: Failed to decode base64 for app token")
            return nil
        }

        let expectedSize = MemoryLayout<ApplicationToken>.size
        guard data.count == expectedSize else {
            print("⚠️ FilteredPicker: App token size mismatch: got \(data.count), expected \(expectedSize)")
            return nil
        }

        // ApplicationTokens from child device cannot be decoded on parent device
        // This is a Family Controls platform limitation
        print("⚠️ FilteredPicker: Skipping app token - cross-device not supported")
        return nil
    }

    private func decodeCategoryToken(from base64: String) -> ManagedSettings.ActivityCategoryToken? {
        guard let data = Data(base64Encoded: base64) else {
            print("⚠️ FilteredPicker: Failed to decode base64 for category token")
            return nil
        }

        let expectedSize = MemoryLayout<ManagedSettings.ActivityCategoryToken>.size
        guard data.count == expectedSize else {
            print("⚠️ FilteredPicker: Category token size mismatch: got \(data.count), expected \(expectedSize)")
            return nil
        }

        // Category tokens from child device cannot be decoded on parent device
        // This is a Family Controls limitation - tokens are device-specific
        // Skip categories in filtered picker (they won't render anyway)
        print("⚠️ FilteredPicker: Skipping category - cross-device tokens not supported")
        return nil
    }
}

// MARK: - App Row

@available(iOS 16.0, *)
private struct AppRow: View {
    let token: ApplicationToken
    let tokenString: String
    let isSelected: Bool
    let badge: String?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.blue : Color(.tertiaryLabel))
                    .frame(width: 24)

                // App icon and name from FamilyControls
                Label(token)
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Badge if app is in other category
                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Row

@available(iOS 16.0, *)
private struct CategoryRow: View {
    let token: ManagedSettings.ActivityCategoryToken
    let tokenString: String
    let isSelected: Bool
    let badge: String?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.blue : Color(.tertiaryLabel))
                    .frame(width: 24)

                // Category icon and name from FamilyControls
                Label(token)
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Badge if category is in other category
                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(4)
                }

                // Category indicator
                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

@available(iOS 16.0, *)
private struct EmptyInventoryView: View {
    let childName: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Apps Found")
                .font(.title3)
                .fontWeight(.semibold)

            Text("\(childName) hasn't selected any apps on their device yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }
}
