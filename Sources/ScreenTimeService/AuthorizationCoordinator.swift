#if canImport(FamilyControls)
import Foundation
import FamilyControls
import Combine

@available(iOS 16.0, *)
public enum ScreenTimeAuthorizationState: Equatable {
    case notDetermined
    case approved
    case denied
    case error(String)
}

@available(iOS 16.0, *)
public final class ScreenTimeAuthorizationCoordinator: ObservableObject {
    @Published public private(set) var state: ScreenTimeAuthorizationState = .notDetermined
    private let authorizationCenter: AuthorizationCenter

    public init(authorizationCenter: AuthorizationCenter = .shared) {
        self.authorizationCenter = authorizationCenter
        Task { await refreshStatus() }
    }

    @MainActor
    public func refreshStatus() async {
        do {
            let status = await authorizationCenter.authorizationStatus
            switch status {
            case .notDetermined:
                state = .notDetermined
            case .approved:
                state = .approved
            case .denied:
                state = .denied
            @unknown default:
                state = .error("Unknown authorization status")
            }
        } catch {
            state = .error(String(describing: error))
        }
    }

    @MainActor
    public func requestAuthorization() async {
        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            await refreshStatus()
        } catch {
            state = .error(String(describing: error))
        }
    }
}
#endif
