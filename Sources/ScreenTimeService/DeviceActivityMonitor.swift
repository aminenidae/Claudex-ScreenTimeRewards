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
        NotificationCenter.default.post(
            name: .learningSessionDidStart,
            object: nil,
            userInfo: ["activity": activity.rawValue]
        )
    }

    /// Called when a monitored activity interval ends
    public override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        NotificationCenter.default.post(
            name: .learningSessionDidEnd,
            object: nil,
            userInfo: ["activity": activity.rawValue]
        )
    }

    /// Called when an event occurs during monitoring (per-app events)
    public override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        // Parse event name to extract app information
        if let (childId, appId) = ActivityEventName.parse(event) {
            // Per-app event: specific learning app was opened/used
            NotificationCenter.default.post(
                name: .appActivityDetected,
                object: nil,
                userInfo: [
                    "childId": childId.rawValue,
                    "appId": appId.rawValue,
                    "event": event.rawValue
                ]
            )
        } else {
            // Generic threshold event
            NotificationCenter.default.post(
                name: .activityThresholdReached,
                object: nil,
                userInfo: ["event": event.rawValue, "activity": activity.rawValue]
            )
        }
    }
}

// MARK: - Notification Names
public extension Notification.Name {
    static let learningSessionDidStart = Notification.Name("learningSessionDidStart")
    static let learningSessionDidEnd = Notification.Name("learningSessionDidEnd")
    static let activityThresholdReached = Notification.Name("activityThresholdReached")
    static let appActivityDetected = Notification.Name("appActivityDetected")
}

// MARK: - Activity Schedule Coordinator
@available(iOS 16.0, *)
public final class ActivityScheduleCoordinator {
    private let center = DeviceActivityCenter()

    public init() {}

    /// Start monitoring learning app usage for a child with per-app event tracking
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

        // Create events for each individual app to enable per-app tracking
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        for appToken in learningApps.applicationTokens {
            let appId = ApplicationTokenHelper.toAppIdentifier(appToken)
            let eventName = ActivityEventName.make(childId: childId, appId: appId)

            // Event fires when app is opened (threshold = 1 second)
            let event = DeviceActivityEvent(
                applications: [appToken],
                threshold: DateComponents(second: 1)
            )
            events[eventName] = event
        }

        // Also create interval-level events for session start/end
        try center.startMonitoring(activityName, during: schedule, events: events)
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

// MARK: - Activity Event Name Helper
@available(iOS 16.0, *)
public enum ActivityEventName {
    /// Create event name encoding childId and appId
    public static func make(childId: ChildID, appId: AppIdentifier) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("child_\(childId.rawValue)_app_\(appId.rawValue)")
    }

    /// Parse event name to extract childId and appId
    public static func parse(_ eventName: DeviceActivityEvent.Name) -> (childId: ChildID, appId: AppIdentifier)? {
        let raw = eventName.rawValue
        let prefix = "child_"
        let separator = "_app_"

        guard raw.hasPrefix(prefix) else { return nil }
        let afterPrefix = raw.dropFirst(prefix.count)

        guard let separatorRange = afterPrefix.range(of: separator) else { return nil }
        let childIdRaw = String(afterPrefix[..<separatorRange.lowerBound])
        let appIdRaw = String(afterPrefix[separatorRange.upperBound...])

        return (ChildID(childIdRaw), AppIdentifier(appIdRaw))
    }
}

// MARK: - ApplicationToken to AppIdentifier Helper
@available(iOS 16.0, *)
public enum ApplicationTokenHelper {
    /// Convert ApplicationToken to stable AppIdentifier using hash
    public static func toAppIdentifier(_ token: ApplicationToken) -> AppIdentifier {
        let data = withUnsafeBytes(of: token) { Data($0) }
        return AppIdentifier("app-\(hexString(from: data))")
    }

    /// Convert base64-encoded token string to AppIdentifier
    public static func toAppIdentifier(base64: String) -> AppIdentifier? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return AppIdentifier("app-\(hexString(from: data))")
    }

    private static func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
#endif
