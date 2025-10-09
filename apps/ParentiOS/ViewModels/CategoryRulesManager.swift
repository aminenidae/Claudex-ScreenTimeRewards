import Foundation
import FamilyControls
import ManagedSettings
#if canImport(Core)
import Core
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

    init(storageURL: URL? = nil) {
        // Default to Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = storageURL ?? documentsPath.appendingPathComponent("app-rules.json")

        // Load existing rules
        loadRules()
    }

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
        // Logging block to see what comes out of the picker
        let apps = selection.applicationTokens.map { token -> (String?, String?) in
            let app = ManagedSettings.Application(token: token)
            return (app.bundleIdentifier, app.localizedDisplayName)
        }
        print("Learning selection tokens:", apps)
        
        var rules = getRules(for: childId)
        rules.learningSelection = selection
        childRules[childId] = rules
        saveRules()
    }

    /// Update reward apps selection for a child
    func updateRewardApps(for childId: ChildID, selection: FamilyActivitySelection) {
        // Logging block to see what comes out of the picker
        let apps = selection.applicationTokens.map { token -> (String?, String?) in
            let app = ManagedSettings.Application(token: token)
            return (app.bundleIdentifier, app.localizedDisplayName)
        }
        print("Reward selection tokens:", apps)
        
        var rules = getRules(for: childId)
        rules.rewardSelection = selection
        childRules[childId] = rules
        saveRules()
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

    // MARK: - Persistence

    private func saveRules() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            // Convert to codable format
            let codableRules = childRules.mapValues { $0.toCodable() }
            let data = try encoder.encode(codableRules)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save app rules: \(error)")
        }
    }

    private func loadRules() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
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
        } catch {
            print("Failed to load app rules: \(error)")
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
