#if canImport(DeviceActivity) && !os(macOS)
import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
#if canImport(Core)
import Core
#endif

@available(iOS 16.0, *)
public final class LearningActivityMonitor: DeviceActivityMonitor {
    public override init() {
        super.init()
    }

    /// Called when a monitored activity interval starts
    public override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Start tracking session
        NotificationCenter.default.post(
            name: .learningSessionDidStart,
            object: nil,
            userInfo: ["activity": activity.rawValue]
        )
    }

    /// Called when a monitored activity interval ends
    public override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // End tracking session
        NotificationCenter.default.post(
            name: .learningSessionDidEnd,
            object: nil,
            userInfo: ["activity": activity.rawValue]
        )
    }

    /// Called when an event occurs during monitoring
    public override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        // Handle threshold events (e.g., daily cap reached)
        NotificationCenter.default.post(
            name: .activityThresholdReached,
            object: nil,
            userInfo: ["event": event.rawValue, "activity": activity.rawValue]
        )
    }
}

// MARK: - Notification Names
public extension Notification.Name {
    static let learningSessionDidStart = Notification.Name("learningSessionDidStart")
    static let learningSessionDidEnd = Notification.Name("learningSessionDidEnd")
    static let activityThresholdReached = Notification.Name("activityThresholdReached")
}

// MARK: - Activity Schedule Coordinator
@available(iOS 16.0, *)
public final class ActivityScheduleCoordinator {
    private let center = DeviceActivityCenter()

    public init() {}

    /// Start monitoring learning app usage for a child
    public func startMonitoring(
        childId: ChildID,
        learningApps: FamilyActivitySelection
    ) throws {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let activityName = DeviceActivityName(childId.rawValue)

        try center.startMonitoring(activityName, during: schedule)
    }

    /// Stop monitoring for a specific child
    public func stopMonitoring(childId: ChildID) {
        let activityName = DeviceActivityName(childId.rawValue)
        center.stopMonitoring([activityName])
    }

    /// Stop all monitoring
    public func stopAllMonitoring() {
        center.stopMonitoring()
    }
}
#endif
