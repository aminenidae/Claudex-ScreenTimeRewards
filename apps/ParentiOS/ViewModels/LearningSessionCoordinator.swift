#if canImport(DeviceActivity) && canImport(FamilyControls) && canImport(PointsEngine) && !os(macOS)
import Foundation
import Combine
import DeviceActivity
import FamilyControls
import PointsEngine
#if canImport(Core)
import Core
#endif

@available(iOS 16.0, *)
@MainActor
final class LearningSessionCoordinator: ObservableObject {
    private let rulesManager: CategoryRulesManager
    private let pointsEngine: PointsEngine
    private let pointsLedger: PointsLedger
    private let scheduleCoordinator = ActivityScheduleCoordinator()
    private let configurationProvider: (ChildID) -> PointsConfiguration

    private var cancellables = Set<AnyCancellable>()
    private var notificationTokens: [NSObjectProtocol] = []
    private var activeSessions: [ChildID: UsageSession] = [:]
    private var monitoredChildren: Set<ChildID> = []

    init(
        rulesManager: CategoryRulesManager,
        pointsEngine: PointsEngine,
        pointsLedger: PointsLedger,
        configurationProvider: @escaping (ChildID) -> PointsConfiguration = { _ in .default }
    ) {
        self.rulesManager = rulesManager
        self.pointsEngine = pointsEngine
        self.pointsLedger = pointsLedger
        self.configurationProvider = configurationProvider

        observeRuleChanges()
        observeActivityNotifications()
    }

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        scheduleCoordinator.stopAllMonitoring()
    }

    // MARK: - Rule Updates

    private func observeRuleChanges() {
        rulesManager.$childRules
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rules in
                self?.applyLearningSelections(rules)
            }
            .store(in: &cancellables)
    }

    private func applyLearningSelections(_ rules: [ChildID: ChildAppRules]) {
        let configuredChildren = Set(rules.keys)

        // Start/stop monitoring based on current selections
        for (childId, rule) in rules {
            let selection = rule.learningSelection
            if selection.isEmpty {
                stopMonitoring(childId: childId)
            } else {
                startMonitoring(childId: childId, selection: selection)
            }
        }

        // Stop monitoring children that no longer have rules
        let removedChildren = monitoredChildren.subtracting(configuredChildren)
        for childId in removedChildren {
            stopMonitoring(childId: childId)
        }
    }

    private func startMonitoring(childId: ChildID, selection: FamilyActivitySelection) {
        do {
            try scheduleCoordinator.startMonitoring(childId: childId, learningApps: selection)
            monitoredChildren.insert(childId)
        } catch {
            print("LearningSessionCoordinator: failed to start monitoring for \(childId.rawValue): \(error)")
        }
    }

    private func stopMonitoring(childId: ChildID) {
        scheduleCoordinator.stopMonitoring(childId: childId)
        monitoredChildren.remove(childId)

        // End any lingering session
        if let session = activeSessions[childId] {
            finalizeSession(session, endTime: Date())
        }
    }

    // MARK: - Activity Notifications

    private func observeActivityNotifications() {
        let center = NotificationCenter.default

        let startToken = center.addObserver(forName: .learningSessionDidStart, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let rawValue = notification.userInfo?["activity"] as? String else { return }
            let childId = ChildID(rawValue)
            self.beginSession(for: childId, startTime: Date())
        }

        let endToken = center.addObserver(forName: .learningSessionDidEnd, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let rawValue = notification.userInfo?["activity"] as? String else { return }
            let childId = ChildID(rawValue)
            self.endSession(for: childId, endTime: Date())
        }

        let thresholdToken = center.addObserver(forName: .activityThresholdReached, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let rawValue = notification.userInfo?["activity"] as? String else { return }
            let childId = ChildID(rawValue)
            // Treat threshold event as activity ping to avoid idle timeout
            self.touchSession(for: childId, at: Date())
        }

        notificationTokens = [startToken, endToken, thresholdToken]
    }

    private func beginSession(for childId: ChildID, startTime: Date) {
        guard activeSessions[childId] == nil else { return }

        let config = configurationProvider(childId)
        guard pointsEngine.canAccruePoints(childId: childId, config: config) else {
            return
        }

        var session = pointsEngine.startSession(childId: childId, at: startTime)
        session.lastActivityTime = startTime
        activeSessions[childId] = session
    }

    private func touchSession(for childId: ChildID, at time: Date) {
        guard let session = activeSessions[childId] else { return }
        let updated = pointsEngine.updateActivity(session: session, at: time)
        activeSessions[childId] = updated
    }

    private func endSession(for childId: ChildID, endTime: Date) {
        guard let session = activeSessions[childId] else { return }
        finalizeSession(session, endTime: endTime)
        activeSessions[childId] = nil
    }

    private func finalizeSession(_ session: UsageSession, endTime: Date) {
        let config = configurationProvider(session.childId)
        var completed = session
        completed.endTime = endTime
        let result = pointsEngine.endSession(session: completed, config: config, at: endTime)
        if result.pointsEarned > 0 {
            _ = pointsLedger.recordAccrual(childId: session.childId, points: result.pointsEarned, timestamp: endTime)
        }
    }
}

private extension FamilyActivitySelection {
    var isEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }
}
#endif

#if !(canImport(DeviceActivity) && canImport(FamilyControls) && canImport(PointsEngine)) || os(macOS)
import Foundation
#if canImport(Core)
import Core
#endif

@MainActor
final class LearningSessionCoordinator: ObservableObject {
    init(
        rulesManager: CategoryRulesManager,
        pointsEngine: Any,
        pointsLedger: Any,
        configurationProvider: @escaping (ChildID) -> PointsConfiguration = { _ in .default }
    ) {}
}
#endif
