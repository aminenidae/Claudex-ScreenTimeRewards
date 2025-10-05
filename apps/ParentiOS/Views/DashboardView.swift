import SwiftUI
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

@MainActor
struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var showingRedemptionSheet = false

    private var redemptionCoordinator: RedemptionCoordinator? {
        guard let exemptionManager = viewModel.exemptionManager else { return nil }
        return RedemptionCoordinator(
            childId: viewModel.childId,
            redemptionService: viewModel.redemptionService,
            exemptionManager: exemptionManager
        )
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    viewModel.refresh()
                }
            } else {
                content
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            viewModel.refresh()
        }
        .onAppear {
            viewModel.refresh()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .sheet(isPresented: $showingRedemptionSheet) {
            if let redemptionCoordinator = redemptionCoordinator {
                ChildRedemptionView(
                    redemptionCoordinator: redemptionCoordinator,
                    pointsBalance: viewModel.balance,
                    config: .default
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if sizeClass == .regular {
            // iPad layout - 2 column grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                cards
            }
            .padding()
        } else {
            // iPhone layout - vertical stack
            VStack(spacing: 16) {
                cards
            }
            .padding()
        }
    }

    @ViewBuilder
    private var cards: some View {
        PointsBalanceCard(
            balance: viewModel.balance,
            todayPoints: viewModel.todayPoints,
            dailyCapProgress: viewModel.dailyCapProgress
        )

        LearningTimeCard(
            todayMinutes: viewModel.todayLearningMinutes,
            weekMinutes: viewModel.weekLearningMinutes
        )

        RedemptionsCard(
            recentRedemptions: viewModel.recentRedemptions,
            activeWindow: viewModel.activeWindow,
            remainingTime: viewModel.remainingExemptionTime,
            onRedeem: {
                showingRedemptionSheet = true
            }
        )

        ShieldStatusCard(
            shieldState: viewModel.shieldState,
            shieldedAppsCount: 0, // TODO: Get from ShieldController
            activeWindow: viewModel.activeWindow
        )
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                retry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview("iPhone") {
    NavigationStack {
        DashboardView(viewModel: .mock())
    }
    .environment(\.horizontalSizeClass, .compact)
}

#Preview("iPad") {
    NavigationStack {
        DashboardView(viewModel: .mock())
    }
    .environment(\.horizontalSizeClass, .regular)
}
