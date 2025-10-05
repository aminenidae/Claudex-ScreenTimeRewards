# EP-05 Implementation Plan: Redemption & Shielding

**Status:** Ready to implement
**Depends on:** EP-04 (Points Engine) ✅ | Family Controls Entitlement ⏳
**Estimated Effort:** 3-4 days

---

## Overview

Implement the redemption flow that converts accumulated points into timed exemptions for reward apps, enforced via ManagedSettings shields. This is the core value delivery mechanism of the app.

---

## Stories Breakdown

### S-501: Redemption UX & Validation
**Goal:** Allow children to convert points to earned time with proper validation

**Implementation:**
1. Create `RedemptionService` protocol and implementation
   - Input: child ID, points to redeem
   - Validation: min/max redemption amounts, sufficient balance
   - Conversion ratio: configurable (e.g., 10 points = 1 minute)
   - Output: earned time in seconds

2. Data Models:
   ```swift
   struct RedemptionConfiguration {
       let pointsPerMinute: Int        // e.g., 10
       let minRedemptionPoints: Int    // e.g., 30 (3 min minimum)
       let maxRedemptionPoints: Int    // e.g., 600 (60 min maximum)
   }

   struct EarnedTimeWindow {
       let id: UUID
       let childId: ChildID
       let durationSeconds: TimeInterval
       let startTime: Date
       var endTime: Date { startTime.addingTimeInterval(durationSeconds) }
       var remainingSeconds: TimeInterval {
           max(0, endTime.timeIntervalSince(Date()))
       }
   }
   ```

3. Integration with PointsLedger:
   - Deduct points via `recordRedemption()`
   - Validate balance before creating exemption
   - Atomic transaction (all-or-nothing)

**Acceptance:**
- ✅ Validates min/max redemption bounds
- ✅ Checks sufficient balance before redemption
- ✅ Calculates time correctly based on ratio
- ✅ Records ledger entry for audit trail

---

### S-502: Start Timed Exemption (ManagedSettings)
**Goal:** Apply shield exemptions immediately when redemption succeeds

**Implementation:**
1. Create `ShieldController` service:
   ```swift
   protocol ShieldControllerProtocol {
       func applyShields(for childId: ChildID, rewardApps: FamilyActivitySelection)
       func grantExemption(for childId: ChildID, duration: TimeInterval)
       func revokeExemption(for childId: ChildID)
   }
   ```

2. ManagedSettings Integration:
   - Use `ManagedSettingsStore` per child
   - Shield reward apps by default via `shield.applications`
   - Clear shields during exemption window
   - Track active exemptions in-memory + persisted

3. Exemption State Management:
   ```swift
   class ExemptionManager {
       private var activeExemptions: [ChildID: EarnedTimeWindow]
       func startExemption(window: EarnedTimeWindow)
       func getActiveWindow(childId: ChildID) -> EarnedTimeWindow?
   }
   ```

**Acceptance:**
- ✅ Shield applied to reward apps on app launch
- ✅ Exemption starts immediately (<1s) after redemption
- ✅ Child can access reward apps during exemption window
- ✅ Active window queryable for countdown UI

---

### S-503: Extend/Stack Rules
**Goal:** Define policy for extending or stacking redemptions

**Implementation:**
1. Extension Policy Options:
   - **Replace:** New redemption replaces current window
   - **Extend:** Add time to existing window (with max cap)
   - **Queue:** Queue next window to start after current expires
   - **Block:** Prevent new redemption until current expires

2. Configuration:
   ```swift
   enum ExemptionStackingPolicy {
       case replace
       case extend(maxTotalMinutes: Int)
       case queue
       case block
   }
   ```

3. Recommended MVP: **Extend with cap**
   - Allow stacking up to 2 hours max
   - Prevents infinite accumulation
   - User-friendly for children

**Acceptance:**
- ✅ Policy enforced consistently
- ✅ Cannot exceed max total time cap
- ✅ Clear feedback when limit reached

---

### S-504: Re-lock Enforcement & Restart Resiliency
**Goal:** Ensure shields re-apply at exemption expiry and survive restarts

**Implementation:**
1. Timer-based Re-lock:
   ```swift
   class ExemptionTimer {
       func scheduleRelock(for window: EarnedTimeWindow, completion: @escaping () -> Void)
       func cancelScheduled(childId: ChildID)
   }
   ```

2. Use `Timer` or `DispatchSourceTimer` for countdown
   - Fire completion handler at expiry
   - Call `ShieldController.revokeExemption()`
   - Re-apply shields to reward apps

3. Persistence for Restart Recovery:
   - Save active exemptions to UserDefaults/File
   - On app launch, check for expired/active windows
   - Re-apply shields or restore timers accordingly

4. Background Execution:
   - Use `BGTaskScheduler` to schedule re-lock if app backgrounded
   - Ensure shields apply even if app terminated

**Acceptance:**
- ✅ Re-lock occurs ≤5s after exemption expiry
- ✅ Shields persist after device restart
- ✅ Timers restored after app relaunch
- ✅ Works correctly when app is backgrounded

---

### S-505: Per-App vs Category Shielding
**Goal:** Support both app-specific and category-based shields with clear precedence

**Implementation:**
1. Shield Configuration Model:
   ```swift
   struct ShieldConfiguration {
       let rewardApps: Set<ApplicationToken>      // Specific apps
       let rewardCategories: Set<ActivityCategoryToken>  // Categories
   }
   ```

2. Precedence Rules:
   - App-specific override > Category default
   - If app explicitly marked "reward" → shield it
   - If app's category is "reward" but app is "learning" → don't shield
   - Store overrides in AppRule (from EP-03)

3. Selection Helpers:
   ```swift
   func buildRewardSelection(config: ShieldConfiguration,
                             rules: [AppRule]) -> FamilyActivitySelection
   ```

**Acceptance:**
- ✅ Category-based shields work for all apps in category
- ✅ Per-app overrides take precedence
- ✅ Edge cases tested (app in multiple categories, etc.)
- ✅ Clear documentation of precedence logic

---

## Technical Architecture

### Core Components

```
RedemptionService
├── validates points balance
├── calculates earned time
└── creates EarnedTimeWindow

ShieldController (ManagedSettings)
├── applyShields()
├── grantExemption()
└── revokeExemption()

ExemptionManager
├── tracks active windows
├── schedules re-lock timers
└── handles persistence

PointsLedger (from EP-04)
└── recordRedemption() → deduct points
```

### Data Flow

```
User Requests Redemption
    ↓
RedemptionService validates balance & calculates time
    ↓
PointsLedger records redemption transaction
    ↓
ExemptionManager creates window & starts timer
    ↓
ShieldController removes shields (grant exemption)
    ↓
[Timer Countdown...]
    ↓
Timer fires at expiry
    ↓
ShieldController re-applies shields
    ↓
ExemptionManager clears window
```

---

## File Structure

**New Files to Create:**
1. `Sources/ScreenTimeService/ShieldController.swift` (~150 LOC)
2. `Sources/PointsEngine/RedemptionService.swift` (~100 LOC)
3. `Sources/PointsEngine/ExemptionManager.swift` (~120 LOC)
4. `Sources/Core/RedemptionModels.swift` (~80 LOC)
5. `Tests/CoreTests/RedemptionServiceTests.swift` (~150 LOC)
6. `Tests/CoreTests/ExemptionManagerTests.swift` (~120 LOC)

**Files to Modify:**
- `Sources/Core/AppModels.swift` — Add `RedemptionConfiguration`, `EarnedTimeWindow`
- `Package.swift` — Ensure ManagedSettings linked (already in ScreenTimeService)

---

## Testing Strategy

### Unit Tests
1. **RedemptionService:**
   - Min/max validation
   - Balance sufficiency checks
   - Ratio calculation accuracy
   - Ledger integration

2. **ExemptionManager:**
   - Window creation and tracking
   - Expiry detection
   - Persistence/restore after restart
   - Timer scheduling

3. **ShieldController:**
   - Mock ManagedSettingsStore for testing
   - Verify shield apply/remove sequences
   - Precedence rules (app vs category)

### Integration Tests (Post-Entitlement)
- End-to-end redemption flow on device
- Shield enforcement during exemption
- Re-lock timing accuracy (±5s)
- Restart resiliency

---

## Risks & Mitigations

**Risk 1: ManagedSettings API limitations**
- Mitigation: Research API capabilities during implementation; document any constraints

**Risk 2: Background execution limitations**
- Mitigation: Use BGTaskScheduler + local notifications; test thoroughly in background

**Risk 3: Timer drift during device sleep**
- Mitigation: Check wall-clock time on wake; adjust timers accordingly

**Risk 4: Entitlement approval delays**
- Mitigation: Build with mocked ManagedSettings; enable testing without entitlement

---

## Success Criteria

✅ **Functional:**
- Child can redeem points for timed reward app access
- Shields apply/remove correctly during exemption lifecycle
- Re-lock occurs within 5s of expiry
- Works across app restarts and device reboots

✅ **Quality:**
- Unit tests for all services (target >70% coverage)
- No crashes or hangs during redemption flow
- Clear error messages for validation failures

✅ **Performance:**
- Redemption completes in <500ms
- Shield changes apply in <1s
- No battery drain from timers (use coalescing)

---

## Next Steps After EP-05

1. **EP-06:** CloudKit sync for multi-parent
2. **EP-07:** Parent dashboard and weekly reporting
3. **EP-02:** Child pairing flow (can be done in parallel)
4. **EP-03:** App categorization UI

---

## Implementation Checklist

- [ ] Create `RedemptionConfiguration` and `EarnedTimeWindow` models
- [ ] Implement `RedemptionService` with validation logic
- [ ] Integrate with `PointsLedger` for balance deduction
- [ ] Create `ShieldController` with ManagedSettings integration
- [ ] Implement `ExemptionManager` for window tracking
- [ ] Add timer-based re-lock mechanism
- [ ] Build persistence layer for active exemptions
- [ ] Implement restart recovery logic
- [ ] Add per-app vs category precedence rules
- [ ] Write unit tests for all components
- [ ] Update docs/checklists.md with progress
- [ ] Test on device once entitlement approved

