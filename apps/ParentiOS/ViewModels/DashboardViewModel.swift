import Foundation
import Combine
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

enum ShieldState {
    case active
    case exempted
    case unknown
}

@MainActor
class DashboardViewModel: ObservableObject {
    // Published properties
    @Published var balance: Int = 0
    @Published var todayPoints: Int = 0
    @Published var todayLearningMinutes: Int = 0
    @Published var weekLearningMinutes: Int = 0
    @Published var recentRedemptions: [PointsLedgerEntry] = []
    @Published var activeWindow: EarnedTimeWindow?
    @Published var shieldState: ShieldState = .unknown
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Dependencies
    let ledger: PointsLedger
    let engine: PointsEngine
    let exemptionManager: ExemptionManager?
    let redemptionService: RedemptionServiceProtocol
    let childId: ChildID

    // Refresh timer
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(
        childId: ChildID,
        ledger: PointsLedger,
        engine: PointsEngine,
        exemptionManager: ExemptionManager? = nil,
        redemptionService: RedemptionServiceProtocol
    ) {
        self.childId = childId
        self.ledger = ledger
        self.engine = engine
        self.exemptionManager = exemptionManager
        self.redemptionService = redemptionService
    }

    // MARK: - Data Loading

    func refresh() {
        isLoading = true
        errorMessage = nil

        // Get balance
        balance = ledger.getBalance(childId: childId)

        // Get today's points
        todayPoints = ledger.getTodayAccrual(childId: childId)

        // Get today's learning time (approximate from points)
        let config = PointsConfiguration.default
        todayLearningMinutes = todayPoints / config.pointsPerMinute

        // Get week's learning time
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let weekEntries = ledger.getEntriesInRange(childId: childId, from: weekAgo, to: Date())
        let weekPoints = weekEntries.filter { $0.type == .accrual }.reduce(0) { $0 + $1.amount }
        weekLearningMinutes = weekPoints / config.pointsPerMinute

        // Get recent redemptions (last 10)
        let allEntries = ledger.getEntries(childId: childId, limit: 50)
        recentRedemptions = Array(allEntries.filter { $0.type == .redemption }.prefix(10))

        // Get active exemption window
        activeWindow = exemptionManager?.getActiveWindow(for: childId)

        // Update shield state
        if activeWindow != nil {
            shieldState = .exempted
        } else {
            shieldState = .active
        }

        isLoading = false
    }

    // MARK: - Auto Refresh

    func startAutoRefresh(interval: TimeInterval = 5.0) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Computed Properties

    var dailyCapProgress: Double {
        let cap = Double(PointsConfiguration.default.dailyCapPoints)
        guard cap > 0 else { return 0 }
        return min(Double(todayPoints) / cap, 1.0)
    }

    var hasActiveExemption: Bool {
        activeWindow != nil && !(activeWindow?.isExpired ?? true)
    }

    var remainingExemptionTime: String {
        guard let window = activeWindow, !window.isExpired else {
            return "No active time"
        }

        let remaining = Int(window.remainingSeconds)
        let minutes = remaining / 60
        let seconds = remaining % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    // MARK: - Redemption Actions

    func redeemMinimum() {
        let config = RedemptionConfiguration.default
        redeem(points: config.minRedemptionPoints, config: config)
    }

    private func redeem(points: Int, config: RedemptionConfiguration) {
        do {
            let _ = try redemptionService.redeem(childId: childId, points: points, config: config)
            refresh()
        } catch let error as RedemptionError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "An unknown error occurred."
        }
    }

    private func message(for error: RedemptionError) -> String {
        switch error {
        case .insufficientBalance(let available, let required):
            return "Need \(required) points, only \(available) available."
        case .belowMinimum(let points, let minimum):
            return "Redemptions require at least \(minimum) points (attempted \(points))."
        case .aboveMaximum(let points, let maximum):
            return "Cannot redeem more than \(maximum) points at once (attempted \(points))."
        case .childNotFound:
            return "Child profile unavailable."
        }
    }

    // MARK: - Cleanup

    deinit {
        refreshTimer?.invalidate()
    }
}

// MARK: - Mock for Previews

extension DashboardViewModel {
    static func mock(childId: ChildID = ChildID("preview-child")) -> DashboardViewModel {
        guard let appGroupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.claudex.ScreentimeRewards") else {
            fatalError("Failed to get app group container URL.")
        }
        let ledgerFileURL = appGroupContainerURL.appendingPathComponent("points_ledger.json")
        let auditLog = AuditLog()
        let ledger = PointsLedger(fileURL: ledgerFileURL, auditLog: auditLog)
        let engine = PointsEngine()
        let redemptionService = RedemptionService(ledger: ledger)

        // Add mock data
        _ = ledger.recordAccrual(childId: childId, points: 150, timestamp: Date())
        _ = ledger.recordRedemption(childId: childId, points: 50, timestamp: Date().addingTimeInterval(-3600))
        _ = ledger.recordAccrual(childId: childId, points: 100, timestamp: Date().addingTimeInterval(-7200))

        let vm = DashboardViewModel(childId: childId, ledger: ledger, engine: engine, redemptionService: redemptionService)
        vm.refresh()
        return vm
    }
}
