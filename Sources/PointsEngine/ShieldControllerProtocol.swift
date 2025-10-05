#if canImport(ManagedSettings) && !os(macOS)
import Foundation
import ManagedSettings
import FamilyControls
#if canImport(Core)
import Core
#endif

@available(iOS 16.0, *)
public protocol ShieldControllerProtocol {
    func applyShields(for childId: ChildID, rewardApps: FamilyActivitySelection)
    func grantExemption(for childId: ChildID)
    func revokeExemption(for childId: ChildID)
    func isExemptionActive(for childId: ChildID) -> Bool
}

#else

import Foundation
#if canImport(Core)
import Core
#endif

public protocol ShieldControllerProtocol {
    func applyShields(for childId: ChildID, rewardApps: Any)
    func grantExemption(for childId: ChildID)
    func revokeExemption(for childId: ChildID)
    func isExemptionActive(for childId: ChildID) -> Bool
}

#endif
