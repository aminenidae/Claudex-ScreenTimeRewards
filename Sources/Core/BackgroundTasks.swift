#if canImport(BackgroundTasks) && !os(macOS)
import Foundation
import BackgroundTasks

#if canImport(PointsEngine)
import PointsEngine
#else
protocol ExemptionManagerProtocol {}
protocol ShieldControllerProtocol {}
#endif

public enum BackgroundTaskIdentifier: String {
    case exemptionCheck = "com.claudex.app.exemptionCheck"
}

@available(iOS 16.0, *)
public class BackgroundTasks {
    public static let shared = BackgroundTasks()

    private var exemptionManager: ExemptionManagerProtocol?
    private var shieldController: ShieldControllerProtocol?

    public func configure(exemptionManager: ExemptionManagerProtocol, shieldController: ShieldControllerProtocol) {
        self.exemptionManager = exemptionManager
        self.shieldController = shieldController
    }

    public func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskIdentifier.exemptionCheck.rawValue, using: nil) { task in
            self.handleExemptionCheck(task: task as! BGAppRefreshTask)
        }
    }

    public func scheduleExemptionCheck() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskIdentifier.exemptionCheck.rawValue)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    private func handleExemptionCheck(task: BGAppRefreshTask) {
        scheduleExemptionCheck() // Reschedule for next time

        guard let exemptionManager = exemptionManager, let shieldController = shieldController else {
            task.setTaskCompleted(success: false)
            return
        }

        let activeWindows = exemptionManager.getAllActiveWindows()
        for window in activeWindows {
            if window.isExpired {
                shieldController.revokeExemption(for: window.childId)
            }
        }

        task.setTaskCompleted(success: true)
    }
}
#endif
