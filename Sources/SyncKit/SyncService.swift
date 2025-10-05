import Foundation
#if canImport(Core)
import Core
#endif

public protocol SyncServiceProtocol {
    func ping() -> Bool
}

public final class SyncService: SyncServiceProtocol {
    public init() {}
    public func ping() -> Bool { true }
}

