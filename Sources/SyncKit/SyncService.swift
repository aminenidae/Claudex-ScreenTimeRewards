import Foundation

public protocol SyncServiceProtocol {
    func ping() -> Bool
}

public final class SyncService: SyncServiceProtocol {
    public init() {}
    public func ping() -> Bool { true }
}

