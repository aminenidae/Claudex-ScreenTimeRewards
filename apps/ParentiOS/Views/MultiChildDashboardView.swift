import SwiftUI
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

@available(iOS 16.0, *)
struct MultiChildDashboardView: View {
    @ObservedObject var childrenManager: ChildrenManager
    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Child selector at top
            if childrenManager.children.count > 1 {
                ChildSelectorView(
                    children: childrenManager.children,
                    selectedIndex: $selectedIndex
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Horizontal paging TabView for dashboards
            TabView(selection: $selectedIndex) {
                ForEach(Array(childrenManager.children.enumerated()), id: \.element.id) { index, child in
                    let viewModel = childrenManager.getViewModel(for: child.id)
                    DashboardView(viewModel: viewModel)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // Hide default page indicator
            .onChange(of: selectedIndex) { newValue in
                childrenManager.selectChild(at: newValue)
            }
        }
        .onAppear {
            selectedIndex = childrenManager.selectedChildIndex
        }
    }
}

/// Child selector with horizontal scrolling buttons
@available(iOS 16.0, *)
struct ChildSelectorView: View {
    let children: [ChildProfile]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedIndex = index
                        }
                    } label: {
                        ChildSelectorButton(
                            name: child.name,
                            isSelected: selectedIndex == index
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

/// Individual child selector button
struct ChildSelectorButton: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "person.circle.fill" : "person.circle")
                .font(.system(size: 20))
            Text(name)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        )
        .foregroundStyle(isSelected ? .white : .primary)
    }
}

#Preview("Single Child") {
    let ledger = PointsLedger()
    let engine = PointsEngine()
    let exemptionManager = ExemptionManager()
    let manager = ChildrenManager(ledger: ledger, engine: engine, exemptionManager: exemptionManager)

    // Single child
    manager.children = [ChildProfile(id: ChildID("child-1"), name: "Alice")]
    manager.selectedChildId = manager.children.first?.id

    return MultiChildDashboardView(childrenManager: manager)
}

#Preview("Multiple Children") {
    let ledger = PointsLedger()
    let engine = PointsEngine()
    let exemptionManager = ExemptionManager()
    let manager = ChildrenManager(ledger: ledger, engine: engine, exemptionManager: exemptionManager)

    manager.loadDemoChildren()

    return MultiChildDashboardView(childrenManager: manager)
}
