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
                            title: "Learning Categories",
                            subtitle: "Select categories like Education, Productivity",
                            icon: "graduationcap.fill",
                            iconColor: .green,
                            summary: summary.learningDescription,
                            isEnabled: canConfigureCategories,
                            action: { showingLearningPicker = true }
                        )
                        .padding(.horizontal)

                        CategorySection(
                            title: "Reward Categories",
                            subtitle: "Select categories like Games, Entertainment",
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
        .sheet(isPresented: $showingLearningPicker) {
            // On child device, use standard FamilyActivityPicker (tokens work locally)
            FamilyActivityPicker(selection: learningSelectionBinding)
        }
        .sheet(isPresented: $showingRewardPicker) {
            // On child device, use standard FamilyActivityPicker (tokens work locally)
            FamilyActivityPicker(selection: rewardSelectionBinding)
        }
        .sheet(isPresented: $showingAddChildSheet) {
            if FeatureFlags.enablesFamilyAuthorization {
                AddChildSheet { name in
                    await childrenManager.addChild(named: name)
                } onSuccess: { profile in
                    _ = rulesManager.getRules(for: profile.id)
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
            }
        )
    }
}

// MARK: - Supporting Views

@available(iOS 16.0, *)
private struct InstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(.blue)
                Text("How it works")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Select **categories** (like Education or Games) to classify apps:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("**Learning categories** earn points automatically")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("**Reward categories** stay blocked until children redeem points")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .padding(.vertical, 4)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Why categories?")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Categories work across devices. Individual apps selected from your device won't match apps on your child's device due to Apple's privacy protections.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
