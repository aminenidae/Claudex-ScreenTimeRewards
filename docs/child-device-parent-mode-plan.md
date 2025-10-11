# Child Device Parent Mode Implementation Plan

**Context:** Post-architectural pivot, the child's device becomes the primary configuration point for all app-specific settings. This document outlines the implementation of PIN-protected Parent Mode on the child's device.

**Reference:** docs/ADR-001-child-device-configuration.md

---

## Overview

**Goal:** Move all configuration UI from parent device to child device, protected by PIN authentication.

**Why:** ApplicationTokens are device-specific. Configuration must happen on the same device where apps will be shielded for tokens to work correctly.

**Architecture:**
```
Child Device App
├── Mode Selection (Entry Point)
│   ├── Child Mode (default)
│   └── Parent Mode (requires PIN)
├── Parent Mode (PIN-Protected) ⭐ NEW
│   ├── App Categorization
│   ├── Points Configuration
│   ├── Redemption Rules
│   └── Settings
└── Child Mode (Existing)
    ├── Points Balance
    ├── Redemption Requests
    └── Activity History
```

---

## Phase 1: PIN Authentication System

### 1.1 PIN Storage & Validation

**Components:**
- `PINManager` service (stores/validates PIN)
- Keychain integration for secure storage
- Optional biometric fallback (Face ID/Touch ID)

**Implementation:**
```swift
@MainActor
class PINManager: ObservableObject {
    @Published var isPINSet: Bool = false
    @Published var isAuthenticated: Bool = false

    func setPIN(_ pin: String) async throws
    func validatePIN(_ pin: String) async -> Bool
    func removePIN() async throws
    func authenticateWithBiometrics() async -> Bool
}
```

**Storage:**
- Store PIN hash in Keychain (never plaintext)
- Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Support 4-6 digit PINs

**Security:**
- Rate limiting (3 attempts, then 1-minute lockout)
- Auto-lock after 5 minutes of inactivity
- Require re-authentication for sensitive operations

### 1.2 PIN Setup Flow

**First-Time Setup:**
1. After child device pairing completes
2. Show "Setup Parent PIN" prompt
3. Parent enters PIN (twice for confirmation)
4. Option to enable biometrics
5. Store PIN hash in Keychain

**UI Components:**
- `PINSetupView` - Initial PIN creation
- `PINEntryView` - Authentication prompt
- `PINSettingsView` - Change/remove PIN

---

## Phase 2: Parent Mode UI on Child Device

### 2.1 Mode Selection Update

**Current State:**
```swift
// ClaudexApp.swift - Mode selection screen
NavigationStack {
    ModeSelectionView()
        .environmentObject(childrenManager)
}
```

**Updated State:**
```swift
// Add PINManager to environment
@StateObject private var pinManager = PINManager()

NavigationStack {
    if pinManager.isAuthenticated {
        ChildDeviceParentModeView() // NEW
            .environmentObject(childrenManager)
            .environmentObject(pinManager)
    } else {
        ModeSelectionView()
            .environmentObject(childrenManager)
            .environmentObject(pinManager)
    }
}
```

### 2.2 Parent Mode Entry Point

**New Component: `ChildDeviceParentModeView`**

```swift
@available(iOS 16.0, *)
struct ChildDeviceParentModeView: View {
    @EnvironmentObject private var childrenManager: ChildrenManager
    @EnvironmentObject private var rulesManager: CategoryRulesManager
    @EnvironmentObject private var pinManager: PINManager

    var body: some View {
        TabView {
            // Tab 1: App Categorization (moved from parent device)
            AppCategorizationView()
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }

            // Tab 2: Points Configuration
            PointsConfigurationView()
                .tabItem { Label("Points", systemImage: "star.fill") }

            // Tab 3: Redemption Rules
            RedemptionRulesView()
                .tabItem { Label("Rewards", systemImage: "gift.fill") }

            // Tab 4: Settings
            ParentSettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .navigationTitle("Parent Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Lock") {
                    pinManager.isAuthenticated = false
                }
            }
        }
    }
}
```

---

## Phase 3: Move Configuration UIs

### 3.1 App Categorization (Existing → Move)

**Source:** `apps/ParentiOS/Views/AppCategorizationView.swift`
**Destination:** Keep in same file, but now accessed from child device

**Changes Needed:**
- ✅ Already uses local FamilyActivityPicker (no changes needed!)
- ✅ Already syncs to CloudKit (child writes, parent reads)
- ✅ Remove privacy-preserving inventory card (not needed on child device)
- ✅ Update instructions to explain "You're configuring apps on this device"

**Key Insight:** This view already works correctly! It uses local ApplicationTokens from FamilyActivityPicker, which is exactly what we need.

### 3.2 Points Configuration (New View)

**Component:** `PointsConfigurationView`

**UI Elements:**
```swift
struct PointsConfigurationView: View {
    @EnvironmentObject private var pointsEngine: LearningSessionCoordinator
    @State private var pointsPerMinute: Int = 10
    @State private var dailyCapPoints: Int = 600
    @State private var idleTimeoutSeconds: TimeInterval = 180

    var body: some View {
        Form {
            Section("Point Accrual") {
                Stepper("Points per minute: \(pointsPerMinute)",
                        value: $pointsPerMinute, in: 1...50)

                Stepper("Daily cap: \(dailyCapPoints)",
                        value: $dailyCapPoints, in: 100...2000, step: 50)

                Picker("Idle timeout", selection: $idleTimeoutSeconds) {
                    Text("1 minute").tag(TimeInterval(60))
                    Text("3 minutes").tag(TimeInterval(180))
                    Text("5 minutes").tag(TimeInterval(300))
                    Text("10 minutes").tag(TimeInterval(600))
                }
            }

            Section("Info") {
                Text("Children earn points for using learning apps. Points stop accruing after idle timeout.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Points Configuration")
    }
}
```

### 3.3 Redemption Rules (New View)

**Component:** `RedemptionRulesView`

**UI Elements:**
```swift
struct RedemptionRulesView: View {
    @State private var pointsPerMinute: Int = 10
    @State private var minRedemptionPoints: Int = 30
    @State private var maxRedemptionPoints: Int = 600
    @State private var stackingPolicy: ExemptionStackingPolicy = .extend

    var body: some View {
        Form {
            Section("Redemption Rates") {
                Stepper("Points per minute: \(pointsPerMinute)",
                        value: $pointsPerMinute, in: 1...50)

                Stepper("Minimum redemption: \(minRedemptionPoints)",
                        value: $minRedemptionPoints, in: 10...100, step: 10)

                Stepper("Maximum redemption: \(maxRedemptionPoints)",
                        value: $maxRedemptionPoints, in: 100...1000, step: 50)
            }

            Section("Stacking Policy") {
                Picker("When redeeming during active time", selection: $stackingPolicy) {
                    Text("Replace current time").tag(ExemptionStackingPolicy.replace)
                    Text("Extend current time").tag(ExemptionStackingPolicy.extend)
                    Text("Queue for later").tag(ExemptionStackingPolicy.queue)
                    Text("Block until expired").tag(ExemptionStackingPolicy.block)
                }
            }

            Section("Preview") {
                Text("\(minRedemptionPoints) points = \(minRedemptionPoints / pointsPerMinute) minutes")
                Text("\(maxRedemptionPoints) points = \(maxRedemptionPoints / pointsPerMinute) minutes")
            }
        }
        .navigationTitle("Redemption Rules")
    }
}
```

---

## Phase 4: CloudKit Sync Updates

### 4.1 Configuration Sync Direction

**Child Device (Writer):**
- Writes AppRule records (app categorization)
- Writes PointsConfiguration record (rates, caps, timeouts)
- Writes RedemptionConfiguration record (ratios, limits, stacking)
- Writes to CloudKit on every configuration change

**Parent Device (Reader):**
- Reads configuration records from CloudKit
- Displays in dashboard (read-only)
- Can write PointsLedgerEntry (manual adjustments)

### 4.2 New CloudKit Records

**PointsConfiguration Record:**
```swift
// Already exists in Core/AppModels.swift!
public struct PointsConfiguration: Codable {
    public let pointsPerMinute: Int
    public let dailyCapPoints: Int
    public let idleTimeoutSeconds: TimeInterval
}
```

**RedemptionConfiguration Record:**
```swift
// Already exists in Core/AppModels.swift!
public struct RedemptionConfiguration: Codable {
    public let pointsPerMinute: Int
    public let minRedemptionPoints: Int
    public let maxRedemptionPoints: Int
    public let maxTotalMinutes: Int
}
```

**CloudKit Schema:**
- Add `PointsConfiguration` record type
- Add `RedemptionConfiguration` record type
- Both reference `childId` (one record per child)
- Auto-sync on UI changes

---

## Phase 5: Testing & Validation

### 5.1 Token Validation Tests

**Critical Test:** Verify ApplicationTokens work for shielding

```
1. On child device: Parent Mode → Select "TikTok" as Reward app
2. Child device stores Token_C (child's TikTok token)
3. Child mode: Try to open TikTok → Should be blocked ✅
4. Child redeems points for 10 minutes
5. ExemptionManager grants exemption using Token_C
6. TikTok unblocks for 10 minutes ✅
7. After 10 minutes, shield reapplies ✅
```

**Expected Result:** Shields work because tokens are from the same device!

### 5.2 PIN Protection Tests

- Child cannot access Parent Mode without PIN
- PIN locks after 5 minutes of inactivity
- Rate limiting works (3 attempts, then lockout)
- Biometric auth works if enabled

### 5.3 CloudKit Sync Tests

- Child device writes configuration
- Parent device reads configuration within 2 seconds
- Multi-parent scenario: Both parents see same config
- Audit log tracks which device made changes

---

## Implementation Checklist

**Phase 1: PIN Authentication**
- [ ] Implement PINManager service
- [ ] Add Keychain integration
- [ ] Create PINSetupView
- [ ] Create PINEntryView
- [ ] Add biometric fallback
- [ ] Implement rate limiting

**Phase 2: Parent Mode UI**
- [ ] Create ChildDeviceParentModeView
- [ ] Update mode selection logic
- [ ] Add "Parent Mode" entry point with PIN prompt
- [ ] Add auto-lock after inactivity

**Phase 3: Move Configuration UIs**
- [ ] Keep AppCategorizationView (already works!)
- [ ] Update instructions in AppCategorizationView
- [ ] Create PointsConfigurationView
- [ ] Create RedemptionRulesView
- [ ] Create ParentSettingsView

**Phase 4: CloudKit Sync**
- [ ] Add PointsConfiguration CloudKit mapping
- [ ] Add RedemptionConfiguration CloudKit mapping
- [ ] Update child device to write configs
- [ ] Update parent device to read configs

**Phase 5: Testing**
- [ ] Test ApplicationTokens work for shielding
- [ ] Test PIN protection prevents child access
- [ ] Test CloudKit sync (child writes, parent reads)
- [ ] Test end-to-end setup flow

---

## Files to Create/Modify

**New Files:**
- `apps/ParentiOS/Services/PINManager.swift`
- `apps/ParentiOS/Views/PINSetupView.swift`
- `apps/ParentiOS/Views/PINEntryView.swift`
- `apps/ParentiOS/Views/ChildDeviceParentModeView.swift`
- `apps/ParentiOS/Views/PointsConfigurationView.swift`
- `apps/ParentiOS/Views/RedemptionRulesView.swift`
- `apps/ParentiOS/Views/ParentSettingsView.swift`

**Modified Files:**
- `apps/ParentiOS/ClaudexApp.swift` (add PINManager, update mode selection)
- `apps/ParentiOS/Views/AppCategorizationView.swift` (update instructions)
- `Sources/SyncKit/CloudKitMapper.swift` (add PointsConfiguration, RedemptionConfiguration mappers)
- `Sources/SyncKit/SyncService.swift` (add save/fetch methods for configs)

---

## Success Criteria

✅ Parent can access Parent Mode on child's device with PIN
✅ App categorization works with local tokens (shields apply correctly)
✅ Points configuration syncs to CloudKit
✅ Redemption rules sync to CloudKit
✅ Parent device dashboard reads configuration (read-only)
✅ Child cannot access Parent Mode without PIN
✅ Auto-lock works after inactivity
