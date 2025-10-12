import Foundation
import Combine
#if canImport(Core)
import Core
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class DeviceRoleManager: ObservableObject {
    @Published private(set) var deviceId: String
    @Published var deviceRole: DeviceRole?
    @Published var isRoleSet: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let pairingService: PairingService
    private let defaults: UserDefaults
    private let familyId: FamilyID

    private let roleDefaultsKey = "com.claudex.deviceRole"
    private let deviceIdDefaultsKey = "com.claudex.deviceId"

    init(
        pairingService: PairingService,
        defaults: UserDefaults = .standard,
        familyId: FamilyID = FamilyID("default-family")
    ) {
        self.pairingService = pairingService
        self.defaults = defaults
        self.familyId = familyId

        if let existingId = defaults.string(forKey: deviceIdDefaultsKey) {
            self.deviceId = existingId
        } else {
            let newId = DeviceRoleManager.generateDeviceIdentifier()
            self.deviceId = newId
            defaults.set(newId, forKey: deviceIdDefaultsKey)
        }
    }

    func loadDeviceRole() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        // Immediate check: if we already have a role cached in memory
        if deviceRole != nil {
            isRoleSet = true
            return
        }

        // Check if the device is already paired as a child locally
        if let childPairing = pairingService.getPairing(for: deviceId) {
            let payload = DevicePairingPayload(
                id: deviceId,
                childId: childPairing.childId,
                deviceId: deviceId,
                deviceName: DeviceRoleManager.currentDeviceName(),
                deviceRole: .child,
                pairedAt: childPairing.pairedAt,
                familyId: familyId
            )
            pairingService.updateCachedDevicePairing(payload)
            deviceRole = .child
            isRoleSet = true
            defaults.set(DeviceRole.child.rawValue, forKey: roleDefaultsKey)
            return
        }

        // Check cached pairing payload
        if let cachedRole = pairingService.cachedDeviceRole(for: deviceId) {
            deviceRole = cachedRole
            isRoleSet = true
            defaults.set(cachedRole.rawValue, forKey: roleDefaultsKey)
            return
        }

        // Check persisted defaults
        if let storedRole = defaults.string(forKey: roleDefaultsKey),
           let role = DeviceRole(rawValue: storedRole) {
            deviceRole = role
            isRoleSet = true
            return
        }

        // Fall back to CloudKit lookup
        await pairingService.refreshDevicePairingsFromCloud(familyId: familyId)
        if let remoteRole = pairingService.cachedDeviceRole(for: deviceId) {
            deviceRole = remoteRole
            isRoleSet = true
            defaults.set(remoteRole.rawValue, forKey: roleDefaultsKey)
        } else {
            isRoleSet = false
        }
    }

    func setDeviceRole(_ role: DeviceRole, childId: ChildID?) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        if role == .child && childId == nil {
            errorMessage = "A child must be selected for child devices."
            return
        }

        let payload = DevicePairingPayload(
            id: deviceId,
            childId: childId,
            deviceId: deviceId,
            deviceName: DeviceRoleManager.currentDeviceName(),
            deviceRole: role,
            pairedAt: Date(),
            familyId: familyId
        )

        do {
            try await pairingService.saveDevicePairing(payload, familyId: familyId)
            deviceRole = role
            isRoleSet = true
            defaults.set(role.rawValue, forKey: roleDefaultsKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetDeviceRole() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await pairingService.deleteDevicePairing(deviceId: deviceId, familyId: familyId)
        } catch {
            print("DeviceRoleManager: Failed to delete device pairing from CloudKit: \(error)")
        }

        pairingService.removeCachedDevicePairing(deviceId: deviceId)
        defaults.removeObject(forKey: roleDefaultsKey)
        deviceRole = nil
        isRoleSet = false
    }

    private static func generateDeviceIdentifier() -> String {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        return UUID().uuidString
        #endif
    }

    private static func currentDeviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "Unknown Device"
        #endif
    }
}
