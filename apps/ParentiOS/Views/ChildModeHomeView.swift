import SwiftUI
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

/// Child mode home screen showing points, earned time, recent rewards, and redemption options
struct ChildModeHomeView: View {
    let childProfile: ChildProfile
    let ledger: PointsLedger
    let exemptionManager: ExemptionManager
    let redemptionService: RedemptionServiceProtocol
    let onUnlinkRequest: () -> Void

    @State private var showingRedemptionSheet = false
    
    private var balance: Int {
        ledger.getBalance(childId: childProfile.id)
    }

    private var todayAccrual: Int {
        ledger.getTodayAccrual(childId: childProfile.id)
    }

    private var activeWindow: EarnedTimeWindow? {
        exemptionManager.getActiveWindow(for: childProfile.id)
    }

    private var recentEntries: [PointsLedgerEntry] {
        ledger.getEntries(childId: childProfile.id, limit: 5)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Points Summary Card
                pointsSummaryCard
                
                // Active Reward Time Card
                if let window = activeWindow {
                    activeRewardTimeCard(window: window)
                }
                
                // Recent Activity Section
                recentActivitySection
                
                // Request More Time Button
                requestMoreTimeButton
                
                Spacer(minLength: 20)
            }
            .padding(.vertical, 32)
        }
        .navigationTitle("My Rewards")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRedemptionSheet) {
            ChildRedemptionView(
                childProfile: childProfile,
                ledger: ledger,
                redemptionService: redemptionService,
                onRedemptionRequested: { points in
                    // TODO: Implement actual redemption request flow
                    print("Redemption requested for \(points) points")
                    showingRedemptionSheet = false
                    // For now, just show an alert
                },
                onCancel: {
                    showingRedemptionSheet = false
                }
            )
        }
    }
    
    // MARK: - Points Summary Card
    
    private var pointsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)
                
                VStack(alignment: .leading) {
                    Text("My Points")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("\(balance)")
                        .font(.system(size: 48, weight: .bold))
                        .contentTransition(.numericText())
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("+\(todayAccrual) points")
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Redeemable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(balance >= 30 ? "Yes" : "No")")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(balance >= 30 ? .green : .red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Active Reward Time Card
    
    private func activeRewardTimeCard(window: EarnedTimeWindow) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading) {
                    Text("Active Reward Time")
                        .font(.headline)
                    
                    Text("Ends \(window.endTime, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack {
                Text("Remaining:")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(Int(window.remainingSeconds / 60))m \(Int(window.remainingSeconds.truncatingRemainder(dividingBy: 60)))s")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal)
            
            if recentEntries.isEmpty {
                Text("No activity yet")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(recentEntries, id: \.id) { entry in
                    recentActivityRow(entry: entry)
                }
            }
        }
    }
    
    private func recentActivityRow(entry: PointsLedgerEntry) -> some View {
        HStack {
            Image(systemName: entry.type == .accrual ? "plus.circle.fill" : "minus.circle.fill")
                .font(.title3)
                .foregroundStyle(entry.type == .accrual ? .green : .red)
            
            VStack(alignment: .leading) {
                Text(entry.type == .accrual ? "Points Earned" : "Points Redeemed")
                    .font(.body)
                
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(entry.amount)")
                .font(.body)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Request More Time Button
    
    private var requestMoreTimeButton: some View {
        Button(action: {
            showingRedemptionSheet = true
        }) {
            HStack {
                Image(systemName: "clock.badge.plus")
                Text("Request More Time")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor)
            )
            .foregroundColor(.white)
        }
        .padding(.horizontal)
        .disabled(balance < 30) // Minimum redemption is 30 points
    }
}

// MARK: - Previews

#Preview("Child Mode Home - With Points") {
    let ledger = PointsLedger()
    let exemptionManager = ExemptionManager()
    let redemptionService = RedemptionService(ledger: ledger)
    
    // Add some mock data
    _ = ledger.recordAccrual(childId: ChildID("child-1"), points: 150, timestamp: Date().addingTimeInterval(-3600))
    _ = ledger.recordRedemption(childId: ChildID("child-1"), points: 50, timestamp: Date().addingTimeInterval(-1800))
    _ = ledger.recordAccrual(childId: ChildID("child-1"), points: 75, timestamp: Date())
    
    return NavigationStack {
        ChildModeHomeView(
            childProfile: ChildProfile(id: ChildID("child-1"), name: "Alice", storeName: "child-child-1"),
            ledger: ledger,
            exemptionManager: exemptionManager,
            redemptionService: redemptionService,
            onUnlinkRequest: {}
        )
    }
}

#Preview("Child Mode Home - No Points") {
    let ledger = PointsLedger()
    let exemptionManager = ExemptionManager()
    let redemptionService = RedemptionService(ledger: ledger)
    
    return NavigationStack {
        ChildModeHomeView(
            childProfile: ChildProfile(id: ChildID("child-1"), name: "Alice", storeName: "child-child-1"),
            ledger: ledger,
            exemptionManager: exemptionManager,
            redemptionService: redemptionService,
            onUnlinkRequest: {}
        )
    }
}