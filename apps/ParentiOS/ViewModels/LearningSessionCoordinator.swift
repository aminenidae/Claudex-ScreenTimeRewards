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
    private let configurationProvider: (ChildID, AppIdentifier?) -> PointsConfiguration

    private var cancellables = Set<AnyCancellable>()
    private var notificationTokens: [NSObjectProtocol] = []
    private var activeSessions: [ChildID: UsageSession] = [:]  // Legacy: global sessions
    private var activeAppSessions: [String: UsageSession] = [:]  // Key: "{childId}_{appId}"
    private var monitoredChildren: Set<ChildID> = []

    init(
        rulesManager: CategoryRulesManager,
        pointsEngine: PointsEngine,
        pointsLedger: PointsLedger,
        configurationProvider: @escaping (ChildID, AppIdentifier?) -> PointsConfiguration = { _, _ in .default }
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

        // End any lingering global session
        if let session = activeSessions[childId] {
            finalizeSession(session, endTime: Date())
            activeSessions[childId] = nil
        }

        // End all active app sessions for this child
        let sessionsToEnd = activeAppSessions.filter { key, _ in
            key.hasPrefix("\(childId.rawValue)_")
        }
        for (key, session) in sessionsToEnd {
            finalizeSession(session, endTime: Date())
            activeAppSessions[key] = nil
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

        // NEW: Per-app activity detection
        let appActivityToken = center.addObserver(forName: .appActivityDetected, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let childIdRaw = notification.userInfo?["childId"] as? String,
                  let appIdRaw = notification.userInfo?["appId"] as? String else { return }
            let childId = ChildID(childIdRaw)
            let appId = AppIdentifier(appIdRaw)
            self.beginAppSession(for: childId, appId: appId, startTime: Date())
        }

        notificationTokens = [startToken, endToken, thresholdToken, appActivityToken]
    }

    private func beginSession(for childId: ChildID, startTime: Date) {
        guard activeSessions[childId] == nil else { return }

        let config = configurationProvider(childId, nil)
        guard pointsEngine.canAccruePoints(childId: childId, appId: nil, config: config) else {
            return
        }

        var session = pointsEngine.startSession(childId: childId, appId: nil, at: startTime)
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
        let config = configurationProvider(session.childId, session.appId)
        var completed = session
        completed.endTime = endTime
        let result = pointsEngine.endSession(session: completed, config: config, at: endTime)
        if result.pointsEarned > 0 {
            _ = pointsLedger.recordAccrual(childId: session.childId, appId: session.appId, points: result.pointsEarned, timestamp: endTime)
        }
    }

    // MARK: - Per-App Session Management

    private func appSessionKey(childId: ChildID, appId: AppIdentifier) -> String {
        "\(childId.rawValue)_\(appId.rawValue)"
    }

    private func beginAppSession(for childId: ChildID, appId: AppIdentifier, startTime: Date) {
        let key = appSessionKey(childId: childId, appId: appId)

        // End existing session for this app if any
        if let existing = activeAppSessions[key] {
            finalizeSession(existing, endTime: startTime)
        }

        // Check if child can accrue points for this app
        let config = configurationProvider(childId, appId)
        guard pointsEngine.canAccruePoints(childId: childId, appId: appId, config: config) else {
            return
        }

        // Start new per-app session
        let session = pointsEngine.startSession(childId: childId, appId: appId, at: startTime)
        activeAppSessions[key] = session
        print("📱 LearningSessionCoordinator: Started session for child \(childId.rawValue), app \(appId.rawValue)")
    }

    private func touchAppSession(for childId: ChildID, appId: AppIdentifier, at time: Date) {
        let key = appSessionKey(childId: childId, appId: appId)
        guard let session = activeAppSessions[key] else { return }
        let updated = pointsEngine.updateActivity(session: session, at: time)
        activeAppSessions[key] = updated
    }

    private func endAppSession(for childId: ChildID, appId: AppIdentifier, endTime: Date) {
        let key = appSessionKey(childId: childId, appId: appId)
        guard let session = activeAppSessions[key] else { return }
        finalizeSession(session, endTime: endTime)
        activeAppSessions[key] = nil
        print("📱 LearningSessionCoordinator: Ended session for child \(childId.rawValue), app \(appId.rawValue)")
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
        configurationProvider: @escaping (ChildID, AppIdentifier?) -> PointsConfiguration = { _, _ in .default }
    ) {}
}
#endif
