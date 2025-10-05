import SwiftUI
import FamilyControls
#if canImport(Core)
import Core
#endif

@available(iOS 16.0, *)
struct AppCategorizationView: View {
    @ObservedObject var childrenManager: ChildrenManager
    @ObservedObject var rulesManager: CategoryRulesManager

    @State private var selectedChildIndex: Int = 0
    @State private var showingLearningPicker = false
    @State private var showingRewardPicker = false
    @State private var showingAddChildSheet = false

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

                        CategorySection(
                            title: "Learning Apps",
                            subtitle: "Earn points when used",
                            icon: "graduationcap.fill",
                            iconColor: .green,
                            summary: rulesManager.getSummary(for: child.id).learningDescription,
                            action: { showingLearningPicker = true }
                        )
                        .padding(.horizontal)

                        CategorySection(
                            title: "Reward Apps",
                            subtitle: "Require points to unlock",
                            icon: "star.fill",
                            iconColor: .orange,
                            summary: rulesManager.getSummary(for: child.id).rewardDescription,
                            action: { showingRewardPicker = true }
                        )
                        .padding(.horizontal)

                        if FeatureFlags.enablesFamilyAuthorization {
                            Button {
                                showingAddChildSheet = true
                            } label: {
                                Label("Add Another Child", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
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
        .familyActivityPicker(
            isPresented: $showingLearningPicker,
            selection: learningSelectionBinding
        )
        .familyActivityPicker(
            isPresented: $showingRewardPicker,
            selection: rewardSelectionBinding
        )
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
        .onReceive(childrenManager.$children) { newChildren in
            if selectedChildIndex >= newChildren.count {
                selectedChildIndex = max(0, newChildren.count - 1)
            }
        }
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

// MARK: - Supporting Views remain unchanged...

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
private struct CategorySection: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let summary: String
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
    }
}
