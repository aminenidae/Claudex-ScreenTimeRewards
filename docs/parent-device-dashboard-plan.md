# Parent Device Dashboard Simplification Plan

**Context:** Post-architectural pivot, the parent's device becomes a read-only monitoring dashboard. Configuration UI is removed and moved to the child's device.

**Reference:** docs/ADR-001-child-device-configuration.md

---

## Overview

**Goal:** Simplify parent device to focus on monitoring, oversight, and data management. Remove all configuration UI that requires ApplicationTokens.

**Why:** ApplicationTokens from parent's device don't work on child's device. Parent device becomes a monitoring dashboard that reads configuration from CloudKit (written by child device).

**Architecture:**
```
Parent Device App
├── Child Profile Management
│   ├── Add children (Apple system UI)
│   ├── Generate pairing codes
│   └── View pairing status
├── Dashboard (Read-Only Monitoring) ⭐ PRIMARY FOCUS
│   ├── Points balance per child
│   ├── Learning time statistics
│   ├── Redemption history
│   ├── Active shield status
│   └── Configuration summary (synced from child)
├── Data Management
│   ├── Export data (CSV/JSON)
│   ├── Manual point adjustments
│   └── Audit log viewing
└── Settings
    ├── Family management
    └── Parent account settings
```

---

## Phase 1: Remove Configuration UI

### 1.1 Remove App Categorization

**Current:** `ParentModeView` has "Settings" tab with `AppCategorizationView`

**Changes:**
```swift
// BEFORE
TabView {
    MultiChildDashboardView()
        .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

    ExportView(...)
        .tabItem { Label("Export", systemImage: "square.and.arrow.up") }

    AppCategorizationView() // ← REMOVE THIS
        .tabItem { Label("Settings", systemImage: "gear") }
}

// AFTER
TabView {
    MultiChildDashboardView()
        .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

    ExportView(...)
        .tabItem { Label("Export", systemImage: "square.and.arrow.up") }

    ParentSettingsView() // ← REPLACE WITH SIMPLIFIED SETTINGS
        .tabItem { Label("Settings", systemImage: "gear") }
}
```

**Rationale:** App categorization now happens on child's device. Parent can view category summary in dashboard, but cannot change it.

### 1.2 Replace with Configuration Summary

**New Component: `ConfigurationSummaryView`**

```swift
@available(iOS 16.0, *)
struct ConfigurationSummaryView: View {
    let childId: ChildID
    @EnvironmentObject private var syncService: SyncService

    @State private var learningCount: Int = 0
    @State private var rewardCount: Int = 0
    @State private var pointsConfig: PointsConfiguration?
    @State private var redemptionConfig: RedemptionConfiguration?
    @State private var lastConfigUpdate: Date?

    var body: some View {
        List {
            Section("App Categories") {
                HStack {
                    Label("Learning Apps", systemImage: "graduationcap.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(learningCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Reward Apps", systemImage: "star.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(rewardCount)")
                        .foregroundStyle(.secondary)
                }

                if let lastUpdate = lastConfigUpdate {
                    Text("Last updated: \(formattedDate(lastUpdate))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Section("Points Settings") {
                if let config = pointsConfig {
                    HStack {
                        Text("Points per minute")
                        Spacer()
                        Text("\(config.pointsPerMinute)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Daily cap")
                        Spacer()
                        Text("\(config.dailyCapPoints)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Idle timeout")
                        Spacer()
                        Text("\(Int(config.idleTimeoutSeconds / 60)) min")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Redemption Rules") {
                if let config = redemptionConfig {
                    HStack {
                        Text("Points per minute")
                        Spacer()
                        Text("\(config.pointsPerMinute)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Min redemption")
                        Spacer()
                        Text("\(config.minRedemptionPoints) pts")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Max redemption")
                        Spacer()
                        Text("\(config.maxRedemptionPoints) pts")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("These settings are configured on your child's device (Parent Mode). Changes sync automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Configuration")
        .task {
            await fetchConfiguration()
        }
        .refreshable {
            await fetchConfiguration()
        }
    }

    private func fetchConfiguration() async {
        // Fetch from CloudKit (child device writes, parent reads)
        // TODO: Implement CloudKit fetch
    }
}
```

---

## Phase 2: Enhance Dashboard

### 2.1 Add Configuration Card to Dashboard

**Current Dashboard Cards:**
1. Points Balance
2. Learning Time Today
3. Recent Redemptions
4. Active Shields
5. Weekly Summary

**Add New Card:**
6. Configuration Summary (read-only)

**New Component: `ConfigurationCard`**

```swift
@available(iOS 16.0, *)
struct ConfigurationCard: View {
    let childName: String
    let learningCount: Int
    let rewardCount: Int
    let lastConfigUpdate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gear.circle.fill")
                    .foregroundStyle(.blue)
                Text("Configuration")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ConfigurationSummaryView(childId: childId)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("\(learningCount) learning app\(learningCount == 1 ? "" : "s")")
                        .font(.subheadline)
                }

                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("\(rewardCount) reward app\(rewardCount == 1 ? "" : "s")")
                        .font(.subheadline)
                }
            }

            if let lastUpdate = lastConfigUpdate {
                Divider()
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                    Text("Last updated \(formattedDate(lastUpdate))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "iphone")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("Settings are configured on \(childName)'s device (Parent Mode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
```

### 2.2 Add Setup Instruction Card (First-Time)

**Show when child is paired but no configuration exists:**

```swift
@available(iOS 16.0, *)
struct SetupInstructionCard: View {
    let childName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("Setup Required")
                    .font(.headline)
            }

            Text("To complete setup, open the app on \(childName)'s device:")
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("1.")
                        .fontWeight(.semibold)
                    Text("Tap 'Parent Mode' and enter your PIN")
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("2.")
                        .fontWeight(.semibold)
                    Text("Select which apps are Learning vs Reward")
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("3.")
                        .fontWeight(.semibold)
                    Text("Configure points and redemption rules")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Why? Apple's privacy protections require app settings to be configured on the device where apps are installed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
```

---

## Phase 3: Update Settings Tab

### 3.1 Simplified Parent Settings

**New Component: `ParentSettingsView`**

```swift
@available(iOS 16.0, *)
struct ParentSettingsView: View {
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var pairingService: PairingService

    var body: some View {
        NavigationStack {
            List {
                Section("Family Management") {
                    NavigationLink {
                        ManageChildrenView(childrenManager: childrenManager)
                    } label: {
                        Label("Manage Children", systemImage: "person.2.fill")
                    }

                    NavigationLink {
                        PairingManagementView()
                    } label: {
                        Label("Device Pairing", systemImage: "link")
                    }
                }

                Section("Data Management") {
                    NavigationLink {
                        ExportView(
                            childId: childrenManager.selectedChildId ?? ChildID("unknown"),
                            ledger: childrenManager.ledger
                        )
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }

                    NavigationLink {
                        AuditLogView()
                    } label: {
                        Label("Audit Log", systemImage: "list.bullet.clipboard")
                    }
                }

                Section("App Configuration") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("App settings are configured on your child's device")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        // Show instruction modal
                    } label: {
                        Label("How to Configure Apps", systemImage: "questionmark.circle")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

---

## Phase 4: Manual Point Adjustments (Keep)

### 4.1 Point Adjustment UI (Existing, Keep)

**Component:** Already exists in dashboard or can be added

```swift
@available(iOS 16.0, *)
struct ManualPointAdjustmentView: View {
    let childId: ChildID
    @EnvironmentObject private var ledger: PointsLedger

    @State private var adjustmentAmount: Int = 0
    @State private var reason: String = ""
    @State private var showingConfirmation = false

    var body: some View {
        Form {
            Section("Adjustment") {
                Stepper("Amount: \(adjustmentAmount >= 0 ? "+" : "")\(adjustmentAmount)",
                        value: $adjustmentAmount, in: -1000...1000, step: 10)

                TextField("Reason (optional)", text: $reason)
            }

            Section("Current Balance") {
                HStack {
                    Text("Current")
                    Spacer()
                    Text("\(ledger.getBalance(childId: childId)) pts")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("After adjustment")
                    Spacer()
                    Text("\(ledger.getBalance(childId: childId) + adjustmentAmount) pts")
                        .foregroundStyle(adjustmentAmount >= 0 ? .green : .orange)
                        .fontWeight(.semibold)
                }
            }

            Button("Apply Adjustment") {
                showingConfirmation = true
            }
            .disabled(adjustmentAmount == 0)
        }
        .navigationTitle("Adjust Points")
        .alert("Confirm Adjustment", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                applyAdjustment()
            }
        } message: {
            Text("Apply \(adjustmentAmount >= 0 ? "+" : "")\(adjustmentAmount) points to balance?")
        }
    }

    private func applyAdjustment() {
        _ = ledger.recordAdjustment(
            childId: childId,
            points: adjustmentAmount,
            reason: reason.isEmpty ? "Manual adjustment" : reason,
            timestamp: Date()
        )
        // TODO: Sync to CloudKit
    }
}
```

**Why Keep This:**
- Point adjustments are parent-driven overrides
- Don't require ApplicationTokens
- Parent can add/subtract points remotely

---

## Phase 5: CloudKit Sync Updates

### 5.1 Read-Only Configuration Sync

**Parent Device:**
```swift
// Fetch configuration written by child device
func fetchChildConfiguration(childId: ChildID) async throws -> ChildConfiguration {
    let pointsConfig = try await syncService.fetchPointsConfiguration(childId: childId)
    let redemptionConfig = try await syncService.fetchRedemptionConfiguration(childId: childId)
    let appRules = try await syncService.fetchAppRules(familyId: familyId, childId: childId)

    return ChildConfiguration(
        pointsConfig: pointsConfig,
        redemptionConfig: redemptionConfig,
        learningAppCount: appRules.filter { $0.classification == .learning }.count,
        rewardAppCount: appRules.filter { $0.classification == .reward }.count,
        lastUpdated: appRules.map { $0.modifiedAt }.max() ?? Date()
    )
}
```

**Display in Dashboard:**
- Auto-refresh every 30 seconds
- Pull-to-refresh gesture
- Show last sync time

### 5.2 Write Point Adjustments

**Parent Device:**
```swift
// Parent can still write point adjustments
func applyPointAdjustment(childId: ChildID, amount: Int, reason: String) async throws {
    let entry = ledger.recordAdjustment(
        childId: childId,
        points: amount,
        reason: reason,
        timestamp: Date()
    )

    // Sync to CloudKit
    try await syncService.savePointsLedgerEntry(entry, familyId: familyId)
}
```

**Child Device:**
- Reads point adjustments from CloudKit
- Updates local balance
- Reflects in child mode UI

---

## Phase 6: User Education

### 6.1 In-App Guidance

**First-Time Setup Modal:**
```swift
@available(iOS 16.0, *)
struct SetupGuidanceView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "iphone.and.iphone")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Two-Device Setup")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 16) {
                    SetupStep(
                        number: 1,
                        title: "Parent Device (This Device)",
                        description: "Add children and monitor their progress"
                    )

                    SetupStep(
                        number: 2,
                        title: "Child Device",
                        description: "Configure app categories and rules (Parent Mode with PIN)"
                    )

                    SetupStep(
                        number: 3,
                        title: "CloudKit Sync",
                        description: "Changes sync automatically between devices"
                    )
                }
                .padding()

                Button("Got It") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct SetupStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

---

## Implementation Checklist

**Phase 1: Remove Configuration UI**
- [ ] Remove AppCategorizationView from ParentModeView tabs
- [ ] Create ConfigurationSummaryView (read-only)
- [ ] Add "configured on child's device" messaging

**Phase 2: Enhance Dashboard**
- [ ] Create ConfigurationCard component
- [ ] Add ConfigurationCard to MultiChildDashboardView
- [ ] Create SetupInstructionCard (show when no config exists)
- [ ] Add auto-refresh for configuration sync

**Phase 3: Update Settings**
- [ ] Create simplified ParentSettingsView
- [ ] Add "How to Configure Apps" guide
- [ ] Keep family management features
- [ ] Keep data export features

**Phase 4: Manual Adjustments**
- [ ] Keep ManualPointAdjustmentView
- [ ] Ensure point adjustments sync to CloudKit
- [ ] Add to dashboard or settings

**Phase 5: CloudKit Sync**
- [ ] Implement fetchChildConfiguration()
- [ ] Add PointsConfiguration CloudKit read
- [ ] Add RedemptionConfiguration CloudKit read
- [ ] Parent writes point adjustments only

**Phase 6: User Education**
- [ ] Create SetupGuidanceView modal
- [ ] Show on first launch
- [ ] Add "How It Works" button in settings
- [ ] Update in-app help text

---

## Files to Modify

**Modified Files:**
- `apps/ParentiOS/Views/ParentModeView.swift` (remove AppCategorizationView tab)
- `apps/ParentiOS/Views/MultiChildDashboardView.swift` (add ConfigurationCard)
- `apps/ParentiOS/ViewModels/DashboardViewModel.swift` (add configuration fetch)

**New Files:**
- `apps/ParentiOS/Views/ConfigurationSummaryView.swift`
- `apps/ParentiOS/Views/ConfigurationCard.swift`
- `apps/ParentiOS/Views/SetupInstructionCard.swift`
- `apps/ParentiOS/Views/ParentSettingsView.swift`
- `apps/ParentiOS/Views/SetupGuidanceView.swift`
- `apps/ParentiOS/Views/ManualPointAdjustmentView.swift` (if doesn't exist)

---

## Success Criteria

✅ Parent device no longer has app categorization UI
✅ Dashboard shows configuration summary (read-only)
✅ Configuration syncs from child device within 2 seconds
✅ Parent can still make manual point adjustments
✅ Setup instructions clearly explain two-device requirement
✅ In-app help guides users through setup process
