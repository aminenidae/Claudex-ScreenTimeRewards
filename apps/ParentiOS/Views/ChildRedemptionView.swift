import SwiftUI
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

// MARK: - Extensions

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

/// View for requesting redemption of points for time
struct ChildRedemptionView: View {
    let childProfile: ChildProfile
    let ledger: PointsLedger
    let redemptionService: RedemptionServiceProtocol
    let onRedemptionRequested: (Int) -> Void
    let onCancel: () -> Void
    
    @State private var pointsToRedeem = 30 // Minimum redemption
    @State private var errorMessage: String?
    
    private var balance: Int {
        ledger.getBalance(childId: childProfile.id)
    }
    
    private var maxRedeemablePoints: Int {
        min(balance, 600) // Max redemption is 600 points
    }
    
    private var minutesToEarn: Double {
        redemptionService is RedemptionService ? 
        (redemptionService as! RedemptionService).calculateMinutes(points: pointsToRedeem) : 
        Double(pointsToRedeem) / 10.0
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Points Selection
                pointsSelectionSection
                
                // Time Preview
                timePreviewSection
                
                // Action Buttons
                actionButtons
                
                Spacer()
            }
            .padding()
            .navigationTitle("Request Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("OK") {
                    errorMessage = nil
                }
            } message: { message in
                Text(message)
            }
        }
    }
    
    // MARK: - Points Selection Section
    
    private var pointsSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Points to Redeem")
                .font(.headline)
            
            HStack {
                Button(action: decrementPoints) {
                    Image(systemName: "minus")
                        .font(.title2)
                }
                .disabled(pointsToRedeem <= 30)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(pointsToRedeem > 30 ? Color.accentColor : Color.gray)
                )
                .foregroundColor(.white)
                
                Spacer()
                
                VStack {
                    Text("\(pointsToRedeem)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Text("points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: incrementPoints) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
                .disabled(pointsToRedeem >= maxRedeemablePoints)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(pointsToRedeem < maxRedeemablePoints ? Color.accentColor : Color.gray)
                )
                .foregroundColor(.white)
            }
            .padding(.horizontal)
            
            // Slider for fine adjustment
            Slider(
                value: Binding(
                    get: { Double(pointsToRedeem) },
                    set: { pointsToRedeem = Int($0).clamped(to: 30...maxRedeemablePoints) }
                ),
                in: 30...Double(maxRedeemablePoints),
                step: 10
            )
            .padding(.horizontal)
            
            HStack {
                Text("30")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(balance) available")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(maxRedeemablePoints)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Time Preview Section
    
    private var timePreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time You'll Earn")
                .font(.headline)
            
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading) {
                    Text("\(minutesToEarn, specifier: "%.0f") minutes")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("of reward time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: requestRedemption) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                    Text("Request Time")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green)
                )
                .foregroundColor(.white)
            }
            .disabled(!isValidRedemption)
            
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
        }
    }
    
    // MARK: - Actions
    
    private var isValidRedemption: Bool {
        pointsToRedeem >= 30 && pointsToRedeem <= balance && pointsToRedeem <= 600
    }
    
    private func incrementPoints() {
        let increment = pointsToRedeem < 100 ? 10 : 50
        pointsToRedeem = min(pointsToRedeem + increment, maxRedeemablePoints)
    }
    
    private func decrementPoints() {
        let decrement = pointsToRedeem <= 100 ? 10 : 50
        pointsToRedeem = max(pointsToRedeem - decrement, 30)
    }
    
    private func requestRedemption() {
        // Validate the redemption request
        let config = RedemptionConfiguration.default
        
        switch redemptionService.canRedeem(childId: childProfile.id, points: pointsToRedeem, config: config) {
        case .success:
            // Valid redemption, notify parent
            onRedemptionRequested(pointsToRedeem)
        case .failure(let error):
            // Handle error
            switch error {
            case .insufficientBalance:
                errorMessage = "You don't have enough points for this redemption."
            case .belowMinimum:
                errorMessage = "Minimum redemption is 30 points."
            case .aboveMaximum:
                errorMessage = "Maximum redemption is 600 points."
            case .childNotFound:
                errorMessage = "Child profile not found."
            }
        }
    }
}

// MARK: - Previews

#Preview("Redemption View") {
    let ledger = PointsLedger()
    let redemptionService = RedemptionService(ledger: ledger)
    
    // Add some mock points
    _ = ledger.recordAccrual(childId: ChildID("child-1"), points: 200, timestamp: Date())
    
    return ChildRedemptionView(
        childProfile: ChildProfile(id: ChildID("child-1"), name: "Alice", storeName: "child-child-1"),
        ledger: ledger,
        redemptionService: redemptionService,
        onRedemptionRequested: { _ in },
        onCancel: {}
    )
}