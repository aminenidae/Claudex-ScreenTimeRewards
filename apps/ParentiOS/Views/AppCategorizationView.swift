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

    var selectedChild: ChildProfile? {
        guard !childrenManager.children.isEmpty else { return nil }
        return childrenManager.children[selectedChildIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Child selector (if multiple children)
            if childrenManager.children.count > 1 {
                ChildSelectorView(
                    children: childrenManager.children,
                    selectedIndex: $selectedChildIndex
                )
                .padding(.horizontal)
                .padding(.vertical, 12)

                Divider()
            }

            // Main content
            if let child = selectedChild {
                ScrollView {
                    VStack(spacing: 20) {
                        // Instructions
                        InstructionsCard()
                            .padding(.horizontal)
                            .padding(.top, 20)

                        // Learning Apps Section
                        CategorySection(
                            title: "Learning Apps",
                            subtitle: "Earn points when used",
                            icon: "graduationcap.fill",
                            iconColor: .green,
                            summary: rulesManager.getSummary(for: child.id).learningDescription,
                            action: { showingLearningPicker = true }
                        )
                        .padding(.horizontal)

                        // Reward Apps Section
                        CategorySection(
                            title: "Reward Apps",
                            subtitle: "Require points to unlock",
                            icon: "star.fill",
                            iconColor: .orange,
                            summary: rulesManager.getSummary(for: child.id).rewardDescription,
                            action: { showingRewardPicker = true }
                        )
                        .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                }
            } else {
                // No children state
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("No Children")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Add children to configure app categories")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .navigationTitle("App Categories")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(
            isPresented: $showingLearningPicker,
            selection: learningSelectionBinding
        )
        .familyActivityPicker(
            isPresented: $showingRewardPicker,
            selection: rewardSelectionBinding
        )
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

struct InstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("How It Works")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(
                    icon: "graduationcap.fill",
                    color: .green,
                    text: "Learning apps earn points while your child uses them"
                )

                InstructionRow(
                    icon: "star.fill",
                    color: .orange,
                    text: "Reward apps require points to unlock for limited time"
                )

                InstructionRow(
                    icon: "app.badge",
                    color: .blue,
                    text: "Tap each section below to choose apps or categories"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct InstructionRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct CategorySection: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let summary: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(iconColor.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            }

            // Summary of selected apps/categories
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(summary == "Not configured" ? Color.secondary : Color.green)
                    .font(.system(size: 14))

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(summary == "Not configured" ? .secondary : .primary)

                Spacer()
            }
            .padding(.leading, 52) // Align with title
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            action()
        }
    }
}

#Preview("Single Child") {
    let ledger = PointsLedger()
    let engine = PointsEngine()
    let exemptionManager = ExemptionManager()
    let childrenManager = ChildrenManager(ledger: ledger, engine: engine, exemptionManager: exemptionManager)
    let rulesManager = CategoryRulesManager()

    childrenManager.children = [ChildProfile(id: ChildID("child-1"), name: "Alice")]
    childrenManager.selectedChildId = childrenManager.children.first?.id

    return NavigationStack {
        AppCategorizationView(childrenManager: childrenManager, rulesManager: rulesManager)
    }
}

#Preview("Multiple Children") {
    let ledger = PointsLedger()
    let engine = PointsEngine()
    let exemptionManager = ExemptionManager()
    let childrenManager = ChildrenManager(ledger: ledger, engine: engine, exemptionManager: exemptionManager)
    let rulesManager = CategoryRulesManager()

    childrenManager.loadDemoChildren()

    return NavigationStack {
        AppCategorizationView(childrenManager: childrenManager, rulesManager: rulesManager)
    }
}
