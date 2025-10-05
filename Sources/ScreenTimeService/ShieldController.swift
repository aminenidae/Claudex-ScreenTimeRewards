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

@available(iOS 16.0, *)
public final class ShieldController: ShieldControllerProtocol {
    private var stores: [ChildID: ManagedSettingsStore] = [:]
    private var shieldConfigurations: [ChildID: FamilyActivitySelection] = [:]
    private var activeExemptions: Set<ChildID> = []

    public init() {}

    // MARK: - Store Management

    private func getStore(for childId: ChildID) -> ManagedSettingsStore {
        if let store = stores[childId] {
            return store
        }
        let store = ManagedSettingsStore()
        stores[childId] = store
        return store
    }

    // MARK: - Shield Application

    public func applyShields(for childId: ChildID, rewardApps: FamilyActivitySelection) {
        let store = getStore(for: childId)
        shieldConfigurations[childId] = rewardApps

        // Apply shields to reward apps
        store.shield.applications = rewardApps.applicationTokens
        store.shield.applicationCategories = .all(including: rewardApps.categoryTokens)
        store.shield.webDomains = rewardApps.webDomainTokens

        activeExemptions.remove(childId)
    }

    // MARK: - Exemption Management

    public func grantExemption(for childId: ChildID) {
        let store = getStore(for: childId)

        // Remove shields by clearing the selection
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil

        activeExemptions.insert(childId)
    }

    public func revokeExemption(for childId: ChildID) {
        // Re-apply previously configured shields
        guard let rewardApps = shieldConfigurations[childId] else {
            return
        }

        let store = getStore(for: childId)
        store.shield.applications = rewardApps.applicationTokens
        store.shield.applicationCategories = .all(including: rewardApps.categoryTokens)
        store.shield.webDomains = rewardApps.webDomainTokens

        activeExemptions.remove(childId)
    }

    public func isExemptionActive(for childId: ChildID) -> Bool {
        activeExemptions.contains(childId)
    }

    // MARK: - Clear All

    public func clearAllShields(for childId: ChildID) {
        let store = getStore(for: childId)
        store.clearAllSettings()
        shieldConfigurations[childId] = nil
        activeExemptions.remove(childId)
    }
}

#else

// Stub implementation for macOS or when ManagedSettings not available
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

public final class ShieldController: ShieldControllerProtocol {
    private var activeExemptions: Set<ChildID> = []

    public init() {}

    public func applyShields(for childId: ChildID, rewardApps: Any) {
        // Stub: No-op on macOS
        activeExemptions.remove(childId)
    }

    public func grantExemption(for childId: ChildID) {
        activeExemptions.insert(childId)
    }

    public func revokeExemption(for childId: ChildID) {
        activeExemptions.remove(childId)
    }

    public func isExemptionActive(for childId: ChildID) -> Bool {
        activeExemptions.contains(childId)
    }
}

#endif
