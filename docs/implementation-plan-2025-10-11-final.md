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
// Added near the top of Sources/Core/AppModels.swift
public enum DeviceRole: String, Codable, Sendable {
    case parent
    case child
}

public struct DevicePairingPayload: Codable, Equatable {
    public let id: String
    public let childId: ChildID?
    public let deviceId: String
    public let deviceName: String
    public let deviceRole: DeviceRole
    public let pairedAt: Date
    public let familyId: FamilyID?
}
```

- `PairingSyncServiceProtocol` now exposes `fetchDevicePairings`, `saveDevicePairing`, and `deleteDevicePairing` so CloudKit can round-trip device roles.

**Status:** ✅ Implemented (2025-10-11)

### Step 1.2: Create DeviceRoleManager
**File**: `apps/ParentiOS/Services/DeviceRoleManager.swift` (NEW)

```swift
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

    init(pairingService: PairingService,
         defaults: UserDefaults = .standard,
         familyId: FamilyID = FamilyID("default-family")) {
        self.pairingService = pairingService
        self.defaults = defaults
        self.familyId = familyId
        self.deviceId = defaults.string(forKey: "com.claudex.deviceId") ?? UUID().uuidString
        defaults.set(deviceId, forKey: "com.claudex.deviceId")
    }

    func loadDeviceRole() async {
        isLoading = true
        defer { isLoading = false }

        if let localPairing = pairingService.getPairing(for: deviceId) {
            await pairingService.updateCachedDevicePairing(
                DevicePairingPayload(
                    id: deviceId,
                    childId: localPairing.childId,
                    deviceId: deviceId,
                    deviceName: UIDevice.current.name,
                    deviceRole: .child,
                    pairedAt: localPairing.pairedAt,
                    familyId: familyId
                )
            )
            deviceRole = .child
            isRoleSet = true
            defaults.set(DeviceRole.child.rawValue, forKey: "com.claudex.deviceRole")
            return
        }

        if let cachedRole = pairingService.cachedDeviceRole(for: deviceId) {
            deviceRole = cachedRole
            isRoleSet = true
            defaults.set(cachedRole.rawValue, forKey: "com.claudex.deviceRole")
            return
        }

        if let storedRole = defaults.string(forKey: "com.claudex.deviceRole"),
           let role = DeviceRole(rawValue: storedRole) {
            deviceRole = role
            isRoleSet = true
            return
        }

        await pairingService.refreshDevicePairingsFromCloud(familyId: familyId)
        if let remoteRole = pairingService.cachedDeviceRole(for: deviceId) {
            deviceRole = remoteRole
            isRoleSet = true
            defaults.set(remoteRole.rawValue, forKey: "com.claudex.deviceRole")
        }
    }

    func setDeviceRole(_ role: DeviceRole, childId: ChildID?) async {
        guard role == .parent || childId != nil else {
            errorMessage = "A child must be selected for child devices."
            return
        }

        isLoading = true
        defer { isLoading = false }

        let payload = DevicePairingPayload(
            id: deviceId,
            childId: childId,
            deviceId: deviceId,
            deviceName: UIDevice.current.name,
            deviceRole: role,
            pairedAt: Date(),
            familyId: familyId
        )

        do {
            try await pairingService.saveDevicePairing(payload, familyId: familyId)
            deviceRole = role
            isRoleSet = true
            defaults.set(role.rawValue, forKey: "com.claudex.deviceRole")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetDeviceRole() async {
        try? await pairingService.deleteDevicePairing(deviceId: deviceId, familyId: familyId)
        await pairingService.removeCachedDevicePairing(deviceId: deviceId)
        defaults.removeObject(forKey: "com.claudex.deviceRole")
        deviceRole = nil
        isRoleSet = false
    }
}
```

**Status:** ✅ Implemented (2025-10-11)

- The child-device option now auto-refreshes CloudKit child profiles when tapped or on first appearance, so freshly paired child installs can load the parent-created child records before showing the selector UI.

### Step 1.3: Create DeviceRoleSetupView
**File**: `apps/ParentiOS/Views/DeviceRoleSetupView.swift` (NEW)

```swift
@available(iOS 16.0, *)
struct DeviceRoleSetupView: View {
    @EnvironmentObject private var deviceRoleManager: DeviceRoleManager
    @EnvironmentObject private var childrenManager: ChildrenManager

    @State private var showingChildSelector = false
    @State private var isSettingRole = false
    @State private var selectedChildId: ChildID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Who uses this device?")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Choose whether this device is for a parent/guardian or for your child. We’ll tailor the experience and security based on this choice.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                if deviceRoleManager.isLoading || isSettingRole {
                    ProgressView()
                }

                VStack(spacing: 16) {
                    Button {
                        if childrenManager.children.isEmpty {
                            deviceRoleManager.errorMessage = "Add a child profile before configuring a child device."
                        } else {
                            showingChildSelector = true
                        }
                    } label: {
                        RoleButtonContent(
                            title: "This is my child's device",
                            subtitle: "Shows both Parent Mode and Child Mode (with PIN protection)",
                            systemImage: "iphone"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(deviceRoleManager.isLoading || isSettingRole)

                    Button {
                        Task { await setRole(.parent, childId: nil) }
                    } label: {
                        RoleButtonContent(
                            title: "This is my device (parent)",
                            subtitle: "Monitoring dashboard only; Child Mode hidden",
                            systemImage: "person.crop.circle"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(deviceRoleManager.isLoading || isSettingRole)
                }

                if let errorMessage = deviceRoleManager.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Set Up Device")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await deviceRoleManager.loadDeviceRole() }
        .sheet(isPresented: $showingChildSelector) {
            NavigationStack {
                List(childrenManager.children) { child in
                    Button {
                        selectedChildId = child.id
                        Task { await setRole(.child, childId: child.id) }
                        showingChildSelector = false
                    } label: {
                        HStack {
                            Text(child.name)
                            Spacer()
                            if selectedChildId == child.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accentColor)
                            }
                        }
                    }
                }
                .navigationTitle("Select Child")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingChildSelector = false }
                    }
                }
            }
        }
    }

    private func setRole(_ role: DeviceRole, childId: ChildID?) async {
        isSettingRole = true
        defer { isSettingRole = false }
        await deviceRoleManager.setDeviceRole(role, childId: childId)
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
@StateObject private var deviceRoleManager: DeviceRoleManager

Group {
    if isPriming {
        ProgressView("Preparing...")
    } else if !deviceRoleManager.isRoleSet {
        DeviceRoleSetupView()
            .environmentObject(deviceRoleManager)
            .environmentObject(childrenManager)
    } else {
        ModeSelectionView(pendingPairingCode: $pendingPairingCode)
            .environmentObject(deviceRoleManager)
            .environmentObject(pinManager)
            // other environment objects unchanged
    }
}

struct ModeSelectionView: View {
    @EnvironmentObject private var deviceRoleManager: DeviceRoleManager
    @EnvironmentObject private var pinManager: PINManager
    @Binding var pendingPairingCode: String?

    @State private var navigateToParentMode = false
    @State private var navigateToChildMode = false
    @State private var showingPINEntry = false
    @State private var showingPINSetup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Button { handleParentModeTap() } label: {
                    ModeButton(title: "Parent Mode", subtitle: "Configure rules, review points, approve redemptions")
                }

                if deviceRoleManager.deviceRole == .child {
                    Button { navigateToChildMode = true } label: {
                        ModeButton(title: "Child Mode", subtitle: "Earn points, see rewards, request more time")
                    }
                } else {
                    ModeInfoCard(
                        title: "Child Mode Hidden",
                        message: "Child Mode is available only on devices registered as child devices."
                    )
                }
            }
            .navigationDestination(isPresented: $navigateToParentMode) {
                ParentModeView()
                    .onDisappear { pinManager.lock() }
            }
            .navigationDestination(isPresented: $navigateToChildMode) {
                ChildModeView(pendingPairingCode: $pendingPairingCode)
            }
        }
        .sheet(isPresented: $showingPINEntry, onDismiss: openParentModeIfAuthenticated) {
            PINEntryView().environmentObject(pinManager)
        }
        .sheet(isPresented: $showingPINSetup, onDismiss: openParentModeIfAuthenticated) {
            PINSetupView().environmentObject(pinManager)
        }
    }
}
```

**Status:** ✅ Implemented (2025-10-11)

### Step 1.5: Update PairingService & Sync Layers for DeviceRole
**File**: `Sources/Core/PairingService.swift`

- Added `DevicePairingPayload` persistence, cached in `PairingService` alongside existing `ChildDevicePairing` data.
- `PairingService` now exposes helpers to refresh/save/delete device pairings in CloudKit and persists them locally for offline access.
- `CloudKitMapper` defines a new `DevicePairing` record type and maps `DevicePairingPayload` to/from CKRecord.
- `SyncService` implements `fetchDevicePairings`, `saveDevicePairing`, and `deleteDevicePairing`, wiring through `PairingSyncServiceProtocol`.
- `DeviceRoleManager` uses these helpers to keep local role cache synchronized and stored in `UserDefaults` for fast reloads.

**Status:** ✅ Implemented (2025-10-11)


---

## Phase 2: Two-Level Parent Mode Structure

### Step 2.1: Create ParentDeviceParentModeView (Level 1)
**File**: `apps/ParentiOS/Views/ParentDeviceParentModeView.swift` (NEW)

- Displays a Level 1 dashboard with child tabs, aggregated points, recent activity, and quick links into per-child configuration.
- Includes toolbar controls for linking child devices and re-locking Parent Mode.
- Shows the authorization banner at the top so parents can re-request Screen Time access if needed.

**Status:** ✅ Implemented (2025-10-11)


### Step 2.2: Keep Existing ChildDeviceParentModeView (Level 2)
**File**: `apps/ParentiOS/Views/ChildDeviceParentModeView.swift`

**Status:** ✅ Implemented (2025-10-11) – `ParentDeviceParentModeView` now sets `childrenManager.selectedChildId` before navigating so the existing Level 2 screen opens with the chosen child context.

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
