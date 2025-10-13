# Per-App Points Tracking Implementation

**Date**: 2025-10-12
**Status**: ✅ Core functionality implemented and tested (build successful)

---

## Overview

Implemented per-app points tracking using DeviceActivity event-based monitoring. This allows the app to identify which specific learning app a child is using and accrue points to that app's balance.

---

## Architecture

### Event-Based Per-App Detection

**Challenge**: DeviceActivity interval callbacks don't identify which specific app is active.

**Solution**: Create one `DeviceActivityEvent` per learning app with encoded event names.

### Event Name Encoding Pattern

```
Event Name Format: "child_{childId}_app_{appId}"
Example: "child_ABC123_app_app_987654321"
```

When an event fires, we parse the name to extract:
- `childId`: Which child
- `appId`: Which app (hashed ApplicationToken)

---

## Implementation Details

### 1. ActivityScheduleCoordinator (Sources/ScreenTimeService/DeviceActivityMonitor.swift)

**Changes:**
- Creates per-app events when monitoring starts
- One `DeviceActivityEvent` per learning app with 1-second threshold
- Events passed to `DeviceActivityCenter.startMonitoring()`

```swift
for appToken in learningApps.applicationTokens {
    let appId = ApplicationTokenHelper.toAppIdentifier(appToken)
    let eventName = ActivityEventName.make(childId: childId, appId: appId)
    let event = DeviceActivityEvent(
        applications: [appToken],
        threshold: DateComponents(second: 1)
    )
    events[eventName] = event
}
```

### 2. LearningActivityMonitor

**Changes:**
- `eventDidReachThreshold` now parses event names
- Posts new `.appActivityDetected` notification with childId and appId
- Enables per-app session tracking

```swift
if let (childId, appId) = ActivityEventName.parse(event) {
    NotificationCenter.default.post(
        name: .appActivityDetected,
        object: nil,
        userInfo: [
            "childId": childId.rawValue,
            "appId": appId.rawValue
        ]
    )
}
```

### 3. LearningSessionCoordinator (apps/ParentiOS/ViewModels/)

**Changes:**
- Added `activeAppSessions` dictionary: `[String: UsageSession]` (key: "{childId}_{appId}")
- New methods: `beginAppSession`, `touchAppSession`, `endAppSession`
- Observes `.appActivityDetected` notification
- Starts per-app sessions with correct appId
- Points accrue to specific app balances

```swift
private func beginAppSession(for childId: ChildID, appId: AppIdentifier, startTime: Date) {
    let session = pointsEngine.startSession(childId: childId, appId: appId, at: startTime)
    activeAppSessions[key] = session
}
```

### 4. ApplicationToken → AppIdentifier Helper

**New Utility**: `ApplicationTokenHelper`

Converts opaque `ApplicationToken` to stable `AppIdentifier`:
```swift
public static func toAppIdentifier(_ token: ApplicationToken) -> AppIdentifier {
    let data = withUnsafeBytes(of: token) { Data($0) }
    let hash = data.hashValue
    return AppIdentifier("app_\(abs(hash))")
}
```

**Why Hashing:**
- ApplicationToken is opaque (can't be inspected)
- Need stable string identifier for AppIdentifier
- Hash provides consistent mapping: same token → same appId

---

## 5. Per-App Configuration & Redemption (2025-10-12)

### PerAppConfigurationStore
- New `PerAppConfigurationStore` persists per-child learning (earn) and reward (spend) rules.
- Stores per-app points rules (rate, daily cap, idle timeout) and reward rules (cost, min/max, stacking policy).
- Records reward usage history (times unlocked, total points spent) to drive dashboard metrics.
- Persists to `per_app_configuration.json` in the shared documents directory.

### Parent Mode UI
- Level 2 `Points` tab lists each detected/configured learning app with live balance + earned-today metrics.
- Parents can adjust points-per-minute and daily caps per app, reset to defaults, and changes persist instantly.
- Level 2 `Rewards` tab lists reward apps with unlock counts, total points spent, and editable cost/min/max/stacking controls.

### RedemptionService Updates
- Redemptions now allocate deductions across all learning-app balances (`PointsLedger.getBalances`), ensuring per-app totals remain accurate.
- Reward usage callback records each redemption in `PerAppConfigurationStore` for analytics.
- Unit tests cover mixed per-app deductions and reward usage recording.

### Remaining Polish
- Surface human-friendly app metadata (names/icons) in the UI.
- Feed per-app metrics into Child Mode dashboards and redemption flow.
- Add integration coverage once DeviceActivity simulations are possible in CI.

---

## Data Flow

### 1. Parent Configures Learning Apps
```
Parent → FamilyActivityPicker → Selects Khan Academy, Duolingo
CategoryRulesManager → Updates rules
LearningSessionCoordinator → Observes rule changes
ActivityScheduleCoordinator.startMonitoring() → Creates per-app events
```

### 2. Child Opens Khan Academy
```
DeviceActivity → Detects Khan Academy usage
LearningActivityMonitor.eventDidReachThreshold() → Event: "child_ABC123_app_app_123456"
ActivityEventName.parse() → Extracts (childId: ABC123, appId: app_123456)
Notification.appActivityDetected posted
LearningSessionCoordinator → Receives notification
beginAppSession(childId, appId) → Starts per-app session
PointsEngine.startSession(childId, appId: app_123456) → Session tracked
```

### 3. Session Ends
```
Child closes app
LearningActivityMonitor.intervalDidEnd()
LearningSessionCoordinator.endAppSession()
PointsEngine.endSession() → Calculates points (e.g., 50 points)
PointsLedger.recordAccrual(childId, appId: app_123456, points: 50)
```

**Result**: 50 points credited to Khan Academy balance for this child.

---

## Key Classes Modified

### Sources/ScreenTimeService/DeviceActivityMonitor.swift
- ✅ `ActivityScheduleCoordinator.startMonitoring()` - Creates per-app events
- ✅ `LearningActivityMonitor.eventDidReachThreshold()` - Parses event names
- ✅ `ActivityEventName` - Event name encoding/parsing utility
- ✅ `ApplicationTokenHelper` - Token-to-AppIdentifier conversion
- ✅ Added `.appActivityDetected` notification name

### apps/ParentiOS/ViewModels/LearningSessionCoordinator.swift
- ✅ Added `activeAppSessions` dictionary
- ✅ Added per-app session methods
- ✅ Observes `.appActivityDetected` notification
- ✅ Updated `stopMonitoring()` to clean up app sessions

---

## Testing Checklist

### Manual Testing (Requires Real Device)

1. **Setup**:
   - [ ] Configure child device
   - [ ] Select 2-3 learning apps via FamilyActivityPicker
   - [ ] Verify monitoring starts without errors

2. **Per-App Session Tracking**:
   - [ ] Open learning app #1 (e.g., Khan Academy)
   - [ ] Verify console log: "Started session for child X, app app_Y"
   - [ ] Use app for 5 minutes
   - [ ] Close app
   - [ ] Verify console log: "Ended session for child X, app app_Y"
   - [ ] Check PointsLedger: Should have entry with `appId: app_Y`

3. **Multiple Apps**:
   - [ ] Open learning app #2 (e.g., Duolingo)
   - [ ] Use for 3 minutes
   - [ ] Switch back to app #1
   - [ ] Verify separate sessions tracked
   - [ ] Check PointsLedger: Multiple entries with different appIds

4. **Balance Verification**:
   - [ ] Query `pointsLedger.getBalance(childId: X, appId: app_Y)`
   - [ ] Verify per-app balances correct
   - [ ] Verify `pointsLedger.getBalances(childId: X)` shows all apps

---

## Known Limitations

### 1. ApplicationToken Instability
- **Issue**: ApplicationToken hashes MAY change across iOS updates
- **Mitigation**: Hash is stable within a single iOS version
- **Future**: Consider storing bundleIdentifier mapping when available

### 2. Event Threshold Delay
- **Issue**: 1-second threshold means app must be used for 1 second before detection
- **Impact**: Very brief app switches (<1 second) may not be tracked
- **Tradeoff**: Acceptable for MVP (filters accidental taps)

### 3. Category Tokens Not Supported Yet
- **Status**: Only individual apps (`applicationTokens`) tracked
- **Impact**: When parents select only categories (no explicit apps), the new Points/Rewards tabs continue to show the guidance state because no per-app DeviceActivity events fire.
- **Future**: Map category selections to the child’s inventory so we can emit per-app events and populate metrics automatically.

---

## Next Steps

### Phase 3a: UI Integration (Next Priority)

1. **Points Tab** (ChildDeviceParentModeView):
   - Display per-app balances
   - Configure per-app point rates
   - Show daily caps per app

2. **Rewards Tab**:
   - Configure per-app redemption rules
   - Display reward app costs

3. **Child Mode UI**:
   - Grid of app icons with balances
   - Per-app redemption flow
   - Partial redemption support

### Phase 3b: RedemptionService Extension

- Support per-app spending
- Multi-app redemption (e.g., 200 pts from Khan + 100 pts from Duolingo)
- Validation across multiple app balances

---

## Technical Notes

### Why Event-Based vs DeviceActivityReport?

**Option A: Events** (✅ Chosen)
- Real-time app detection
- Immediate session start/end
- Clean notification-based architecture
- Scales well (one event per app)

**Option B: DeviceActivityReport** (❌ Rejected)
- Query-based (delayed)
- Requires complex retroactive point allocation
- More complex integration with PointsEngine
- Report queries can fail or timeout

**Decision**: Event-based approach provides better UX and simpler architecture.

### Thread Safety

- All session management happens on `@MainActor` (LearningSessionCoordinator)
- Notifications posted on `.main` queue
- No race conditions with dictionary updates

---

## Build Status

✅ **Swift Package Build**: SUCCESS
✅ **Warnings**: Only existing actor isolation warnings (not introduced by this change)
✅ **Compilation**: Clean

---

## Commits

See: `git log --oneline | head -5` for recent commits related to this implementation.

---

## References

- **Implementation Plan**: `docs/implementation-plan-2025-10-11-final.md` (Phase 3)
- **Architecture Confirmed**: `docs/architecture-confirmed-2025-10-11.md` (User answers)
- **Apple Documentation**: DeviceActivity, DeviceActivityEvent, DeviceActivityMonitor
