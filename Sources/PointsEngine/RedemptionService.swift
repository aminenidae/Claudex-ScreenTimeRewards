import Foundation
#if canImport(Core)
import Core
#endif

public enum RedemptionError: Error, Equatable {
    case insufficientBalance(available: Int, required: Int)
    case belowMinimum(points: Int, minimum: Int)
    case aboveMaximum(points: Int, maximum: Int)
    case childNotFound(ChildID)
}

@MainActor
public protocol RedemptionServiceProtocol {
    func redeem(
        childId: ChildID,
        points: Int,
        config: RedemptionConfiguration,
        appId: AppIdentifier?
    ) throws -> EarnedTimeWindow

    func canRedeem(
        childId: ChildID,
        points: Int,
        config: RedemptionConfiguration,
        appId: AppIdentifier?
    ) -> Result<Int, RedemptionError>
}

public extension RedemptionServiceProtocol {
    func redeem(
        childId: ChildID,
        points: Int,
        config: RedemptionConfiguration = .default
    ) throws -> EarnedTimeWindow {
        try redeem(childId: childId, points: points, config: config, appId: nil)
    }

    func canRedeem(
        childId: ChildID,
        points: Int,
        config: RedemptionConfiguration = .default
    ) -> Result<Int, RedemptionError> {
        canRedeem(childId: childId, points: points, config: config, appId: nil)
    }
}

public final class RedemptionService: RedemptionServiceProtocol {
    private let ledger: PointsLedgerProtocol
    private let rewardUsageRecorder: ((ChildID, AppIdentifier, Int) -> Void)?

    public init(ledger: PointsLedgerProtocol, rewardUsageRecorder: ((ChildID, AppIdentifier, Int) -> Void)? = nil) {
        self.ledger = ledger
        self.rewardUsageRecorder = rewardUsageRecorder
    }

    // MARK: - Validation

    @MainActor
    public func canRedeem(
        childId: ChildID,
        points: Int,
        config: RedemptionConfiguration = .default,
        appId: AppIdentifier? = nil
    ) -> Result<Int, RedemptionError> {
        // Check minimum
        guard points >= config.minRedemptionPoints else {
            return .failure(.belowMinimum(points: points, minimum: config.minRedemptionPoints))
        }

        // Check maximum
        guard points <= config.maxRedemptionPoints else {
            return .failure(.aboveMaximum(points: points, maximum: config.maxRedemptionPoints))
        }

        // Check balance
        let balance = ledger.getBalance(childId: childId)
        guard balance >= points else {
            return .failure(.insufficientBalance(available: balance, required: points))
        }

        return .success(balance)
    }

    // MARK: - Redemption

    @MainActor
    public func redeem(
        childId: ChildID,
        points: Int,
        config: RedemptionConfiguration = .default,
        appId: AppIdentifier? = nil
    ) throws -> EarnedTimeWindow {
        // Validate
        switch canRedeem(childId: childId, points: points, config: config, appId: appId) {
        case .success:
            break
        case .failure(let error):
            throw error
        }

        // Calculate earned time
        let minutes = Double(points) / Double(config.pointsPerMinute)
        let durationSeconds = minutes * 60.0

        let timestamp = Date()

        // Determine which app balances will fund this redemption
        let allocations = allocatePoints(childId: childId, totalPoints: points)

        // Record redemption in ledger for each contributing app
        for allocation in allocations {
            _ = ledger.recordRedemption(childId: childId, appId: allocation.appId, points: allocation.points, timestamp: timestamp)
        }

        if let rewardAppId = appId {
            rewardUsageRecorder?(childId, rewardAppId, points)
        }

        // Create earned time window
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: durationSeconds,
            startTime: timestamp
        )

        return window
    }

    // MARK: - Helpers

    /// Calculate how many minutes can be redeemed for given points
    public func calculateMinutes(points: Int, config: RedemptionConfiguration = .default) -> Double {
        Double(points) / Double(config.pointsPerMinute)
    }

    /// Calculate how many points are needed for given minutes
    public func calculatePointsNeeded(minutes: Int, config: RedemptionConfiguration = .default) -> Int {
        minutes * config.pointsPerMinute
    }

    private func allocatePoints(childId: ChildID, totalPoints: Int) -> [(appId: AppIdentifier?, points: Int)] {
        var remaining = totalPoints
        var result: [(AppIdentifier?, Int)] = []

        let perAppBalances = ledger.getBalances(childId: childId)
        let sortedBalances = perAppBalances.sorted { $0.value > $1.value }

        for (appId, balance) in sortedBalances where balance > 0 && remaining > 0 {
            let contribution = min(balance, remaining)
            result.append((appId, contribution))
            remaining -= contribution
        }

        if remaining > 0 {
            let perAppTotal = sortedBalances.reduce(0) { $0 + max(0, $1.value) }
            let globalBalance = ledger.getBalance(childId: childId) - perAppTotal
            let contribution = min(max(0, globalBalance), remaining)
            if contribution > 0 {
                result.append((nil, contribution))
                remaining -= contribution
            }
        }

        if remaining > 0 {
            // This should not happen because validation already checks overall balance,
            // but guard against rounding issues.
            result.append((nil, remaining))
        }

        return result
    }
}
