import Foundation
import Combine
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

@MainActor
class RedemptionCoordinator: ObservableObject {
    @Published private(set) var activeWindow: EarnedTimeWindow?

    private let childId: ChildID
    private let redemptionService: RedemptionServiceProtocol
    private let exemptionManager: ExemptionManagerProtocol

    private var cancellables = Set<AnyCancellable>()

    init(
        childId: ChildID,
        redemptionService: RedemptionServiceProtocol,
        exemptionManager: ExemptionManagerProtocol
    ) {
        self.childId = childId
        self.redemptionService = redemptionService
        self.exemptionManager = exemptionManager

        // Monitor active window
        Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.updateActiveWindow()
        }.store(in: &cancellables)
    }

    func redeem(points: Int, config: RedemptionConfiguration) {
        do {
            let window = try redemptionService.redeem(childId: childId, points: points, config: config)
            exemptionManager.startExemption(window: window, onExpiry: { [weak self] in
                self?.activeWindow = nil
            })
            self.activeWindow = window
        } catch {
            // Handle and surface error to the user
            print("Redemption failed: \(error)")
        }
    }

    private func updateActiveWindow() {
        self.activeWindow = exemptionManager.getActiveWindow(for: childId)
    }
}
