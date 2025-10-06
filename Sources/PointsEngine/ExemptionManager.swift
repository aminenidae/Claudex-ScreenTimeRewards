import Foundation
#if canImport(Core)
import Core
#endif

public protocol ExemptionManagerProtocol {
    func startExemption(window: EarnedTimeWindow, onExpiry: @escaping () -> Void)
    func getActiveWindow(for childId: ChildID) -> EarnedTimeWindow?
    func extendExemption(for childId: ChildID, additionalSeconds: TimeInterval, maxTotalMinutes: Int) -> EarnedTimeWindow?
    func cancelExemption(for childId: ChildID)
    func restoreFromPersistence()
    func getAllActiveWindows() -> [EarnedTimeWindow]
}

public final class ExemptionManager: ExemptionManagerProtocol {
    private var activeWindows: [ChildID: EarnedTimeWindow] = [:]
    private var timers: [ChildID: Timer] = [:]
    private var expiryCallbacks: [ChildID: () -> Void] = [:]

    private let storageURL: URL
    private let policy: ExemptionStackingPolicy

    public init(
        policy: ExemptionStackingPolicy = .extend,
        storageURL: URL? = nil
    ) {
        self.policy = policy
        self.storageURL = storageURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("active_exemptions.json")
    }

    // MARK: - Exemption Management

    public func startExemption(window: EarnedTimeWindow, onExpiry: @escaping () -> Void) {
        // Cancel any existing timer
        cancelTimer(for: window.childId)

        // Store window and callback
        activeWindows[window.childId] = window
        expiryCallbacks[window.childId] = onExpiry

        // Schedule expiry timer
        scheduleExpiryTimer(for: window)

        // Persist state
        save()
    }

    public func getActiveWindow(for childId: ChildID) -> EarnedTimeWindow? {
        guard let window = activeWindows[childId] else {
            return nil
        }

        // Check if expired
        if window.isExpired {
            cancelExemption(for: childId)
            return nil
        }

        return window
    }

    public func extendExemption(
        for childId: ChildID,
        additionalSeconds: TimeInterval,
        maxTotalMinutes: Int
    ) -> EarnedTimeWindow? {
        guard let currentWindow = activeWindows[childId] else {
            return nil
        }

        let newDuration = currentWindow.durationSeconds + additionalSeconds
        let maxSeconds = TimeInterval(maxTotalMinutes * 60)

        // Enforce max cap
        let cappedDuration = min(newDuration, maxSeconds)

        // Create extended window with same start time
        let extendedWindow = EarnedTimeWindow(
            id: currentWindow.id,
            childId: childId,
            durationSeconds: cappedDuration,
            startTime: currentWindow.startTime
        )

        // Update active window
        activeWindows[childId] = extendedWindow

        // Reschedule timer
        if let callback = expiryCallbacks[childId] {
            cancelTimer(for: childId)
            scheduleExpiryTimer(for: extendedWindow)
        }

        save()
        return extendedWindow
    }

    public func cancelExemption(for childId: ChildID) {
        cancelTimer(for: childId)
        activeWindows[childId] = nil
        expiryCallbacks[childId] = nil
        save()
    }

    public func getAllActiveWindows() -> [EarnedTimeWindow] {
        Array(activeWindows.values)
    }

    // MARK: - Timer Management

    private func scheduleExpiryTimer(for window: EarnedTimeWindow) {
        let remaining = window.remainingSeconds

        guard remaining > 0 else {
            // Already expired, fire callback immediately
            if let callback = expiryCallbacks[window.childId] {
                callback()
            }
            activeWindows[window.childId] = nil
            expiryCallbacks[window.childId] = nil
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Fire callback
            if let callback = self.expiryCallbacks[window.childId] {
                callback()
            }

            // Clean up
            self.activeWindows[window.childId] = nil
            self.expiryCallbacks[window.childId] = nil
            self.timers[window.childId] = nil
            self.save()
        }

        timers[window.childId] = timer
    }

    private func cancelTimer(for childId: ChildID) {
        timers[childId]?.invalidate()
        timers[childId] = nil
    }

    // MARK: - Persistence

    public func save() {
        let windows = Array(activeWindows.values)
        guard let data = try? JSONEncoder().encode(windows) else {
            return
        }
        try? data.write(to: storageURL)
    }

    public func restoreFromPersistence() {
        guard let data = try? Data(contentsOf: storageURL),
              let windows = try? JSONDecoder().decode([EarnedTimeWindow].self, from: data) else {
            return
        }

        for window in windows {
            // Skip expired windows
            guard !window.isExpired else {
                continue
            }

            // Restore without callback (needs to be re-registered by caller)
            activeWindows[window.childId] = window
        }
    }

    // MARK: - Policy Handling

    public func canStartExemption(for childId: ChildID) -> Bool {
        switch policy {
        case .replace, .extend:
            return true
        case .queue:
            return true // Queue is always allowed
        case .block:
            return activeWindows[childId] == nil
        }
    }

    // MARK: - Cleanup

    deinit {
        for timer in timers.values {
            timer.invalidate()
        }
    }
}
