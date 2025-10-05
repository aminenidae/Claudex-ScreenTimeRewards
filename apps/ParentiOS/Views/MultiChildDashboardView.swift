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
            if childrenManager.children.isEmpty {
                emptyState
            } else {
                if childrenManager.children.count > 1 {
                    ChildSelectorView(
                        children: childrenManager.children,
                        selectedIndex: $selectedIndex
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                TabView(selection: $selectedIndex) {
                    ForEach(Array(childrenManager.children.enumerated()), id: \.element.id) { index, child in
                        let viewModel = childrenManager.getViewModel(for: child.id)
                        DashboardView(viewModel: viewModel)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedIndex) { newValue in
                    childrenManager.selectChild(at: newValue)
                }
            }
        }
        .onAppear {
            selectedIndex = childrenManager.selectedChildIndex
        }
        .onReceive(childrenManager.$children) { children in
            if children.isEmpty {
                selectedIndex = 0
            } else if selectedIndex >= children.count {
                selectedIndex = max(0, children.count - 1)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No dashboards yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add a child from the Settings tab to start tracking learning and rewards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview("Multiple Children") {
    let ledger = PointsLedger()
    let engine = PointsEngine()
    let exemptionManager = ExemptionManager()
    let manager = ChildrenManager(ledger: ledger, engine: engine, exemptionManager: exemptionManager)
    manager.loadDemoChildren()
    return MultiChildDashboardView(childrenManager: manager)
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
