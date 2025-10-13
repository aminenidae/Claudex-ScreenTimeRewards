import Foundation
#if canImport(Core)
import Core
#endif

@MainActor
final class PerAppConfigurationStore: ObservableObject {
    @Published private var pointsRules: [String: [String: PerAppPointsRule]] = [:] {
        didSet { persistIfNeeded() }
    }

    @Published private var rewardRules: [String: [String: PerAppRewardRule]] = [:] {
        didSet { persistIfNeeded() }
    }

    @Published private var rewardUsage: [String: [String: RewardUsage]] = [:] {
        didSet { persistIfNeeded() }
    }

    @Published private var appNames: [String: [String: String]] = [:] {
        didSet { persistIfNeeded() }
    }

    private let fileURL: URL
    private var isLoading = false

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.fileURL = documents.appendingPathComponent("per_app_configuration.json")
        }

        loadFromDisk()
    }

    // MARK: - Public Accessors

    func pointsRule(for childId: ChildID, appId: AppIdentifier) -> PerAppPointsRule {
        pointsRules[childId.rawValue]?[appId.rawValue] ?? .default
    }

    func updatePointsRule(childId: ChildID, appId: AppIdentifier, mutate: (inout PerAppPointsRule) -> Void) {
        var childRules = pointsRules[childId.rawValue] ?? [:]
        var rule = childRules[appId.rawValue] ?? .default
        mutate(&rule)
        rule.pointsPerMinute = max(1, rule.pointsPerMinute)
        rule.dailyCapPoints = max(rule.pointsPerMinute, rule.dailyCapPoints)
        childRules[appId.rawValue] = rule
        pointsRules[childId.rawValue] = childRules
    }

    func resetPointsRule(childId: ChildID, appId: AppIdentifier) {
        guard var childRules = pointsRules[childId.rawValue] else { return }
        childRules.removeValue(forKey: appId.rawValue)
        pointsRules[childId.rawValue] = childRules.isEmpty ? nil : childRules
    }

    func isUsingDefaultPointsRule(childId: ChildID, appId: AppIdentifier) -> Bool {
        pointsRules[childId.rawValue]?[appId.rawValue] == nil
    }

    func pointsAppIdentifiers(for childId: ChildID) -> [AppIdentifier] {
        guard let rules = pointsRules[childId.rawValue] else { return [] }
        return rules.keys.map { AppIdentifier($0) }
    }

    func pointsConfiguration(for childId: ChildID, appId: AppIdentifier?) -> PointsConfiguration {
        guard let appId else { return .default }
        let rule = pointsRule(for: childId, appId: appId)
        return PointsConfiguration(
            pointsPerMinute: rule.pointsPerMinute,
            dailyCapPoints: rule.dailyCapPoints,
            idleTimeoutSeconds: rule.idleTimeoutSeconds
        )
    }

    func rewardRule(for childId: ChildID, appId: AppIdentifier) -> PerAppRewardRule {
        rewardRules[childId.rawValue]?[appId.rawValue] ?? .default
    }

    func updateRewardRule(childId: ChildID, appId: AppIdentifier, mutate: (inout PerAppRewardRule) -> Void) {
        var childRules = rewardRules[childId.rawValue] ?? [:]
        var rule = childRules[appId.rawValue] ?? .default
        mutate(&rule)
        rule.pointsPerMinute = max(1, rule.pointsPerMinute)
        rule.minRedemptionPoints = max(0, rule.minRedemptionPoints)
        rule.maxRedemptionPoints = max(rule.minRedemptionPoints, rule.maxRedemptionPoints)
        childRules[appId.rawValue] = rule
        rewardRules[childId.rawValue] = childRules
    }

    func resetRewardRule(childId: ChildID, appId: AppIdentifier) {
        guard var childRules = rewardRules[childId.rawValue] else { return }
        childRules.removeValue(forKey: appId.rawValue)
        rewardRules[childId.rawValue] = childRules.isEmpty ? nil : childRules
    }

    func isUsingDefaultRewardRule(childId: ChildID, appId: AppIdentifier) -> Bool {
        rewardRules[childId.rawValue]?[appId.rawValue] == nil
    }

    func rewardAppIdentifiers(for childId: ChildID) -> [AppIdentifier] {
        var identifiers = Set<AppIdentifier>()
        if let rules = rewardRules[childId.rawValue] {
            identifiers.formUnion(rules.keys.map { AppIdentifier($0) })
        }
        if let usage = rewardUsage[childId.rawValue] {
            identifiers.formUnion(usage.keys.map { AppIdentifier($0) })
        }
        return Array(identifiers)
    }

    func rewardUsageMap(for childId: ChildID) -> [AppIdentifier: RewardUsage] {
        guard let usage = rewardUsage[childId.rawValue] else { return [:] }
        var mapped: [AppIdentifier: RewardUsage] = [:]
        for (key, value) in usage {
            mapped[AppIdentifier(key)] = value
        }
        return mapped
    }

    func redemptionConfiguration(for childId: ChildID, appId: AppIdentifier?) -> RedemptionConfiguration {
        guard let appId else { return .default }
        let rule = rewardRule(for: childId, appId: appId)
        return RedemptionConfiguration(
            pointsPerMinute: rule.pointsPerMinute,
            minRedemptionPoints: rule.minRedemptionPoints,
            maxRedemptionPoints: rule.maxRedemptionPoints,
            maxTotalMinutes: RedemptionConfiguration.default.maxTotalMinutes
        )
    }

    func stackingPolicy(for childId: ChildID, appId: AppIdentifier) -> ExemptionStackingPolicy {
        rewardRule(for: childId, appId: appId).stackingPolicy
    }

    func rewardUsage(for childId: ChildID, appId: AppIdentifier) -> RewardUsage {
        rewardUsage[childId.rawValue]?[appId.rawValue] ?? RewardUsage()
    }

    func recordRewardRedemption(childId: ChildID, appId: AppIdentifier, pointsSpent: Int) {
        var childUsage = rewardUsage[childId.rawValue] ?? [:]
        var usage = childUsage[appId.rawValue] ?? RewardUsage()
        usage.timesRedeemed += 1
        usage.pointsSpent += pointsSpent
        childUsage[appId.rawValue] = usage
        rewardUsage[childId.rawValue] = childUsage
    }

    func registerAppDisplayName(childId: ChildID, appId: AppIdentifier, name: String) {
        var childNames = appNames[childId.rawValue] ?? [:]
        childNames[appId.rawValue] = name
        appNames[childId.rawValue] = childNames
    }

    func displayName(childId: ChildID, appId: AppIdentifier) -> String? {
        appNames[childId.rawValue]?[appId.rawValue]
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        isLoading = true
        defer { isLoading = false }

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(PersistedConfiguration.self, from: data)
            pointsRules = decoded.pointsRules
            rewardRules = decoded.rewardRules
            rewardUsage = decoded.rewardUsage ?? [:]
            appNames = decoded.appNames ?? [:]
        } catch {
            print("PerAppConfigurationStore: Failed to load from disk - \(error)")
        }
    }

    private func persistIfNeeded() {
        guard !isLoading else { return }
        persist()
    }

    private func persist() {
        do {
            let payload = PersistedConfiguration(pointsRules: pointsRules, rewardRules: rewardRules, rewardUsage: rewardUsage, appNames: appNames)
            let data = try JSONEncoder().encode(payload)
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("PerAppConfigurationStore: Failed to persist - \(error)")
        }
    }
}

private struct PersistedConfiguration: Codable {
    var pointsRules: [String: [String: PerAppPointsRule]]
    var rewardRules: [String: [String: PerAppRewardRule]]
    var rewardUsage: [String: [String: RewardUsage]]?
    var appNames: [String: [String: String]]?
}

struct RewardUsage: Codable, Equatable {
    var timesRedeemed: Int = 0
    var pointsSpent: Int = 0
}
