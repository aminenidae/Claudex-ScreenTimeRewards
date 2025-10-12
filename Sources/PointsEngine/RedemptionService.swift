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

    public init(ledger: PointsLedgerProtocol) {
        self.ledger = ledger
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
        let balance: Int
        if let appId = appId {
            balance = ledger.getBalance(childId: childId, appId: appId)
        } else {
            balance = ledger.getBalance(childId: childId)
        }
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

        // Record redemption in ledger (deduct points)
        _ = ledger.recordRedemption(childId: childId, appId: appId, points: points, timestamp: Date())

        // Create earned time window
        let window = EarnedTimeWindow(
            childId: childId,
            durationSeconds: durationSeconds,
            startTime: Date()
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
}
