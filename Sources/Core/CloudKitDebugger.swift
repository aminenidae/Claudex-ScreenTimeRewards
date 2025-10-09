import Foundation
import os
#if canImport(CloudKit)
import CloudKit
#endif

/// Operation categories for CloudKit debugging
public enum CloudKitOperationCategory: String, Codable {
    case family = "Family"
    case child = "Child"
    case appRule = "App Rule"
    case pairingCode = "Pairing"
    case sync = "Sync"
    case monitoring = "Monitoring"
    case general = "General"
}

/// Protocol for CloudKit debugging operations
public protocol CloudKitDebugging: AnyObject {
    var isMonitoring: Bool { get }
    var debugLogs: [DebugLogEntry] { get }

    func startMonitoring()
    func stopMonitoring()
    func logOperation(_ operation: String, details: String?, error: Error?)
    func logOperation(_ operation: String, category: CloudKitOperationCategory, details: String?, error: Error?)

    // Child operations
    func logChildAdded(childId: String, familyId: String)
    func logChildRemoved(childId: String, familyId: String)
    func logChildrenFetched(familyId: String, count: Int)

    // Pairing operations
    func logPairingCodeSaved(code: String, familyId: String)
    func logPairingCodeDeleted(code: String, familyId: String)
    func logPairingCodesFetched(familyId: String, count: Int)
    func logPairingCodeExpired(code: String)

    // App rule operations
    func logAppRuleSaved(ruleId: String, familyId: String, childId: String?)
    func logAppRulesFetched(familyId: String, childId: String?, count: Int)

    // Family operations
    func logFamilyFetched(familyId: String)
    func logFamilySaved(familyId: String)

    // Sync operations
    func logSyncStarted(token: String?)
    func logSyncCompleted(changesCount: Int, newToken: String?)
    func logSyncFailed(error: Error)

    func clearLogs()
}

/// A service to debug CloudKit operations for child management
@MainActor
public class CloudKitDebugger: ObservableObject, CloudKitDebugging {
    private let logger = Logger(subsystem: "com.claudex.screentimerewards", category: "CloudKitDebugger")
    
    @Published public private(set) var debugLogs: [DebugLogEntry] = []
    @Published public private(set) var isMonitoring = false
    
    public static let shared = CloudKitDebugger()
    
    // Make initializer public for testing
    public init() {}
    
    /// Start monitoring CloudKit operations
    public func startMonitoring() {
        isMonitoring = true
        logOperation("Monitoring Started", category: .monitoring, details: "CloudKit monitoring started", error: nil)
    }

    /// Stop monitoring CloudKit operations
    public func stopMonitoring() {
        isMonitoring = false
        logOperation("Monitoring Stopped", category: .monitoring, details: "CloudKit monitoring stopped", error: nil)
    }

    /// Log a CloudKit operation with automatic category detection
    public func logOperation(_ operation: String, details: String? = nil, error: Error? = nil) {
        logOperation(operation, category: .general, details: details, error: error)
    }

    /// Log a CloudKit operation with explicit category
    public func logOperation(_ operation: String, category: CloudKitOperationCategory, details: String? = nil, error: Error? = nil) {
        guard isMonitoring else { return }

        let entry = DebugLogEntry(
            timestamp: Date(),
            operation: operation,
            category: category,
            details: details,
            error: error?.localizedDescription
        )

        debugLogs.append(entry)
        logger.info("CloudKit [\(category.rawValue)] \(operation): \(details ?? "None"), Error: \(error?.localizedDescription ?? "None")")
    }

    // MARK: - Child Operations

    /// Log child addition
    public func logChildAdded(childId: String, familyId: String) {
        logOperation("Save Child", category: .child, details: "Child: \(childId), Family: \(familyId)", error: nil)
    }

    /// Log child removal
    public func logChildRemoved(childId: String, familyId: String) {
        logOperation("Delete Child", category: .child, details: "Child: \(childId), Family: \(familyId)", error: nil)
    }

    /// Log child fetch
    public func logChildrenFetched(familyId: String, count: Int) {
        logOperation("Fetch Children", category: .child, details: "Family: \(familyId), Count: \(count)", error: nil)
    }

    // MARK: - Pairing Operations

    public func logPairingCodeSaved(code: String, familyId: String) {
        logOperation("Save Pairing Code", category: .pairingCode, details: "Code: \(code), Family: \(familyId)", error: nil)
    }

    public func logPairingCodeDeleted(code: String, familyId: String) {
        logOperation("Delete Pairing Code", category: .pairingCode, details: "Code: \(code), Family: \(familyId)", error: nil)
    }

    public func logPairingCodesFetched(familyId: String, count: Int) {
        logOperation("Fetch Pairing Codes", category: .pairingCode, details: "Family: \(familyId), Count: \(count)", error: nil)
    }

    public func logPairingCodeExpired(code: String) {
        logOperation("Pairing Code Expired", category: .pairingCode, details: "Code: \(code)", error: nil)
    }

    // MARK: - App Rule Operations

    public func logAppRuleSaved(ruleId: String, familyId: String, childId: String?) {
        let childInfo = childId.map { ", Child: \($0)" } ?? ""
        logOperation("Save App Rule", category: .appRule, details: "Rule: \(ruleId), Family: \(familyId)\(childInfo)", error: nil)
    }

    public func logAppRulesFetched(familyId: String, childId: String?, count: Int) {
        let childInfo = childId.map { ", Child: \($0)" } ?? ""
        logOperation("Fetch App Rules", category: .appRule, details: "Family: \(familyId)\(childInfo), Count: \(count)", error: nil)
    }

    // MARK: - Family Operations

    public func logFamilyFetched(familyId: String) {
        logOperation("Fetch Family", category: .family, details: "Family: \(familyId)", error: nil)
    }

    public func logFamilySaved(familyId: String) {
        logOperation("Save Family", category: .family, details: "Family: \(familyId)", error: nil)
    }

    // MARK: - Sync Operations

    public func logSyncStarted(token: String?) {
        let tokenInfo = token.map { "Token: \($0)" } ?? "Initial sync"
        logOperation("Sync Started", category: .sync, details: tokenInfo, error: nil)
    }

    public func logSyncCompleted(changesCount: Int, newToken: String?) {
        let tokenInfo = newToken.map { ", New Token: \($0)" } ?? ""
        logOperation("Sync Completed", category: .sync, details: "Changes: \(changesCount)\(tokenInfo)", error: nil)
    }

    public func logSyncFailed(error: Error) {
        logOperation("Sync Failed", category: .sync, details: nil, error: error)
    }
    
    /// Clear all logs
    public func clearLogs() {
        debugLogs.removeAll()
    }
}

/// A no-op implementation for use in non-main actor contexts
public class NoOpCloudKitDebugger: CloudKitDebugging {
    public var isMonitoring: Bool { false }
    public var debugLogs: [DebugLogEntry] { [] }

    public init() {}

    public func startMonitoring() {}
    public func stopMonitoring() {}
    public func logOperation(_ operation: String, details: String?, error: Error?) {}
    public func logOperation(_ operation: String, category: CloudKitOperationCategory, details: String?, error: Error?) {}
    public func logChildAdded(childId: String, familyId: String) {}
    public func logChildRemoved(childId: String, familyId: String) {}
    public func logChildrenFetched(familyId: String, count: Int) {}
    public func logPairingCodeSaved(code: String, familyId: String) {}
    public func logPairingCodeDeleted(code: String, familyId: String) {}
    public func logPairingCodesFetched(familyId: String, count: Int) {}
    public func logPairingCodeExpired(code: String) {}
    public func logAppRuleSaved(ruleId: String, familyId: String, childId: String?) {}
    public func logAppRulesFetched(familyId: String, childId: String?, count: Int) {}
    public func logFamilyFetched(familyId: String) {}
    public func logFamilySaved(familyId: String) {}
    public func logSyncStarted(token: String?) {}
    public func logSyncCompleted(changesCount: Int, newToken: String?) {}
    public func logSyncFailed(error: Error) {}
    public func clearLogs() {}
}

// Nonisolated shared instance for use in non-main actor contexts
public nonisolated(unsafe) var cloudKitDebuggerShared: CloudKitDebugger {
    CloudKitDebugger.shared
}

/// Represents a debug log entry
public struct DebugLogEntry: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let operation: String
    public let category: CloudKitOperationCategory
    public let details: String?
    public let error: String?

    public init(timestamp: Date, operation: String, category: CloudKitOperationCategory = .general, details: String?, error: String?) {
        self.timestamp = timestamp
        self.operation = operation
        self.category = category
        self.details = details
        self.error = error
    }

    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        return formatter.string(from: timestamp)
    }

    public var hasError: Bool {
        error != nil
    }

    public var categoryColor: String {
        switch category {
        case .family: return "blue"
        case .child: return "green"
        case .appRule: return "orange"
        case .pairingCode: return "purple"
        case .sync: return "indigo"
        case .monitoring: return "gray"
        case .general: return "primary"
        }
    }
}