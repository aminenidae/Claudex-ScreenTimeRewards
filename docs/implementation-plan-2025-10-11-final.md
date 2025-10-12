# Implementation Plan - October 11, 2025 (Final)

## Architecture Summary (User Confirmed)

### Child's Device - Complete Flow
```
App Launch
    ↓
[First Launch Only] DeviceRoleSetupView
    ├─ "This is my child's device" → deviceRole = .child
    └─ "This is my device (parent)" → deviceRole = .parent
    ↓
ModeSelectionView
    ├─→ [Parent Mode] button
    │       ↓
    │   🔐 Authentication (PIN/Biometric as parent/organizer/guardian)
    │       ↓
    │   ParentDeviceParentModeView (Level 1 - Family Overview)
    │       ├─ Child Tab: DashboardView (aggregated points balance per child)
    │       │   ├─ Select child → Navigate to Level 2
    │       │   └─ Shows all children in family
    │       └─ Account Tab: Manage SubscriptionView (future)
    │       ↓
    │   [User selects a child]
    │       ↓
    │   ChildDeviceParentModeView (Level 2 - Per-Child Configuration)
    │       ├─ Apps Tab: Configure Learning/Reward categories
    │       ├─ Points Tab: Set points rules PER APP
    │       ├─ Rewards Tab: Set redemption rules PER APP
    │       └─ Settings Tab: Screentime config, PIN management
    │
    └─→ [Child Mode] button (no authentication)
            ↓
        ChildModeHomeView
            ├─ Points balance (per-app display)
            ├─ Redeem points PER APP
            │   └─ Partial or full redemption
            │   └─ Remaining points available for other apps
            └─ Active reward time display

Note: Child Mode only visible if deviceRole = .child
```

### Parent's Device - Simplified Flow
```
App Launch
    ↓
[First Launch Only] DeviceRoleSetupView
    └─ "This is my device (parent)" → deviceRole = .parent
    ↓
ModeSelectionView
    └─→ [Parent Mode] button only (Child Mode hidden)
            ↓
        🔐 Authentication (PIN/Biometric)
            ↓
        ParentDeviceParentModeView (Monitoring Only)
            ├─ Child Tabs: One per child (read-only monitoring)
            ├─ View points history
            ├─ View redemptions
            └─ Account Tab: Settings (future)
```

---

## Phase 1: Device Role Detection + Mode Selection Fix

### Goals
1. ✅ Add device role detection (parent vs child device)
2. ✅ Fix mode selection (authentication at mode level, not inside)
3. ✅ Remove gear icon from Child Mode
4. ✅ Hide Child Mode on parent devices

### Step 1.1: Add DeviceRole to Data Model
**File**: `Sources/Core/AppModels.swift`

```swift
// Add near top of file with other enums
public enum DeviceRole: String, Codable, Sendable {
    case parent    // Monitoring dashboard only
    case child     // Full functionality (config + child mode)
}
```

**File**: `Sources/Core/PairingService.swift` (update DevicePairing)

```swift
// Update struct to include deviceRole
public struct DevicePairing {
    public let pairingId: String
    public let childId: ChildID
    public let deviceId: String
    public let deviceName: String
    public let deviceRole: DeviceRole  // NEW FIELD
    public let pairedAt: Date
    public let familyId: FamilyID

    public init(
        pairingId: String,
        childId: ChildID,
        deviceId: String,
        deviceName: String,
        deviceRole: DeviceRole,  // NEW
        pairedAt: Date,
        familyId: FamilyID
    ) {
        // ... implementation
    }
}
```

### Step 1.2: Create DeviceRoleManager
**File**: `apps/ParentiOS/Services/DeviceRoleManager.swift` (NEW)

```swift
import Foundation
import Combine
#if canImport(Core)
import Core
#endif

@MainActor
class DeviceRoleManager: ObservableObject {
    @Published var deviceRole: DeviceRole?
    @Published var isRoleSet: Bool = false
    @Published var deviceId: String

    private let pairingService: PairingService

    init(pairingService: PairingService) {
        self.pairingService = pairingService
        self.deviceId = Self.getOrCreateDeviceId()
    }

    func loadDeviceRole() async {
        // Query CloudKit for this device's pairing record
        do {
            if let pairing = try await pairingService.getPairingForDevice(deviceId) {
                deviceRole = pairing.deviceRole
                isRoleSet = true
            } else {
                isRoleSet = false
            }
        } catch {
            print("DeviceRoleManager: Failed to load role: \(error)")
            isRoleSet = false
        }
    }

    func setDeviceRole(_ role: DeviceRole, childId: ChildID?, familyId: FamilyID) async throws {
        let pairing = DevicePairing(
            pairingId: UUID().uuidString,
            childId: childId ?? ChildID("unassigned"),
            deviceId: deviceId,
            deviceName: UIDevice.current.name,
            deviceRole: role,
            pairedAt: Date(),
            familyId: familyId
        )

        try await pairingService.savePairing(pairing)
        deviceRole = role
        isRoleSet = true
    }

    func resetDeviceRole() {
        deviceRole = nil
        isRoleSet = false
        // TODO: Delete pairing from CloudKit
    }

    private static func getOrCreateDeviceId() -> String {
        let key = "com.claudex.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
```

### Step 1.3: Create DeviceRoleSetupView
**File**: `apps/ParentiOS/Views/DeviceRoleSetupView.swift` (NEW)

```swift
import SwiftUI
#if canImport(Core)
import Core
#endif

@available(iOS 16.0, *)
struct DeviceRoleSetupView: View {
    @EnvironmentObject var deviceRoleManager: DeviceRoleManager
    @EnvironmentObject var childrenManager: ChildrenManager

    @State private var showingChildSelector = false
    @State private var selectedChildId: ChildID?
    @State private var isSettingRole = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "iphone.and.ipad")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("Setup Device")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Is this your child's device or your device?")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Device Type Selection
                VStack(spacing: 16) {
                    Button {
                        showingChildSelector = true
                    } label: {
                        HStack {
                            Image(systemName: "iphone")
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("This is my child's device")
                                    .font(.headline)
                                Text("Configure and monitor on this device")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await setAsParentDevice()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.circle")
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("This is my device (parent)")
                                    .font(.headline)
                                Text("Monitor children from here")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isSettingRole {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSettingRole)
                }
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingChildSelector) {
            ChildSelectorSheetView(selectedChildId: $selectedChildId) {
                Task {
                    await setAsChildDevice()
                }
            }
            .environmentObject(childrenManager)
        }
    }

    private func setAsChildDevice() async {
        guard let childId = selectedChildId else {
            errorMessage = "Please select a child"
            return
        }

        isSettingRole = true
        errorMessage = nil

        do {
            try await deviceRoleManager.setDeviceRole(
                .child,
                childId: childId,
                familyId: FamilyID("default-family")
            )
        } catch {
            errorMessage = "Failed to set device role: \(error.localizedDescription)"
        }

        isSettingRole = false
    }

    private func setAsParentDevice() async {
        isSettingRole = true
        errorMessage = nil

        do {
            try await deviceRoleManager.setDeviceRole(
                .parent,
                childId: nil,
                familyId: FamilyID("default-family")
            )
        } catch {
            errorMessage = "Failed to set device role: \(error.localizedDescription)"
        }

        isSettingRole = false
    }
}

// Helper view for child selection
@available(iOS 16.0, *)
struct ChildSelectorSheetView: View {
    @EnvironmentObject var childrenManager: ChildrenManager
    @Binding var selectedChildId: ChildID?
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(childrenManager.children) { child in
                    Button {
                        selectedChildId = child.id
                    } label: {
                        HStack {
                            Text(child.name)
                            Spacer()
                            if selectedChildId == child.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        dismiss()
                        onConfirm()
                    }
                    .disabled(selectedChildId == nil)
                }
            }
        }
    }
}
```

### Step 1.4: Update ClaudexApp.swift - Remove Gear Icon & Fix Mode Selection
**File**: `apps/ParentiOS/ClaudexApp.swift`

**Changes**:
1. Add DeviceRoleManager @StateObject
2. Show DeviceRoleSetupView on first launch
3. Update ModeSelectionView to:
   - Add authentication BEFORE entering Parent Mode
   - Hide Child Mode if deviceRole == .parent
4. Remove gear icon from ChildModeView

```swift
// Add DeviceRoleManager
@StateObject private var deviceRoleManager = DeviceRoleManager(pairingService: pairingService)

// Root view logic
var body: some Scene {
    WindowGroup {
        if !deviceRoleManager.isRoleSet {
            DeviceRoleSetupView()
                .environmentObject(deviceRoleManager)
                .environmentObject(childrenManager)
                .task {
                    await deviceRoleManager.loadDeviceRole()
                }
        } else {
            ModeSelectionView()
                .environmentObject(deviceRoleManager)
                // ... other environment objects
        }
    }
}

// Updated ModeSelectionView
struct ModeSelectionView: View {
    @EnvironmentObject var deviceRoleManager: DeviceRoleManager
    @EnvironmentObject var pinManager: PINManager

    @State private var showingPINEntry = false
    @State private var showingPINSetup = false

    var body: some View {
        VStack(spacing: 24) {
            // Parent Mode - Always visible
            Button {
                // Check if PIN is set
                if !pinManager.isPINSet {
                    showingPINSetup = true
                } else if pinManager.isAuthenticated {
                    // Already authenticated - go directly
                    navigateToParentMode()
                } else {
                    // Need authentication
                    showingPINEntry = true
                }
            } label: {
                Label("Parent Mode", systemImage: "lock.shield")
            }

            // Child Mode - Only on child devices
            if deviceRoleManager.deviceRole == .child {
                NavigationLink {
                    ChildModeHomeView()
                } label: {
                    Label("Child Mode", systemImage: "star")
                }
            }
        }
        .sheet(isPresented: $showingPINEntry) {
            PINEntryView()
                .environmentObject(pinManager)
                .onDisappear {
                    if pinManager.isAuthenticated {
                        navigateToParentMode()
                    }
                }
        }
        .sheet(isPresented: $showingPINSetup) {
            PINSetupView()
                .environmentObject(pinManager)
                .onDisappear {
                    if pinManager.isAuthenticated {
                        navigateToParentMode()
                    }
                }
        }
    }

    private func navigateToParentMode() {
        // Navigate to ParentDeviceParentModeView
        // Implementation depends on navigation structure
    }
}

// ChildModeView - REMOVE gear icon toolbar
// Delete or comment out:
/*
.toolbar {
    if currentPairing != nil {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                attemptParentModeAccess()  // DELETE THIS
            } label: {
                Label("Parent Mode", systemImage: "gear.circle")  // DELETE THIS
            }
        }
    }
}
*/
```

### Step 1.5: Update PairingService (Add getPairingForDevice)
**File**: `Sources/Core/PairingService.swift`

```swift
// Add method to query by deviceId
public func getPairingForDevice(_ deviceId: String) async throws -> DevicePairing? {
    #if canImport(CloudKit)
    let predicate = NSPredicate(format: "deviceId == %@", deviceId)
    let query = CKQuery(recordType: "DevicePairing", predicate: predicate)

    let results = try await publicDatabase.records(matching: query)

    if let firstMatch = results.matchResults.first {
        let record = try firstMatch.1.get()
        // Map CKRecord to DevicePairing
        // ... implementation
        return mappedPairing
    }

    return nil
    #else
    return nil
    #endif
}
```

---

## Phase 2: Two-Level Parent Mode Structure

### Step 2.1: Create ParentDeviceParentModeView (Level 1)
**File**: `apps/ParentiOS/Views/ParentDeviceParentModeView.swift` (NEW)

```swift
import SwiftUI
#if canImport(Core)
import Core
#endif

@available(iOS 16.0, *)
struct ParentDeviceParentModeView: View {
    @EnvironmentObject var childrenManager: ChildrenManager
    @EnvironmentObject var pinManager: PINManager

    var body: some View {
        NavigationStack {
            TabView {
                // Tab for each child
                ForEach(childrenManager.children) { child in
                    ChildDashboardTab(child: child)
                        .tabItem {
                            Label(child.name, systemImage: "person.circle")
                        }
                }

                // Account Tab (future)
                AccountTabView()
                    .tabItem {
                        Label("Account", systemImage: "gear")
                    }
            }
            .navigationTitle("Family Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { pinManager.lock() }) {
                        Label("Lock", systemImage: "lock.fill")
                    }
                }
            }
        }
    }
}

@available(iOS 16.0, *)
struct ChildDashboardTab: View {
    let child: ChildProfile
    @EnvironmentObject var childrenManager: ChildrenManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Aggregated points balance
                DashboardCard {
                    VStack(alignment: .leading) {
                        Text("Total Points")
                            .font(.headline)
                        Text("\(getAggregatedPoints()) pts")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                }

                // Per-app breakdown
                DashboardCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Points by App")
                            .font(.headline)

                        // TODO: Display per-app balances
                        ForEach(getAppBalances(), id: \.appId) { balance in
                            HStack {
                                Text(balance.appName)
                                Spacer()
                                Text("\(balance.points) pts")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Navigate to configuration
                NavigationLink {
                    ChildDeviceParentModeView()
                        .environmentObject(childrenManager)
                } label: {
                    Label("Configure \(child.name)'s Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }

    private func getAggregatedPoints() -> Int {
        // TODO: Sum all app balances for this child
        return 0
    }

    private func getAppBalances() -> [(appId: String, appName: String, points: Int)] {
        // TODO: Get per-app balances
        return []
    }
}

@available(iOS 16.0, *)
struct AccountTabView: View {
    var body: some View {
        Text("Account & Subscription Settings")
            .font(.headline)
            .foregroundStyle(.secondary)
    }
}
```

### Step 2.2: Keep Existing ChildDeviceParentModeView (Level 2)
**File**: `apps/ParentiOS/Views/ChildDeviceParentModeView.swift`

**No major changes needed** - this becomes Level 2 (per-child configuration).

Navigation: `ParentDeviceParentModeView` → Select child → `ChildDeviceParentModeView`

---

## Phase 3: Per-App Points System (MAJOR REFACTOR)

**Status**: Documentation only, implementation blocked on user clarification.

See questions in `architecture-confirmed-2025-10-11.md` lines 225-269.

---

## Phase 4: Fix PIN Setup UI

**Status**: Deferred until architecture is stable.

---

## Summary of Changes

### New Files (3)
1. `apps/ParentiOS/Services/DeviceRoleManager.swift`
2. `apps/ParentiOS/Views/DeviceRoleSetupView.swift`
3. `apps/ParentiOS/Views/ParentDeviceParentModeView.swift`

### Modified Files (4)
1. `Sources/Core/AppModels.swift` - Add DeviceRole enum
2. `Sources/Core/PairingService.swift` - Add deviceRole field, getPairingForDevice()
3. `apps/ParentiOS/ClaudexApp.swift` - Add DeviceRoleManager, fix mode selection, remove gear icon
4. `apps/ParentiOS/Views/ChildModeHomeView.swift` - Remove gear icon (if exists)

### Deleted Code
- Gear icon in ChildModeView toolbar
- `attemptParentModeAccess()` function in ClaudexApp
- Old Parent Mode access from Child Mode

---

## Implementation Order

1. ✅ Phase 1.1: Add DeviceRole to data model
2. ✅ Phase 1.2: Create DeviceRoleManager
3. ✅ Phase 1.3: Create DeviceRoleSetupView
4. ✅ Phase 1.4: Update ClaudexApp - remove gear, fix mode selection
5. ✅ Phase 1.5: Update PairingService
6. ✅ Phase 2.1: Create ParentDeviceParentModeView (Level 1)
7. ✅ Phase 2.2: Update navigation to Level 2
8. ⏸️ Phase 3: Per-app points (awaiting clarification)
9. ⏸️ Phase 4: PIN UI fix

---

## Testing Plan

### Test 1: First Launch on Child Device
1. App opens → DeviceRoleSetupView
2. Select "This is my child's device"
3. Select child from list
4. Device role saved
5. ModeSelectionView shows: Parent Mode + Child Mode

### Test 2: First Launch on Parent Device
1. App opens → DeviceRoleSetupView
2. Select "This is my device (parent)"
3. Device role saved
4. ModeSelectionView shows: Parent Mode only (Child Mode hidden)

### Test 3: Parent Mode Access on Child Device
1. Tap "Parent Mode"
2. PIN entry (or setup if first time)
3. Authenticate
4. ParentDeviceParentModeView opens (Level 1 - family dashboard)
5. Tap child tab
6. Tap "Configure [child name]'s Settings"
7. ChildDeviceParentModeView opens (Level 2 - per-child config)

### Test 4: Child Mode Access
1. From ModeSelectionView
2. Tap "Child Mode" (only visible on child device)
3. ChildModeHomeView opens
4. No gear icon visible

---

## Coordination Notes

- Phase 1 & 2 can be implemented independently (no per-app points dependency)
- Phase 3 (per-app points) blocks on user clarification
- Phase 4 (PIN UI) can be done in parallel by other developer
- All changes documented with clear before/after

---

## Status

✅ Architecture confirmed with user modifications
✅ Implementation plan created
✅ Testing plan defined
⏸️ **AWAITING USER CONFIRMATION TO START IMPLEMENTATION**
