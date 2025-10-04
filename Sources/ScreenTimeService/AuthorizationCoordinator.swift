#if canImport(FamilyControls)
import Foundation
import FamilyControls
import Combine

@available(iOS 16.0, *)
public enum ScreenTimeAuthorizationState: Equatable {
    case notDetermined
    case approved
    case denied
    case restricted
    case error(String)

    init(from status: AuthorizationCenter.AuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .approved: self = .approved
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default:
            self = .restricted
        }
    }
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
            state = ScreenTimeAuthorizationState(from: status)
        } catch {
            state = .error(String(describing: error))
        }
    }

    @MainActor
    public func requestAuthorization() async {
        do {
            try await authorizationCenter.requestAuthorization(for: .family)
            await refreshStatus()
        } catch {
            state = .error(error)
        }
    }
}
#endif
