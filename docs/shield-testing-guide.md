# Shield Testing Guide (P0-2)

## Overview

This guide provides manual testing procedures for validating ManagedSettings shields and timed exemptions to meet the P0-2 requirement: **re-lock ≤5s after expiry**.

## Prerequisites

### Device Requirements
- **Physical iOS device** (iPhone or iPad running iOS 16.0+)
- Shields do NOT work in Simulator - must test on real hardware
- Device must be signed into an Apple ID with Family Sharing configured

### Entitlement Requirements
- Family Controls entitlement approved by Apple
- App must be code-signed with proper provisioning profile
- Entitlement file must include:
  ```xml
  <key>com.apple.developer.family-controls</key>
  <true/>
  ```

### App Configuration
- Parent Mode: Authorize Family Controls
- Add at least one child profile via system UI
- Configure app categorization:
  - **Learning Apps**: Select 1-2 apps (e.g., Khan Academy, Duolingo)
  - **Reward Apps**: Select 2-3 apps that can be easily tested (e.g., YouTube, Instagram, Safari)

## Test Scenarios

### Test 1: Initial Shield Application

**Objective**: Verify shields are applied when reward apps are configured

**Steps:**
1. Open app in Parent Mode
2. Navigate to Settings → App Categorization
3. Select child profile
4. Tap "Reward Apps" → Select test apps (e.g., YouTube, Instagram)
5. Return to home screen
6. Attempt to open a reward app

**Expected Behavior:**
- ✅ Reward app shows ManagedSettings shield screen
- ✅ Shield prevents app launch
- ✅ Shield message is clear and informative

**Pass Criteria:**
- Shield appears within 2 seconds of configuration
- All configured reward apps are shielded

---

### Test 2: Exemption on Redemption

**Objective**: Verify shields are lifted when child redeems points

**Steps:**
1. Ensure child has sufficient points (≥30 points default minimum)
2. In Parent Mode, navigate to Dashboard
3. Tap "Redeem Points" button (or use ChildRedemptionView if integrated)
4. Redeem 60 points (= 6 minutes of reward time at default 10 pts/min)
5. Return to home screen
6. Immediately attempt to open a reward app

**Expected Behavior:**
- ✅ Reward app launches successfully (no shield)
- ✅ CountdownTimerView shows remaining time in dashboard
- ✅ Child can use reward apps freely during window

**Pass Criteria:**
- Exemption grants within 2 seconds of redemption
- All reward apps become accessible

---

### Test 3: Re-lock on Expiry (Critical - P0-2)

**Objective**: Verify shields re-apply ≤5s after expiry

**Setup:**
1. Redeem 30 points (= 3 minutes at default rate)
2. Note expiry time from dashboard countdown

**Steps:**
1. Use reward app during active window
2. Keep reward app in background 30 seconds before expiry
3. Watch countdown timer reach 0:00
4. **Immediately** attempt to reopen reward app

**Expected Behavior:**
- ✅ Shield re-appears within 5 seconds of expiry
- ✅ Reward app is blocked after expiry
- ✅ CountdownTimerView shows expiry (red, 0:00)

**Measurement:**
- Record time between countdown reaching 0:00 and shield appearing
- Use stopwatch or screen recording for accurate timing
- Test multiple times (3-5 iterations)

**Pass Criteria:**
- **Re-lock occurs ≤5 seconds after expiry in all tests**
- Average re-lock time <3 seconds
- No false positives (shield doesn't appear early)

---

### Test 4: Restart Resiliency

**Objective**: Verify shields persist after app restart

**Setup:**
1. Configure reward apps with shields active
2. Force quit the app (swipe up in app switcher)

**Steps:**
1. Reopen the app
2. Attempt to open reward app from home screen
3. Check dashboard for active window state

**Expected Behavior:**
- ✅ Shields remain active after restart
- ✅ Active exemption windows are restored from persistence
- ✅ ExemptionManager.restoreFromPersistence() loads active windows

**Pass Criteria:**
- Shields persist without re-configuration
- Active windows resume countdown after restart

---

### Test 5: Device Restart Resiliency

**Objective**: Verify shields persist after device reboot

**Setup:**
1. Configure reward apps with shields active
2. Restart device (Settings → General → Shut Down → Power on)

**Steps:**
1. After reboot, attempt to open reward app
2. Open Claudex app and check shield state

**Expected Behavior:**
- ✅ Shields remain active after device restart
- ✅ ManagedSettingsStore persists across reboots
- ✅ App correctly restores shield configuration

**Pass Criteria:**
- Shields active immediately after reboot (no app launch needed)
- Shield configuration persists indefinitely

---

### Test 6: Multiple Redemptions (Stacking Policy)

**Objective**: Verify exemption stacking behavior

**Setup:**
1. Set `ExemptionManager` policy to `.extend` (default)
2. Start with 120+ points

**Steps:**
1. Redeem 30 points (3 minutes)
2. Wait 1 minute
3. Redeem another 30 points (3 more minutes)
4. Check countdown timer

**Expected Behavior:**
- ✅ Second redemption extends existing window
- ✅ Total time = 5 minutes (2 remaining + 3 new)
- ✅ Countdown reflects extended time

**Alternate Policies to Test:**
- `.replace`: Second redemption replaces first (total = 3 min from now)
- `.queue`: Second redemption queues after first (total = 6 min)
- `.block`: Second redemption rejected while window active

**Pass Criteria:**
- Stacking policy behaves as configured
- No shield flickering during extension

---

### Test 7: Concurrent Shields (Multi-App)

**Objective**: Verify multiple reward apps shield/unshield together

**Setup:**
1. Configure 3+ reward apps
2. Start exemption window

**Steps:**
1. During active window, open each reward app sequentially
2. Verify all are accessible
3. Wait for expiry
4. Attempt to open each app

**Expected Behavior:**
- ✅ All reward apps accessible during window
- ✅ All reward apps shielded after expiry
- ✅ Shield state is consistent across all apps

**Pass Criteria:**
- No app-specific exceptions (all or nothing)
- Re-lock timing consistent across apps (≤5s for all)

---

## Timing Measurement

### Recommended Tools

**Screen Recording:**
```
Settings → Control Center → Add Screen Recording
Use stopwatch overlay app for precise timing
Record at 60fps for frame-accurate analysis
```

**Logging:**
Add timestamps to ExemptionManager expiry callback:
```swift
exemptionManager.startExemption(window: window) { [weak self] in
    let expiryTime = Date()
    print("⏰ Exemption expired at: \(expiryTime)")

    Task { @MainActor in
        let revokeStart = Date()
        self?.shieldController.revokeExemption(for: childId)
        let revokeEnd = Date()
        let duration = revokeEnd.timeIntervalSince(revokeStart)
        print("🛡️ Shield revoked in \(duration * 1000)ms")
    }
}
```

**Manual Stopwatch:**
- Start when countdown shows 0:00
- Stop when shield appears
- Repeat 5 times, average results

---

## Expected Results Summary

| Test | Requirement | Pass Criteria |
|------|-------------|---------------|
| Initial Shield | Shields apply on config | <2s application |
| Exemption Grant | Shields lift on redeem | <2s exemption |
| **Re-lock Timing** | **≤5s after expiry** | **<5s average** |
| App Restart | Shields persist | Config restored |
| Device Restart | Shields persist | Shields active |
| Stacking | Policy enforced | Correct behavior |
| Multi-App | Consistent state | All apps sync |

---

## Known Limitations

### ManagedSettings API Timing
- Apple's ManagedSettings framework has inherent latency
- Shield application is asynchronous (no completion callback)
- Actual timing may vary by device and iOS version
- Typical observed latency: 1-3 seconds

### Background Execution
- Timers may be delayed if app is backgrounded
- Use `NSBackgroundTask` for critical timing (future enhancement)
- Test with app in foreground for accurate results

### Simulator Limitations
- ⚠️ **ManagedSettings does NOT work in Simulator**
- Shields will appear as no-ops
- Must test on physical device

---

## Troubleshooting

### Shields Not Appearing
1. Verify entitlement is active (check Xcode capabilities)
2. Confirm authorization granted (AuthorizationCoordinator state)
3. Check FamilyActivitySelection is not empty
4. Review console logs for ManagedSettings errors

### Shields Not Lifting
1. Verify `shieldController.grantExemption()` is called
2. Check ManagedSettingsStore.shield properties are nil
3. Restart app to clear cached shield state

### Timing Inconsistency
1. Ensure app is in foreground during test
2. Disable Low Power Mode (affects timer precision)
3. Close background apps to reduce system load
4. Test on newer device (A12+ chip recommended)

---

## Success Criteria (P0-2)

✅ **PASS if:**
- Re-lock occurs ≤5 seconds in 90%+ of tests
- Average re-lock time <3 seconds
- Shields persist across app/device restarts
- No false positives (early shield application)

❌ **FAIL if:**
- Re-lock exceeds 5 seconds in >10% of tests
- Shields fail to persist after restart
- Exemption grants fail to lift shields

---

## Reporting Results

Document test results in `docs/test-results/shield-testing-results.md`:

```markdown
## Test Date: 2025-10-05
**Device**: iPhone 14 Pro, iOS 17.5
**Build**: Debug, ParentiOS target

### Test 3: Re-lock Timing (5 trials)
1. 2.3s ✅
2. 3.1s ✅
3. 4.2s ✅
4. 2.8s ✅
5. 3.5s ✅

**Average**: 3.18s
**Max**: 4.2s
**Pass/Fail**: PASS ✅
```

---

## Next Steps After Testing

1. If tests pass: Mark P0-2 complete in `docs/checklists.md`
2. If tests fail: Investigate latency sources, consider:
   - Preemptive shield application (1-2s before expiry)
   - Background task for guaranteed timer execution
   - Push notification as backup expiry trigger
3. Document findings in `docs/progress-log.md`
4. Update PRD implementation status
