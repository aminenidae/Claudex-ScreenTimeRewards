import Foundation

public protocol ScreenTimeServiceProtocol {
    func isAuthorized() -> Bool
}

public final class ScreenTimeService: ScreenTimeServiceProtocol {
    public init() {}
    public func isAuthorized() -> Bool { false }
}

