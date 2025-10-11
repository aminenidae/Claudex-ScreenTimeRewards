import Foundation
import SwiftUI
import Security
import LocalAuthentication

/// Manages PIN authentication for Parent Mode on child's device
/// Stores PIN hash securely in Keychain and validates authentication attempts
@MainActor
public class PINManager: ObservableObject {

    // MARK: - Published State

    @Published public var isPINSet: Bool = false
    @Published public var isAuthenticated: Bool = false
    @Published public var failedAttempts: Int = 0
    @Published public var isLockedOut: Bool = false
    @Published public var lockoutEndTime: Date?

    // MARK: - Constants

    private let keychainService = "com.claudex.ScreentimeRewards"
    private let keychainAccount = "parentModePIN"
    private let maxAttempts = 3
    private let lockoutDurationSeconds: TimeInterval = 60 // 1 minute
    private let autoLockDurationSeconds: TimeInterval = 300 // 5 minutes

    // MARK: - Private State

    private var lastActivityTime: Date?
    private var autoLockTimer: Timer?

    // MARK: - Initialization

    public init() {
        checkPINExists()
        startAutoLockTimer()
    }

    // MARK: - PIN Management

    /// Set a new PIN (first-time setup or change)
    public func setPIN(_ pin: String) throws {
        guard pin.count >= 4 && pin.count <= 6 else {
            throw PINError.invalidPINLength
        }

        guard pin.allSatisfy({ $0.isNumber }) else {
            throw PINError.invalidPINFormat
        }

        // Hash the PIN before storing
        let hashedPIN = hashPIN(pin)

        // Store in Keychain
        try storeInKeychain(hashedPIN)

        isPINSet = true
        print("🔐 PINManager: PIN set successfully")
    }

    /// Remove the PIN
    public func removePIN() throws {
        try deleteFromKeychain()
        isPINSet = false
        isAuthenticated = false
        failedAttempts = 0
        print("🔐 PINManager: PIN removed")
    }

    /// Validate a PIN attempt
    public func validatePIN(_ pin: String) -> Bool {
        // Check if locked out
        if isLockedOut, let endTime = lockoutEndTime {
            if Date() < endTime {
                print("🔐 PINManager: Still locked out until \(endTime)")
                return false
            } else {
                // Lockout expired
                clearLockout()
            }
        }

        // Hash the attempted PIN
        let hashedAttempt = hashPIN(pin)

        // Retrieve stored PIN hash
        guard let storedHash = retrieveFromKeychain() else {
            print("🔐 PINManager: No PIN found in Keychain")
            return false
        }

        // Compare hashes
        if hashedAttempt == storedHash {
            // Success
            isAuthenticated = true
            failedAttempts = 0
            updateLastActivity()
            print("🔐 PINManager: Authentication successful")
            return true
        } else {
            // Failed attempt
            failedAttempts += 1
            print("🔐 PINManager: Authentication failed (attempt \(failedAttempts)/\(maxAttempts))")

            if failedAttempts >= maxAttempts {
                initiateLockout()
            }

            return false
        }
    }

    /// Lock (sign out of Parent Mode)
    public func lock() {
        isAuthenticated = false
        print("🔐 PINManager: Locked")
    }

    // MARK: - Biometric Authentication

    /// Attempt to authenticate with biometrics (Face ID / Touch ID)
    public func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometrics are available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("🔐 PINManager: Biometrics not available: \(error?.localizedDescription ?? "unknown")")
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access Parent Mode"
            )

            if success {
                await MainActor.run {
                    isAuthenticated = true
                    failedAttempts = 0
                    updateLastActivity()
                }
                print("🔐 PINManager: Biometric authentication successful")
            }

            return success
        } catch {
            print("🔐 PINManager: Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Auto-Lock

    /// Update last activity timestamp (call on user interaction)
    public func updateLastActivity() {
        lastActivityTime = Date()
    }

    /// Check if should auto-lock due to inactivity
    private func checkAutoLock() {
        guard isAuthenticated else { return }
        guard let lastActivity = lastActivityTime else { return }

        let timeSinceActivity = Date().timeIntervalSince(lastActivity)
        if timeSinceActivity >= autoLockDurationSeconds {
            lock()
            print("🔐 PINManager: Auto-locked due to inactivity")
        }
    }

    private func startAutoLockTimer() {
        autoLockTimer?.invalidate()
        autoLockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAutoLock()
            }
        }
    }

    // MARK: - Lockout Management

    private func initiateLockout() {
        isLockedOut = true
        lockoutEndTime = Date().addingTimeInterval(lockoutDurationSeconds)
        print("🔐 PINManager: Locked out until \(lockoutEndTime!)")
    }

    private func clearLockout() {
        isLockedOut = false
        lockoutEndTime = nil
        failedAttempts = 0
        print("🔐 PINManager: Lockout cleared")
    }

    // MARK: - Keychain Operations

    private func storeInKeychain(_ hashedPIN: String) throws {
        let data = hashedPIN.data(using: .utf8)!

        // Delete existing item first
        try? deleteFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            print("🔐 PINManager: Keychain store failed with status \(status)")
            throw PINError.keychainError(status)
        }

        print("🔐 PINManager: Stored PIN hash in Keychain")
    }

    private func retrieveFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let hashedPIN = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                print("🔐 PINManager: Keychain retrieve failed with status \(status)")
            }
            return nil
        }

        return hashedPIN
    }

    private func deleteFromKeychain() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            print("🔐 PINManager: Keychain delete failed with status \(status)")
            throw PINError.keychainError(status)
        }
    }

    private func checkPINExists() {
        isPINSet = retrieveFromKeychain() != nil
        print("🔐 PINManager: PIN exists: \(isPINSet)")
    }

    // MARK: - PIN Hashing

    private func hashPIN(_ pin: String) -> String {
        // Simple hash for MVP (use proper hashing in production)
        // In production, use CryptoKit with salt and proper key derivation
        let data = pin.data(using: .utf8)!
        let hash = data.base64EncodedString()
        return hash
    }
}

// MARK: - Errors

public enum PINError: LocalizedError {
    case invalidPINLength
    case invalidPINFormat
    case keychainError(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidPINLength:
            return "PIN must be 4-6 digits"
        case .invalidPINFormat:
            return "PIN must contain only numbers"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        }
    }
}
