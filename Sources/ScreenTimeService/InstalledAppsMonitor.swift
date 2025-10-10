#if canImport(FamilyControls) && !os(macOS)
import Foundation
import FamilyControls
import ManagedSettings
#if canImport(Core)
import Core
#endif

/// Monitors installed apps on child device and syncs to CloudKit
@available(iOS 16.0, *)
public class InstalledAppsMonitor: ObservableObject {
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var appCount: Int = 0

    private let deviceId: String
    private var syncService: SyncServiceProtocol?

    public init(deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device") {
        self.deviceId = deviceId
    }

    /// Set or update the sync service
    public func setSyncService(_ service: SyncServiceProtocol?) {
        self.syncService = service
        print("📱 InstalledAppsMonitor: Sync service configured")
    }

    /// Fetch all installed apps using FamilyActivityPicker selection
    /// Note: This requires FamilyControls authorization
    public func fetchInstalledApps() -> FamilyActivitySelection {
        // In iOS 16+, we can't directly enumerate installed apps
        // Instead, we rely on what the user has selected via FamilyActivityPicker
        // This is a limitation of the FamilyControls framework

        // Return empty selection - apps must be discovered via picker
        // The actual inventory will be populated when rules are set
        return FamilyActivitySelection()
    }

    /// Sync child device's app inventory to CloudKit
    /// This should be called with the apps from category rules
    public func syncInstalledAppsToCloudKit(
        childId: ChildID,
        selection: FamilyActivitySelection,
        familyId: FamilyID = FamilyID("default-family")
    ) async throws {
        guard let syncService = syncService else {
            print("⚠️ InstalledAppsMonitor: No sync service configured, skipping CloudKit sync")
            return
        }

        print("📱 InstalledAppsMonitor: Starting CloudKit sync for child: \(childId.rawValue)")

        // Convert ApplicationTokens to base64 strings
        let appTokens = selection.applicationTokens.map { token in
            tokenToBase64(token)
        }

        // Convert CategoryTokens to base64 strings
        let categoryTokens = selection.categoryTokens.map { token in
            categoryTokenToBase64(token)
        }

        let inventoryId = "\(childId.rawValue):\(deviceId)"
        let payload = ChildAppInventoryPayload(
            id: inventoryId,
            childId: childId,
            deviceId: deviceId,
            appTokens: appTokens,
            categoryTokens: categoryTokens,
            lastUpdated: Date(),
            appCount: appTokens.count + categoryTokens.count
        )

        do {
            try await syncService.saveAppInventory(payload, familyId: familyId)
            await MainActor.run {
                self.lastSyncDate = Date()
                self.appCount = payload.appCount
            }
            print("📱 InstalledAppsMonitor: Successfully synced \(payload.appCount) items to CloudKit")
        } catch {
            print("❌ InstalledAppsMonitor: Failed to sync to CloudKit: \(error)")
            throw error
        }
    }

    /// Start periodic sync (every 24 hours)
    public func startPeriodicSync(
        childId: ChildID,
        selection: FamilyActivitySelection,
        familyId: FamilyID = FamilyID("default-family")
    ) {
        Task {
            // Initial sync
            try? await syncInstalledAppsToCloudKit(
                childId: childId,
                selection: selection,
                familyId: familyId
            )

            // Schedule periodic sync every 24 hours
            while true {
                try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000) // 24 hours
                try? await syncInstalledAppsToCloudKit(
                    childId: childId,
                    selection: selection,
                    familyId: familyId
                )
            }
        }
    }

    // MARK: - Token Conversion Helpers

    private func tokenToBase64(_ token: ApplicationToken) -> String {
        // ApplicationToken is opaque, so we use its description or hash
        // For now, we'll use a simple approach - convert to data and base64 encode
        let data = withUnsafeBytes(of: token) { Data($0) }
        return data.base64EncodedString()
    }

    private func categoryTokenToBase64(_ token: ActivityCategoryToken) -> String {
        // CategoryToken is also opaque
        let data = withUnsafeBytes(of: token) { Data($0) }
        return data.base64EncodedString()
    }
}

#else
// Stub for non-iOS platforms
@available(iOS 16.0, *)
public class InstalledAppsMonitor: ObservableObject {
    public init() {}

    public func setSyncService(_ service: Any?) {}
}
#endif
