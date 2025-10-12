# Device Role Detection Analysis

## Question
Can our app determine if the device belongs to a Parent/Organizer/Guardian (hide Child Mode) or a Child (show both modes)?

## TL;DR Answer
**YES - Using our own pairing system in CloudKit**, but NOT through Apple's native APIs.

---

## What Apple Provides (Limited)

### AuthorizationCenter - NO Role Information ❌
```swift
let status = authorizationCenter.authorizationStatus
// Returns: .notDetermined, .denied, or .approved
// Does NOT tell us: parent vs child role
```

**Apple's Family Controls framework does NOT provide**:
- ❌ Device role detection (parent vs child)
- ❌ Family Sharing membership info
- ❌ Who authorized the device
- ❌ Relationship between devices

**What Apple DOES provide**:
- ✅ Authorization status (approved/denied)
- ✅ FamilyActivityPicker (for app selection)
- ✅ ManagedSettings (for shielding)
- ✅ DeviceActivity (for monitoring)

### Why No Native Role Detection?
Apple's privacy design:
- Screen Time API is device-local
- No cross-device awareness
- No family relationship metadata
- ApplicationTokens are opaque and device-specific

---

## What We CAN Do (Our Pairing System) ✅

### We Already Have a Pairing System!

**Files**:
- `Sources/Core/PairingService.swift`
- CloudKit schema: `DevicePairing` records

**Current Capabilities**:
```swift
struct DevicePairing {
    let pairingId: String
    let childId: ChildID
    let deviceId: String      // ← Unique device identifier
    let deviceName: String
    let pairedAt: Date
    let familyId: FamilyID
}
```

**We can add a `deviceRole` field**:
```swift
enum DeviceRole: String, Codable {
    case parent     // Parent/Guardian device (monitoring only)
    case child      // Child device (configuration + child interface)
}

struct DevicePairing {
    // ... existing fields
    let deviceRole: DeviceRole  // ← NEW FIELD
}
```

---

## Proposed Solution: Automatic Device Role Detection

### Architecture

```
App Launch
    ↓
Check Device Role in CloudKit
    ↓
    ├─ Found as PARENT device
    │      ↓
    │  ModeSelectionView
    │      └─ [Parent Mode] only (monitoring dashboard)
    │         (Hide Child Mode option)
    │
    ├─ Found as CHILD device
    │      ↓
    │  ModeSelectionView
    │      ├─ [Parent Mode] (PIN-protected configuration)
    │      └─ [Child Mode] (points & redemption)
    │
    └─ NOT FOUND (first launch)
           ↓
       DeviceRoleSetupView (new)
           ├─ "This is my child's device" → Register as CHILD
           └─ "This is my device (parent)" → Register as PARENT
```

### Implementation Plan

#### 1. Add DeviceRole to CloudKit Schema
```swift
// Sources/Core/AppModels.swift
public enum DeviceRole: String, Codable {
    case parent
    case child
}

// Update DevicePairing
public struct DevicePairing: Codable {
    public let pairingId: String
    public let childId: ChildID
    public let deviceId: String
    public let deviceName: String
    public let deviceRole: DeviceRole  // NEW
    public let pairedAt: Date
    public let familyId: FamilyID
}
```

#### 2. Create DeviceRoleManager
```swift
// apps/ParentiOS/Services/DeviceRoleManager.swift
@MainActor
class DeviceRoleManager: ObservableObject {
    @Published var deviceRole: DeviceRole?
    @Published var isRoleSet: Bool = false

    private let pairingService: PairingService
    private var deviceId: String

    init(pairingService: PairingService) {
        self.pairingService = pairingService
        self.deviceId = Self.getOrCreateDeviceId()
    }

    func loadDeviceRole() async {
        // Query CloudKit for this device's pairing record
        if let pairing = await pairingService.getPairingForDevice(deviceId) {
            deviceRole = pairing.deviceRole
            isRoleSet = true
        } else {
            isRoleSet = false
        }
    }

    func setDeviceRole(_ role: DeviceRole, childId: ChildID?) async throws {
        // Create pairing record in CloudKit
        let pairing = DevicePairing(
            pairingId: UUID().uuidString,
            childId: childId ?? ChildID("unassigned"),
            deviceId: deviceId,
            deviceName: UIDevice.current.name,
            deviceRole: role,
            pairedAt: Date(),
            familyId: FamilyID("default-family")
        )

        try await pairingService.savePairing(pairing)
        deviceRole = role
        isRoleSet = true
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

#### 3. Create DeviceRoleSetupView (First Launch)
```swift
// apps/ParentiOS/Views/DeviceRoleSetupView.swift
struct DeviceRoleSetupView: View {
    @EnvironmentObject var deviceRoleManager: DeviceRoleManager
    @EnvironmentObject var childrenManager: ChildrenManager

    var body: some View {
        VStack(spacing: 24) {
            Text("Setup Device")
                .font(.largeTitle)

            Text("Is this your child's device or your device?")
                .font(.headline)

            Button {
                Task {
                    // Child device needs to be paired to a child profile
                    // Show child selector or create new child
                    await setupAsChildDevice()
                }
            } label: {
                Label("This is my child's device", systemImage: "iphone")
            }

            Button {
                Task {
                    // Parent device for monitoring
                    try? await deviceRoleManager.setDeviceRole(.parent, childId: nil)
                }
            } label: {
                Label("This is my device (parent)", systemImage: "person")
            }
        }
    }
}
```

#### 4. Update ModeSelectionView (Conditional Display)
```swift
// apps/ParentiOS/ClaudexApp.swift
struct ModeSelectionView: View {
    @EnvironmentObject var deviceRoleManager: DeviceRoleManager

    var body: some View {
        VStack(spacing: 24) {
            // Always show Parent Mode
            NavigationLink {
                // PIN protection here
                ParentModeEntryView()
            } label: {
                Label("Parent Mode", systemImage: "lock.shield")
            }

            // Only show Child Mode if device is registered as child device
            if deviceRoleManager.deviceRole == .child {
                NavigationLink {
                    ChildModeHomeView()
                } label: {
                    Label("Child Mode", systemImage: "star")
                }
            }
        }
    }
}
```

#### 5. Update ClaudexApp.swift (Root Logic)
```swift
@main
struct ClaudexApp: App {
    @StateObject private var deviceRoleManager = DeviceRoleManager(pairingService: pairingService)

    var body: some Scene {
        WindowGroup {
            if !deviceRoleManager.isRoleSet {
                // First launch - ask user to set device role
                DeviceRoleSetupView()
                    .environmentObject(deviceRoleManager)
                    .task {
                        await deviceRoleManager.loadDeviceRole()
                    }
            } else {
                // Role is set - show mode selection
                ModeSelectionView()
                    .environmentObject(deviceRoleManager)
            }
        }
    }
}
```

---

## User Experience

### First Launch on Child's Device
1. App opens → "Setup Device" screen
2. Parent selects "This is my child's device"
3. App asks: "Which child?" (if multiple) or creates new child profile
4. Device role saved to CloudKit
5. ModeSelectionView shows: Parent Mode + Child Mode

### First Launch on Parent's Device
1. App opens → "Setup Device" screen
2. Parent selects "This is my device (parent)"
3. Device role saved to CloudKit
4. ModeSelectionView shows: Parent Mode only (Child Mode hidden)

### Subsequent Launches
1. App checks CloudKit for device role
2. Automatically shows appropriate mode options
3. No setup screen needed

---

## Apple's Rules & Token Limitations - NOT AN ISSUE ✅

### ApplicationToken Limitation (From Pivot)
- **Problem**: Parent device tokens ≠ Child device tokens
- **Impact**: Can't select apps on parent device and shield on child device
- **Solution**: Configuration happens on child device (already decided)

### Device Role Detection (This Feature)
- **Uses**: CloudKit pairing records (our own system)
- **Does NOT use**: Apple's Family Controls authorization metadata
- **Does NOT violate**: Any Apple privacy rules
- **Does NOT conflict**: With ApplicationToken limitations

**Key Point**: ApplicationToken limitation is about shielding apps across devices. Device role detection is about UI customization using our own pairing data. These are separate concerns.

---

## Benefits of Device Role Detection

### 1. Cleaner UX
- Parent device: Only shows monitoring (no Child Mode clutter)
- Child device: Shows both modes (Parent Mode PIN-protected)

### 2. Security
- Child can't accidentally enter Parent Mode on parent's device
- Parent device doesn't need PIN protection (child never uses it)

### 3. Clarity
- Device role is explicit and stored
- No confusion about which device is which
- Pairing records include role metadata

### 4. Flexibility
- Parent can change device role if needed
- Can have multiple parent devices (all monitoring)
- Can have multiple child devices (each paired to a child profile)

---

## Edge Cases

### What if parent installs app on their own device to configure?
- **Answer**: Parent device should still be role=parent
- Configuration still happens on child device (tokens are device-specific)
- Parent device can't shield child's device (token limitation)
- Parent device is for monitoring only

### What if parent wants to test Child Mode?
- **Answer**: Add a "Test Child Mode" option in parent device settings
- Or allow role change (with confirmation)
- But make it clear: "This is for testing only"

### What if device changes hands?
- **Answer**: Add "Reset Device Role" in settings
- Unlinks device from CloudKit pairing
- Shows setup screen again on next launch

---

## Implementation Effort

### Small (1-2 hours)
- Add DeviceRole enum to AppModels.swift
- Add deviceRole field to DevicePairing
- Update CloudKit schema

### Medium (3-4 hours)
- Create DeviceRoleManager
- Create DeviceRoleSetupView
- Update ModeSelectionView conditional display
- Update ClaudexApp.swift root logic

### Testing (1-2 hours)
- Test first launch flow
- Test role persistence
- Test mode selection hiding
- Test role change/reset

**Total: ~6-8 hours**

---

## Recommendation

✅ **YES, implement device role detection**

**Benefits**:
1. Better UX (hide Child Mode on parent device)
2. Clear device role metadata
3. Leverages existing PairingService
4. No conflict with Apple's rules or token limitations
5. Relatively small implementation effort

**Risks**:
- ⚠️ If user installs on wrong device first, need to reset role
- ⚠️ If CloudKit sync fails, role detection fails (need offline fallback)

**Mitigation**:
- Add "Reset Device Role" in settings
- Cache role in UserDefaults as backup
- Clear instructions during setup

---

## Next Steps if Approved

1. Add DeviceRole to data model
2. Create DeviceRoleManager service
3. Create DeviceRoleSetupView
4. Update ModeSelectionView to hide Child Mode on parent devices
5. Add role reset option in settings
6. Test on both device types
7. Document device role setup in user guide

**Should I proceed with this implementation?**
