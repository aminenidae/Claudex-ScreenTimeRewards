import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Pairing Models

/// A paired child device
public struct ChildDevicePairing: Codable, Equatable, Identifiable {
    public let id: String // deviceId
    public let childId: ChildID
    public let deviceId: String
    public let pairedAt: Date
    public let pairingCode: String // For audit trail

    public init(
        id: String? = nil,
        childId: ChildID,
        deviceId: String,
        pairedAt: Date = Date(),
        pairingCode: String
    ) {
        self.id = id ?? deviceId
        self.childId = childId
        self.deviceId = deviceId
        self.pairedAt = pairedAt
        self.pairingCode = pairingCode
    }
}

// MARK: - Pairing Notification

/// Notification sent when a child device is successfully paired
public struct PairingNotification: Codable {
    public let childId: ChildID
    public let deviceId: String
    public let pairedAt: Date
    public let deviceName: String
    
    public init(childId: ChildID, deviceId: String, pairedAt: Date, deviceName: String) {
        self.childId = childId
        self.deviceId = deviceId
        self.pairedAt = pairedAt
        self.deviceName = deviceName
    }
}

// MARK: - Pairing Errors

public enum PairingError: Error, LocalizedError {
    case invalidCode
    case codeExpired
    case codeAlreadyUsed
    case rateLimitExceeded
    case deviceAlreadyPaired
    case noPairingFound

    public var errorDescription: String? {
        switch self {
        case .invalidCode: return "Invalid pairing code"
        case .codeExpired: return "Pairing code has expired"
        case .codeAlreadyUsed: return "Pairing code has already been used"
        case .rateLimitExceeded: return "Too many pairing attempts. Please try again later."
        case .deviceAlreadyPaired: return "This device is already paired to a child"
        case .noPairingFound: return "No pairing found for this device"
        }
    }
}

// MARK: - Pairing Service Protocol

public protocol PairingServiceProtocol {
    /// Generate a new pairing code for a child
    func generatePairingCode(for childId: ChildID, ttlMinutes: Int) throws -> PairingCode

    /// Validate and consume a pairing code
    func consumePairingCode(_ code: String, deviceId: String) throws -> ChildDevicePairing

    /// Get active pairing for a device
    func getPairing(for deviceId: String) -> ChildDevicePairing?

    /// Revoke pairing for a device
    @discardableResult
    func revokePairing(for deviceId: String) throws -> ChildDevicePairing

    /// Delete the pairing code record from CloudKit if available
    func removePairingFromCloud(_ pairing: ChildDevicePairing, familyId: FamilyID) async

    /// Get all pairings for a child
    func getPairings(for childId: ChildID) -> [ChildDevicePairing]

    /// Get deep link URL for a pairing code
    func deepLinkURL(for code: PairingCode) -> URL

    /// Get the active (unused, unexpired) code for a child if one exists
    func activeCode(for childId: ChildID) -> PairingCode?
    
    /// Sync pairing codes with CloudKit
    func syncWithCloudKit(familyId: FamilyID) async throws
    
    /// Publishes notifications when pairing events occur
    var pairingNotifications: PassthroughSubject<PairingNotification, Never> { get }
}

// MARK: - Pairing Service Implementation

public final class PairingService: ObservableObject, PairingServiceProtocol {

    public static let localPairingDefaultsKey = "com.claudex.localPairing"

    // MARK: Properties

    // Make this public for debugging
    public private(set) var activeCodes: [String: PairingCode] = [:]
    private var pairings: [String: ChildDevicePairing] = [:] // deviceId -> pairing

    // Rate limiting: max 5 code generations per child per hour
    private var generationAttempts: [ChildID: [Date]] = [:]
    private let maxGenerationsPerHour = 5

    // Rate limiting: max 10 validation attempts per device per hour
    private var validationAttempts: [String: [Date]] = [:]
    private let maxValidationsPerHour = 10

    private let persistenceKey = "com.claudex.pairings"
    private let codesKey = "com.claudex.pairingCodes"
    private let generationKey = "com.claudex.pairingGenerationAttempts"
    private let validationKey = "com.claudex.pairingValidationAttempts"
    private let defaults: UserDefaults

    // Use a generic protocol instead of importing SyncKit directly
    // Make this public for debugging
    public private(set) var syncService: (any PairingSyncServiceProtocol)?

    // Notification publisher for pairing events
    public let pairingNotifications = PassthroughSubject<PairingNotification, Never>()
    @Published public var lastPairingNotification: PairingNotification?

    // MARK: Initialization

    public init(userDefaults: UserDefaults = .standard) {
        #if os(iOS)
        if let suiteDefaults = UserDefaults(suiteName: "group.com.claudex.screentimerewards") {
            self.defaults = suiteDefaults
            // Touch the suite once to convince cfprefsd to attach immediately
            suiteDefaults.set(true, forKey: "com.claudex.pairingService.bootstrap")
            suiteDefaults.removeObject(forKey: "com.claudex.pairingService.bootstrap")
        } else {
            print("PairingService: WARNING - Unable to access app group defaults; falling back to standard defaults")
            self.defaults = userDefaults
        }
        #else
        self.defaults = userDefaults
        #endif
        loadFromPersistence()
    }
    
    public func setSyncService(_ service: any PairingSyncServiceProtocol) {
        self.syncService = service
    }

    // MARK: Public Methods

    public func generatePairingCode(for childId: ChildID, ttlMinutes: Int = 15) throws -> PairingCode {
        // Check rate limit
        try checkGenerationRateLimit(for: childId)

        cleanupExpiredCodes()

        // Generate 6-digit code
        let code = generateRandomCode()

        // Ensure only one active code per child
        removeActiveCodes(for: childId)

        // Create pairing code
        let pairingCode = PairingCode(
            code: code,
            childId: childId,
            ttlMinutes: ttlMinutes
        )

        // Store active code
        notifyChange()
        activeCodes[code] = pairingCode

        // Record generation attempt
        recordGenerationAttempt(for: childId)

        // Persist
        saveToPersistence()

        return pairingCode
    }

    public func consumePairingCode(_ code: String, deviceId: String) throws -> ChildDevicePairing {
        print("PairingService: Attempting to consume pairing code: \(code) for deviceId: \(deviceId)")
        print("PairingService: Available codes: \(activeCodes.keys)")
        
        // Check rate limit
        try checkValidationRateLimit(for: deviceId)

        // Record validation attempt
        recordValidationAttempt(for: deviceId)

        // Find code
        guard let pairingCode = activeCodes[code] else {
            print("PairingService: Pairing code \(code) not found in active codes. Available codes: \(activeCodes.keys)")
            throw PairingError.invalidCode
        }

        // Validate code
        print("PairingService: Found code \(code) for child \(pairingCode.childId)")
        print("PairingService: Code status - expired: \(pairingCode.isExpired), used: \(pairingCode.isUsed), valid: \(pairingCode.isValid)")
        
        if pairingCode.isExpired {
            print("PairingService: Pairing code \(code) has expired. Code created at: \(pairingCode.createdAt), expires at: \(pairingCode.expiresAt), current time: \(Date())")
            throw PairingError.codeExpired
        }

        if pairingCode.isUsed {
            print("PairingService: Pairing code \(code) already used. Used at: \(String(describing: pairingCode.usedAt)), by device: \(String(describing: pairingCode.usedByDeviceId))")
            throw PairingError.codeAlreadyUsed
        }

        // Check if device already paired
        if pairings[deviceId] != nil {
            print("PairingService: Device \(deviceId) already paired to a child")
            throw PairingError.deviceAlreadyPaired
        }

        // Mark code as used
        notifyChange()
        activeCodes[code] = pairingCode.markingUsed(by: deviceId)
        print("PairingService: Marked code \(code) as used by device \(deviceId)")

        // Create pairing
        let pairing = ChildDevicePairing(
            childId: pairingCode.childId,
            deviceId: deviceId,
            pairingCode: code
        )
        print("PairingService: Created pairing for child \(pairing.childId) on device \(deviceId)")

        // Store pairing
        notifyChange()
        pairings[deviceId] = pairing
        print("PairingService: Stored pairing for device \(deviceId)")

        // Send notification to parent
        let deviceName = getDeviceName()
        let notification = PairingNotification(
            childId: pairing.childId,
            deviceId: deviceId,
            pairedAt: Date(),
            deviceName: deviceName
        )
        pairingNotifications.send(notification)
        lastPairingNotification = notification
        print("PairingService: Sent pairing notification for device \(deviceId)")

        // Persist
        saveToPersistence()
        print("PairingService: Saved pairing to persistence")

        // Immediately sync the updated code back to CloudKit to ensure other devices can see the pairing
        if let syncService = syncService {
            Task.detached {
                do {
                    print("PairingService: Saving updated pairing code \(code) to CloudKit")
                    try await syncService.savePairingCode(pairingCode.markingUsed(by: deviceId), familyId: FamilyID("default-family"))
                    print("PairingService: Successfully saved updated pairing code to CloudKit")
                } catch {
                    print("PairingService: Failed to save updated pairing code to CloudKit: \(error)")
                }
            }
        }

        print("PairingService: Successfully paired device \(deviceId) to child \(pairingCode.childId)")
        return pairing
    }

    public func getPairing(for deviceId: String) -> ChildDevicePairing? {
        return pairings[deviceId]
    }

    @discardableResult
    public func revokePairing(for deviceId: String) throws -> ChildDevicePairing {
        print("PairingService: Attempting to revoke pairing for deviceId: \(deviceId)")
        guard let pairing = pairings[deviceId] else {
            print("PairingService: No pairing found for deviceId: \(deviceId)")
            throw PairingError.noPairingFound
        }

        notifyChange()
        pairings.removeValue(forKey: deviceId)
        // Remove the associated code (used codes stay pruned to avoid unnecessary uploads)
        activeCodes.removeValue(forKey: pairing.pairingCode)
        saveToPersistence()
        print("PairingService: Pairing successfully revoked for deviceId: \(deviceId)")
        return pairing
    }

    public func removePairingFromCloud(_ pairing: ChildDevicePairing, familyId: FamilyID) async {
        guard let syncService else {
            print("PairingService: No sync service configured; skipping CloudKit unlink for code \(pairing.pairingCode)")
            return
        }

        do {
            try await syncService.deletePairingCode(pairing.pairingCode, familyId: familyId)
        } catch {
            print("PairingService: Failed to delete pairing code \(pairing.pairingCode) from CloudKit: \(error)")
        }
    }

    public func getPairings(for childId: ChildID) -> [ChildDevicePairing] {
        return pairings.values.filter { $0.childId == childId }
    }

    public func deepLinkURL(for code: PairingCode) -> URL {
        return URL(string: "claudex://pair/\(code.code)")!
    }

    public func activeCode(for childId: ChildID) -> PairingCode? {
        return activeCodes.values.first { $0.childId == childId && !$0.isExpired }
    }
    
    public func syncWithCloudKit(familyId: FamilyID) async throws {
        guard let syncService = syncService else {
            print("PairingService: Sync service not available")
            return
        }
        
        print("PairingService: Starting sync with CloudKit for family: \(familyId)")
        // Log start time for performance monitoring
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform CloudKit operations on a background task
        let cloudCodes = try await Task.detached {
            print("PairingService: Fetching pairing codes from CloudKit on background task")
            let codes = try await syncService.fetchPairingCodes(familyId: familyId)
            let endTime = CFAbsoluteTimeGetCurrent()
            print("PairingService: CloudKit fetch completed in \(endTime - startTime)s")
            return codes
        }.value
        print("PairingService: Retrieved \(cloudCodes.count) pairing codes from CloudKit")
        
        var addedCount = 0
        var uploadedCount = 0
        var skippedCount = 0
        
        // Merge cloud codes with local codes
        for code in cloudCodes {
            print("PairingService: Processing cloud code \(code.code) for child \(code.childId)")
            print("PairingService: Code validity - expired: \(code.isExpired), used: \(code.isUsed), valid: \(code.isValid)")
            
            // Update UI-related properties on the main actor
            await MainActor.run {
                if self.activeCodes[code.code] == nil {
                    if code.isValid {
                        self.activeCodes[code.code] = code
                        print("PairingService: Added pairing code from CloudKit: \(code.code) for child: \(code.childId)")
                        addedCount += 1
                    } else {
                        print("PairingService: Skipped invalid cloud code \(code.code) (expired: \(code.isExpired), used: \(code.isUsed))")
                        skippedCount += 1
                    }
                } else {
                    print("PairingService: Cloud code \(code.code) already exists locally")
                    // Update local code if cloud version is newer
                    if let localCode = self.activeCodes[code.code] {
                        if code.createdAt > localCode.createdAt {
                            self.activeCodes[code.code] = code
                            print("PairingService: Updated local code \(code.code) with newer cloud version")
                        }
                    }
                }
            }
        }
        
        // Upload any local codes that aren't in CloudKit
        print("PairingService: Checking \(self.activeCodes.count) local codes for upload to CloudKit")
        
        // Create a copy of activeCodes to avoid modifying while iterating
        let codesToProcess = await MainActor.run { self.activeCodes }
        
        for (codeKey, code) in codesToProcess {
            print("PairingService: Processing local code \(codeKey) for child \(code.childId)")
            print("PairingService: Code validity - expired: \(code.isExpired), used: \(code.isUsed), valid: \(code.isValid)")

            if code.isUsed || !code.isExpired {
                do {
                    // Log start time for save operation
                    let saveStartTime = CFAbsoluteTimeGetCurrent()
                    try await Task.detached {
                        print("PairingService: Saving pairing code \(code.code) to CloudKit on background task")
                        try await syncService.savePairingCode(code, familyId: familyId)
                        let saveEndTime = CFAbsoluteTimeGetCurrent()
                        print("PairingService: CloudKit save completed in \(saveEndTime - saveStartTime)s")
                    }.value
                    print("PairingService: Uploaded pairing code to CloudKit: \(code.code)")
                    uploadedCount += 1
                } catch {
                    print("PairingService: Failed to upload pairing code \(code.code) to CloudKit: \(error)")
                }
            } else {
                print("PairingService: Skipped local code \(code.code) (expired without use)")
                skippedCount += 1
            }
        }

        // Reconcile pairings on the main actor
        await MainActor.run {
            self.reconcilePairingsFromCodes()
        }

        // Save to persistence on the main actor
        await MainActor.run {
            self.saveToPersistence()
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        print("PairingService: Sync complete for family \(familyId): Added \(addedCount) codes from CloudKit, uploaded \(uploadedCount) codes to CloudKit, skipped \(skippedCount) invalid codes. Total time: \(totalTime)s")
        print("PairingService: Total active codes: \(self.activeCodes.count)")
    }

    private func reconcilePairingsFromCodes() {
        var updatedPairings = pairings
        var didChange = false

        for code in activeCodes.values {
            guard code.isUsed, let deviceId = code.usedByDeviceId else { continue }
            let pairing = ChildDevicePairing(
                childId: code.childId,
                deviceId: deviceId,
                pairedAt: code.usedAt ?? code.createdAt,
                pairingCode: code.code
            )

            if updatedPairings[deviceId] != pairing {
                updatedPairings[deviceId] = pairing
                didChange = true
            }
        }

        if didChange {
            pairings = updatedPairings
            notifyChange()
        }
    }

    // MARK: Private Helpers

    private func generateRandomCode() -> String {
        // Generate 6-digit code
        var candidate: String
        repeat {
            candidate = String(Int.random(in: 100000...999999))
        } while activeCodes[candidate] != nil
        return candidate
    }

    private func checkGenerationRateLimit(for childId: ChildID) throws {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let recentAttempts = generationAttempts[childId]?.filter { $0 > oneHourAgo } ?? []

        if recentAttempts.count >= maxGenerationsPerHour {
            throw PairingError.rateLimitExceeded
        }
    }

    private func recordGenerationAttempt(for childId: ChildID) {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        var attempts = generationAttempts[childId]?.filter { $0 > oneHourAgo } ?? []
        attempts.append(Date())
        generationAttempts[childId] = attempts
    }

    private func checkValidationRateLimit(for deviceId: String) throws {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let recentAttempts = validationAttempts[deviceId]?.filter { $0 > oneHourAgo } ?? []

        if recentAttempts.count >= maxValidationsPerHour {
            throw PairingError.rateLimitExceeded
        }
    }

    private func recordValidationAttempt(for deviceId: String) {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        var attempts = validationAttempts[deviceId]?.filter { $0 > oneHourAgo } ?? []
        attempts.append(Date())
        validationAttempts[deviceId] = attempts
    }

    // MARK: Persistence

    private func saveToPersistence() {
        // Save pairings
        if let encoded = try? JSONEncoder().encode(Array(pairings.values)) {
            defaults.set(encoded, forKey: persistenceKey)
        }

        // Save active codes
        if let encoded = try? JSONEncoder().encode(Array(activeCodes.values)) {
            defaults.set(encoded, forKey: codesKey)
        }

        if let encoded = try? JSONEncoder().encode(serializeAttempts(generationAttempts)) {
            defaults.set(encoded, forKey: generationKey)
        }

        if let encoded = try? JSONEncoder().encode(validationAttempts) {
            defaults.set(encoded, forKey: validationKey)
        }
    }

    private func loadFromPersistence() {
        // Load pairings
        if let data = defaults.data(forKey: persistenceKey),
           let decoded = try? JSONDecoder().decode([ChildDevicePairing].self, from: data) {
            pairings = Dictionary(uniqueKeysWithValues: decoded.map { ($0.deviceId, $0) })
        }

        // Load active codes
        if let data = defaults.data(forKey: codesKey),
           let decoded = try? JSONDecoder().decode([PairingCode].self, from: data) {
            activeCodes = Dictionary(uniqueKeysWithValues: decoded.map { ($0.code, $0) })
        }

        if let data = defaults.data(forKey: generationKey),
           let decoded = try? JSONDecoder().decode([String: [Date]].self, from: data) {
            generationAttempts = deserializeGenerationAttempts(decoded)
        }

        if let data = defaults.data(forKey: validationKey),
           let decoded = try? JSONDecoder().decode([String: [Date]].self, from: data) {
            validationAttempts = decoded
        }

        // Clean up expired codes
        cleanupExpiredCodes()
    }

    private func cleanupExpiredCodes() {
        notifyChange()
        activeCodes = activeCodes.filter { _, code in
            !code.isExpired
        }
        saveToPersistence()
    }

    private func removeActiveCodes(for childId: ChildID) {
        if activeCodes.values.contains(where: { $0.childId == childId }) {
            notifyChange()
            activeCodes = activeCodes.filter { _, value in
                value.childId != childId
            }
        }
    }

    private func serializeAttempts(_ attempts: [ChildID: [Date]]) -> [String: [Date]] {
        Dictionary(uniqueKeysWithValues: attempts.map { ($0.key.rawValue, $0.value) })
    }

    private func deserializeGenerationAttempts(_ attempts: [String: [Date]]) -> [ChildID: [Date]] {
        Dictionary(uniqueKeysWithValues: attempts.map { (ChildID($0.key), $0.value) })
    }

    private func notifyChange() {
        objectWillChange.send()
    }
    
    private func getDeviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "Unknown Device"
        #endif
    }
}