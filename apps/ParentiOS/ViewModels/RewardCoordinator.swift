#if canImport(ManagedSettings) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
import Foundation
import Combine
import FamilyControls
import PointsEngine
#if canImport(Core)
import Core
#endif

@available(iOS 16.0, *)
protocol RewardCoordinatorProtocol: AnyObject {
    func canRedeem(childId: ChildID, points: Int, config: RedemptionConfiguration) -> Result<Int, RedemptionError>
    func redeem(childId: ChildID, points: Int, config: RedemptionConfiguration) -> Result<EarnedTimeWindow, RedemptionError>
    func isExemptionActive(for childId: ChildID) -> Bool
}

@available(iOS 16.0, *)
@MainActor
final class RewardCoordinator: ObservableObject, RewardCoordinatorProtocol {
    private let rulesManager: CategoryRulesManager
    private let redemptionService: RedemptionService
    private let shieldController: ShieldController
    private let exemptionManager: ExemptionManager
    private var cancellables = Set<AnyCancellable>()

    init(
        rulesManager: CategoryRulesManager,
        redemptionService: RedemptionService,
        shieldController: ShieldController,
        exemptionManager: ExemptionManager
    ) {
        self.rulesManager = rulesManager
        self.redemptionService = redemptionService
        self.shieldController = shieldController
        self.exemptionManager = exemptionManager

        observeRuleChanges()
        applyCurrentRules()
    }

    // MARK: - Reward Selection Handling

    private func observeRuleChanges() {
        rulesManager.$childRules
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rules in
                self?.applyRewardRules(rules)
            }
            .store(in: &cancellables)
    }

    private func applyCurrentRules() {
        applyRewardRules(rulesManager.childRules)
    }

    private func applyRewardRules(_ rules: [ChildID: ChildAppRules]) {
        for (childId, childRules) in rules {
            let rewardSelection = childRules.rewardSelection
            if rewardSelection.isEmpty {
                shieldController.clearAllShields(for: childId)
            } else {
                shieldController.applyShields(for: childId, rewardApps: rewardSelection)
            }
        }
    }

    // MARK: - Redemption

    func canRedeem(childId: ChildID, points: Int, config: RedemptionConfiguration = .default) -> Result<Int, RedemptionError> {
        redemptionService.canRedeem(childId: childId, points: points, config: config)
    }

    func redeem(childId: ChildID, points: Int, config: RedemptionConfiguration = .default) -> Result<EarnedTimeWindow, RedemptionError> {
        switch redemptionService.canRedeem(childId: childId, points: points, config: config) {
        case .failure(let error):
            return .failure(error)
        case .success:
            break
        }

        do {
            let window = try redemptionService.redeem(childId: childId, points: points, config: config)
            shieldController.grantExemption(for: childId)
            exemptionManager.startExemption(window: window) { [weak self] in
                Task { @MainActor in
                    self?.shieldController.revokeExemption(for: childId)
                }
            }
            return .success(window)
        } catch let error as RedemptionError {
            return .failure(error)
        } catch {
            return .failure(.childNotFound(childId))
        }
    }

    func isExemptionActive(for childId: ChildID) -> Bool {
        exemptionManager.getActiveWindow(for: childId) != nil
    }
}

private extension FamilyActivitySelection {
    var isEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }
}
#else
import Foundation
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

protocol RewardCoordinatorProtocol: AnyObject {
    func canRedeem(childId: ChildID, points: Int, config: RedemptionConfiguration) -> Result<Int, RedemptionError>
    func redeem(childId: ChildID, points: Int, config: RedemptionConfiguration) -> Result<EarnedTimeWindow, RedemptionError>
    func isExemptionActive(for childId: ChildID) -> Bool
}

final class RewardCoordinator: ObservableObject, RewardCoordinatorProtocol {
    func canRedeem(childId: ChildID, points: Int, config: RedemptionConfiguration) -> Result<Int, RedemptionError> {
        .failure(.childNotFound(childId))
    }

    func redeem(childId: ChildID, points: Int, config: RedemptionConfiguration) -> Result<EarnedTimeWindow, RedemptionError> {
        .failure(.childNotFound(childId))
    }

    func isExemptionActive(for childId: ChildID) -> Bool { false }
}
#endif
