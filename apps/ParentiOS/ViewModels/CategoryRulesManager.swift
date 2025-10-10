import Foundation
import FamilyControls
import ManagedSettings
#if canImport(Core)
import Core
#endif
#if canImport(SyncKit)
import SyncKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Represents a conflict between learning and reward app classifications
struct AppConflict {
    let appToken: ApplicationToken
    let appName: String? // Optional, as we may not have access to app names
}

/// Manages app categorization rules (Learning vs Reward) per child
@MainActor
class CategoryRulesManager: ObservableObject {
    /// Rules for each child
    @Published private(set) var childRules: [ChildID: ChildAppRules] = [:]

    /// Storage location for persisted rules
    private let storageURL: URL

    /// CloudKit sync service (optional)
    #if canImport(SyncKit)
    private var syncService: SyncServiceProtocol?
    #endif

    /// Parent device ID for tracking who modified rules
    private let deviceId: String

    init(storageURL: URL? = nil, syncService: SyncServiceProtocol? = nil, deviceId: String? = nil) {
        // Default to Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = storageURL ?? documentsPath.appendingPathComponent("app-rules.json")

        #if canImport(SyncKit)
        self.syncService = syncService
        #endif

        // Use device identifier for tracking modifications
        #if canImport(UIKit)
        self.deviceId = deviceId ?? UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        #else
        self.deviceId = deviceId ?? "unknown"
        #endif

        // Load existing rules
        loadRules()
    }

    #if canImport(SyncKit)
    /// Set or update the sync service
    func setSyncService(_ service: SyncServiceProtocol) {
        self.syncService = service
        print("☁️ CategoryRulesManager: CloudKit sync service configured")
    }
    #endif

    // MARK: - Public API

    /// Get rules for a specific child
    func getRules(for childId: ChildID) -> ChildAppRules {
        if let existing = childRules[childId] {
            return existing
        }

        // Create default empty rules
        let newRules = ChildAppRules(childId: childId)
        childRules[childId] = newRules
        return newRules
    }

    /// Update learning apps selection for a child
    func updateLearningApps(for childId: ChildID, selection: FamilyActivitySelection) {
        print("📚 CategoryRulesManager: updateLearningApps called for child: \(childId.rawValue)")
        print("📚 Total application tokens: \(selection.applicationTokens.count)")
        print("📚 Total category tokens: \(selection.categoryTokens.count)")
        print("📚 Total web domain tokens: \(selection.webDomainTokens.count)")

        // Detailed logging of selected apps
        for (index, token) in selection.applicationTokens.enumerated() {
            let app = ManagedSettings.Application(token: token)
            let bundleId = app.bundleIdentifier ?? "unknown"
            let displayName = app.localizedDisplayName ?? "unknown"
            print("📚 App \(index + 1): \(displayName) (bundle: \(bundleId))")
        }

        // Log categories
        for (index, token) in selection.categoryTokens.enumerated() {
            print("📚 Category \(index + 1): \(token)")
        }

        var rules = getRules(for: childId)
        rules.learningSelection = selection
        childRules[childId] = rules
        print("📚 Saving \(selection.applicationTokens.count) learning apps + \(selection.categoryTokens.count) categories to local storage")
        saveRules()
        print("📚 ✅ Learning apps saved successfully")

        // Sync to CloudKit
        #if canImport(SyncKit)
        Task {
            do {
                try await syncToCloudKit(for: childId)
            } catch {
                print("❌ Failed to sync learning apps to CloudKit: \(error)")
            }
        }
        #endif
    }

    /// Update reward apps selection for a child
    func updateRewardApps(for childId: ChildID, selection: FamilyActivitySelection) {
        print("⭐ CategoryRulesManager: updateRewardApps called for child: \(childId.rawValue)")
        print("⭐ Total application tokens: \(selection.applicationTokens.count)")
        print("⭐ Total category tokens: \(selection.categoryTokens.count)")
        print("⭐ Total web domain tokens: \(selection.webDomainTokens.count)")

        // Detailed logging of selected apps
        for (index, token) in selection.applicationTokens.enumerated() {
            let app = ManagedSettings.Application(token: token)
            let bundleId = app.bundleIdentifier ?? "unknown"
            let displayName = app.localizedDisplayName ?? "unknown"
            print("⭐ App \(index + 1): \(displayName) (bundle: \(bundleId))")
        }

        // Log categories
        for (index, token) in selection.categoryTokens.enumerated() {
            print("⭐ Category \(index + 1): \(token)")
        }

        var rules = getRules(for: childId)
        rules.rewardSelection = selection
        childRules[childId] = rules
        print("⭐ Saving \(selection.applicationTokens.count) reward apps + \(selection.categoryTokens.count) categories to local storage")
        saveRules()
        print("⭐ ✅ Reward apps saved successfully")

        // Sync to CloudKit
        #if canImport(SyncKit)
        Task {
            do {
                try await syncToCloudKit(for: childId)
            } catch {
                print("❌ Failed to sync reward apps to CloudKit: \(error)")
            }
        }
        #endif
    }

    /// Check if an app token is classified as learning
    func isLearningApp(_ token: ApplicationToken, for childId: ChildID) -> Bool {
        let rules = getRules(for: childId)
        return rules.learningSelection.applicationTokens.contains(token)
    }

    /// Check if an app token is classified as reward
    func isRewardApp(_ token: ApplicationToken, for childId: ChildID) -> Bool {
        let rules = getRules(for: childId)
        return rules.rewardSelection.applicationTokens.contains(token)
    }

    /// Get summary of configured rules
    func getSummary(for childId: ChildID) -> RulesSummary {
        let rules = getRules(for: childId)
        let conflictCount = detectConflicts(for: childId).count
        
        return RulesSummary(
            learningAppsCount: rules.learningSelection.applicationTokens.count,
            learningCategoriesCount: rules.learningSelection.categoryTokens.count,
            rewardAppsCount: rules.rewardSelection.applicationTokens.count,
            rewardCategoriesCount: rules.rewardSelection.categoryTokens.count,
            conflictCount: conflictCount
        )
    }

    /// Detect conflicts between learning and reward app selections
    func detectConflicts(for childId: ChildID) -> [AppConflict] {
        let rules = getRules(for: childId)
        let learningApps = rules.learningSelection.applicationTokens
        let rewardApps = rules.rewardSelection.applicationTokens
        
        // Find intersection of learning and reward apps
        let conflictingApps = learningApps.intersection(rewardApps)
        
        return conflictingApps.map { token in
            AppConflict(appToken: token, appName: nil)
        }
    }

    /// Resolve conflicts by removing apps from one category
    /// - Parameters:
    ///   - childId: The child ID to resolve conflicts for
    ///   - keepLearning: If true, keep apps in learning and remove from reward. If false, keep in reward and remove from learning.
    func resolveConflicts(for childId: ChildID, keepLearning: Bool) {
        var rules = getRules(for: childId)
        let conflicts = detectConflicts(for: childId)
        
        if keepLearning {
            // Remove conflicting apps from reward selection
            var rewardSelection = rules.rewardSelection
            rewardSelection.applicationTokens.subtract(conflicts.map { $0.appToken })
            rules.rewardSelection = rewardSelection
        } else {
            // Remove conflicting apps from learning selection
            var learningSelection = rules.learningSelection
            learningSelection.applicationTokens.subtract(conflicts.map { $0.appToken })
            rules.learningSelection = learningSelection
        }
        
        childRules[childId] = rules
        saveRules()
    }

    // MARK: - CloudKit Sync

    #if canImport(SyncKit)
    /// Sync app rules to CloudKit for a specific child
    func syncToCloudKit(for childId: ChildID, familyId: FamilyID = FamilyID("default-family")) async throws {
        guard let syncService else {
            print("⚠️ CategoryRulesManager: No sync service configured, skipping CloudKit sync")
            return
        }

        print("☁️ CategoryRulesManager: Starting CloudKit sync for child: \(childId.rawValue)")
        let rules = getRules(for: childId)
        var uploadedCount = 0

        // Convert learning apps to AppRulePayload and upload
        for token in rules.learningSelection.applicationTokens {
            let tokenString = tokenToBase64(token)
            let ruleId = "\(childId.rawValue):\(tokenString.prefix(16))" // Use first 16 chars as ID suffix
            let payload = AppRulePayload(
                id: ruleId,
                childId: childId,
                appToken: tokenString,
                classification: .learning,
                isCategory: false,
                categoryId: nil,
                createdAt: Date(),
                modifiedAt: Date(),
                modifiedBy: deviceId
            )

            do {
                try await syncService.saveAppRule(payload, familyId: familyId)
                uploadedCount += 1
                print("☁️   Uploaded learning app rule: \(ruleId)")
            } catch {
                print("❌   Failed to upload learning app rule \(ruleId): \(error)")
            }
        }

        // Convert reward apps to AppRulePayload and upload
        for token in rules.rewardSelection.applicationTokens {
            let tokenString = tokenToBase64(token)
            let ruleId = "\(childId.rawValue):\(tokenString.prefix(16))"
            let payload = AppRulePayload(
                id: ruleId,
                childId: childId,
                appToken: tokenString,
                classification: .reward,
                isCategory: false,
                categoryId: nil,
                createdAt: Date(),
                modifiedAt: Date(),
                modifiedBy: deviceId
            )

            do {
                try await syncService.saveAppRule(payload, familyId: familyId)
                uploadedCount += 1
                print("☁️   Uploaded reward app rule: \(ruleId)")
            } catch {
                print("❌   Failed to upload reward app rule \(ruleId): \(error)")
            }
        }

        print("☁️ CategoryRulesManager: Uploaded \(uploadedCount) app rules to CloudKit")
    }

    /// Helper to convert ApplicationToken to base64 string
    private func tokenToBase64(_ token: ApplicationToken) -> String {
        let data = withUnsafeBytes(of: token) { Data($0) }
        return data.base64EncodedString()
    }

    /// Helper to convert base64 string back to ApplicationToken
    private func base64ToToken(_ base64: String) -> ApplicationToken? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return data.withUnsafeBytes { $0.load(as: ApplicationToken.self) }
    }
    #endif

    // MARK: - Persistence

    private func saveRules() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            // Convert to codable format
            let codableRules = childRules.mapValues { $0.toCodable() }
            let data = try encoder.encode(codableRules)
            try data.write(to: storageURL)
            print("💾 CategoryRulesManager: Saved rules for \(childRules.count) children to: \(storageURL.path)")
        } catch {
            print("❌ CategoryRulesManager: Failed to save app rules: \(error)")
        }
    }

    private func loadRules() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            print("📂 CategoryRulesManager: No existing rules file found at: \(storageURL.path)")
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let codableRules = try decoder.decode([ChildID: CodableChildAppRules].self, from: data)

            // Convert back to runtime format
            for (childId, codableRule) in codableRules {
                childRules[childId] = ChildAppRules(from: codableRule)
            }

            print("📂 CategoryRulesManager: Loaded rules for \(childRules.count) children from: \(storageURL.path)")
            for (childId, rules) in childRules {
                print("📂   Child: \(childId.rawValue)")
                print("📂     Learning: \(rules.learningSelection.applicationTokens.count) apps, \(rules.learningSelection.categoryTokens.count) categories")
                print("📂     Reward: \(rules.rewardSelection.applicationTokens.count) apps, \(rules.rewardSelection.categoryTokens.count) categories")
            }
        } catch {
            print("❌ CategoryRulesManager: Failed to load app rules: \(error)")
        }
    }
}

// MARK: - Data Models

/// App categorization rules for a single child
struct ChildAppRules {
    let childId: ChildID
    var learningSelection: FamilyActivitySelection  // Apps/categories that earn points
    var rewardSelection: FamilyActivitySelection    // Apps/categories that require points

    init(childId: ChildID,
         learningSelection: FamilyActivitySelection = FamilyActivitySelection(),
         rewardSelection: FamilyActivitySelection = FamilyActivitySelection()) {
        self.childId = childId
        self.learningSelection = learningSelection
        self.rewardSelection = rewardSelection
    }

    init(from codable: CodableChildAppRules) {
        self.childId = codable.childId
        self.learningSelection = codable.learningSelection.toFamilyActivitySelection()
        self.rewardSelection = codable.rewardSelection.toFamilyActivitySelection()
    }

    func toCodable() -> CodableChildAppRules {
        CodableChildAppRules(
            childId: childId,
            learningSelection: CodableFamilyActivitySelection(from: learningSelection),
            rewardSelection: CodableFamilyActivitySelection(from: rewardSelection)
        )
    }
}

/// Summary of configured rules for UI display
struct RulesSummary {
    let learningAppsCount: Int
    let learningCategoriesCount: Int
    let rewardAppsCount: Int
    let rewardCategoriesCount: Int
    let conflictCount: Int  // New property to track conflicts

    init(learningAppsCount: Int, learningCategoriesCount: Int, rewardAppsCount: Int, rewardCategoriesCount: Int, conflictCount: Int = 0) {
        self.learningAppsCount = learningAppsCount
        self.learningCategoriesCount = learningCategoriesCount
        self.rewardAppsCount = rewardAppsCount
        self.rewardCategoriesCount = rewardCategoriesCount
        self.conflictCount = conflictCount
    }

    var hasLearningRules: Bool {
        learningAppsCount > 0 || learningCategoriesCount > 0
    }

    var hasRewardRules: Bool {
        rewardAppsCount > 0 || rewardCategoriesCount > 0
    }

    var learningDescription: String {
        var parts: [String] = []
        if learningAppsCount > 0 {
            parts.append("\(learningAppsCount) app\(learningAppsCount == 1 ? "" : "s")")
        }
        if learningCategoriesCount > 0 {
            parts.append("\(learningCategoriesCount) categor\(learningCategoriesCount == 1 ? "y" : "ies")")
        }
        return parts.isEmpty ? "Not configured" : parts.joined(separator: ", ")
    }

    var rewardDescription: String {
        var parts: [String] = []
        if rewardAppsCount > 0 {
            parts.append("\(rewardAppsCount) app\(rewardAppsCount == 1 ? "" : "s")")
        }
        if rewardCategoriesCount > 0 {
            parts.append("\(rewardCategoriesCount) categor\(rewardCategoriesCount == 1 ? "y" : "ies")")
        }
        return parts.isEmpty ? "Not configured" : parts.joined(separator: ", ")
    }
    
    /// Check if there are conflicts between learning and reward rules
    var hasConflicts: Bool {
        conflictCount > 0
    }
}

// MARK: - Codable Wrappers (FamilyActivitySelection is not Codable)

struct CodableChildAppRules: Codable {
    let childId: ChildID
    let learningSelection: CodableFamilyActivitySelection
    let rewardSelection: CodableFamilyActivitySelection
}

struct CodableFamilyActivitySelection: Codable {
    let applicationTokenData: [Data]
    let categoryTokenData: [Data]
    let webDomainTokenData: [Data]

    init(from selection: FamilyActivitySelection) {
        // Store tokens as Data for persistence
        self.applicationTokenData = selection.applicationTokens.map { token in
            // FamilyControls tokens are opaque, store as-is
            withUnsafeBytes(of: token) { Data($0) }
        }
        self.categoryTokenData = selection.categoryTokens.map { token in
            withUnsafeBytes(of: token) { Data($0) }
        }
        self.webDomainTokenData = selection.webDomainTokens.map { token in
            withUnsafeBytes(of: token) { Data($0) }
        }
    }

    func toFamilyActivitySelection() -> FamilyActivitySelection {
        var selection = FamilyActivitySelection()

        // Reconstruct tokens from Data
        // Note: This is a simplified approach - in production, consider using
        // the includesEntireCategory flag and category-based storage
        selection.applicationTokens = Set(applicationTokenData.compactMap { data in
            data.withUnsafeBytes { $0.load(as: ApplicationToken.self) }
        })
        selection.categoryTokens = Set(categoryTokenData.compactMap { data in
            data.withUnsafeBytes { $0.load(as: ManagedSettings.ActivityCategoryToken.self) }
        })
        selection.webDomainTokens = Set(webDomainTokenData.compactMap { data in
            data.withUnsafeBytes { $0.load(as: ManagedSettings.WebDomainToken.self) }
        })

        return selection
    }
}
