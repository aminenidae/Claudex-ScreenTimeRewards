# Architecture Clarification Needed - Parent Mode Access

## Current Implementation (WRONG ❌)

```
App Launch
    ↓
ModeSelectionView
    ├─→ Parent Mode (?)
    │       ↓
    │   [What should be here?]
    │
    └─→ Child Mode (For child to use)
            ↓
        ChildModeHomeView
            ├─ My Rewards card
            ├─ My Points balance
            ├─ Redeem button
            └─ [WRONG] Gear icon in toolbar ❌
                    ↓
                PIN Entry Sheet
                    ↓
                ChildDeviceParentModeView (4 tabs)
                    ├─ Apps (categorization)
                    ├─ Points (configuration)
                    ├─ Rewards (rules)
                    └─ Settings
```

### Problem
- Gear icon gives child access to Parent Mode configuration
- Even with PIN protection, child can see there's a Parent Mode
- Architecture mixing Child Mode (child interface) with Parent Mode (parent configuration)

---

## What User Said

> "the loading page has two modes: Parent mode for the parents to configure the App, Child mode ONLY for the child to monitor/redeem the rewards"

### Interpretation
- **Loading page** = ModeSelectionView (app launch)
- **Parent mode** = For parents to configure
- **Child mode** = ONLY for child (no parent access)

---

## Possible Correct Architecture #1: Separate Modes

```
App Launch
    ↓
ModeSelectionView
    ├─→ Parent Mode
    │       ↓
    │   [PIN Protection Here?]
    │       ↓
    │   ChildDeviceParentModeView (4 tabs)
    │       ├─ Apps (categorization)
    │       ├─ Points (configuration)
    │       ├─ Rewards (rules)
    │       └─ Settings
    │
    └─→ Child Mode (PIN protected? or open?)
            ↓
        ChildModeHomeView
            ├─ My Rewards card
            ├─ My Points balance
            ├─ Redeem button
            └─ [NO gear icon]
```

### Questions
1. Is Parent Mode PIN-protected at mode selection?
2. Or is mode selection open, then PIN inside Parent Mode?
3. Should Child Mode have any access to parent features?

---

## Possible Correct Architecture #2: Device-Specific

### On Child's Device
```
App Launch
    ↓
ModeSelectionView
    ├─→ Parent Mode (PIN required)
    │       ↓
    │   ChildDeviceParentModeView
    │   (Configuration - apps, points, rules)
    │
    └─→ Child Mode
            ↓
        ChildModeHomeView
        (Monitor points, redeem rewards)
```

### On Parent's Device
```
App Launch
    ↓
ModeSelectionView
    ├─→ Parent Mode
    │       ↓
    │   ParentDashboardView
    │   (Monitoring only - read-only)
    │
    └─→ Child Mode
            ↓
        (Maybe for testing? Or hidden?)
```

### Questions
1. Are we talking about ONE device or TWO devices?
2. Post-pivot: Configuration on child's device, monitoring on parent's?
3. Should ModeSelectionView detect device role automatically?

---

## Possible Correct Architecture #3: Single Parent Device

```
App Launch
    ↓
ModeSelectionView
    ├─→ Parent Mode
    │       ↓
    │   [PIN Protection]
    │       ↓
    │   ParentModeView
    │       ├─ Configure Apps (local tokens)
    │       ├─ Configure Points
    │       ├─ Configure Rewards
    │       └─ Monitor Dashboard
    │
    └─→ Child Mode
            ↓
        ChildModeHomeView
        (For parent to test/demo)
```

### But This Conflicts With:
- Post-pivot decision: Configuration must be on child's device (tokens are device-specific)
- So Parent Mode can't be on parent's device for configuration

---

## What I Need to Know

### 1. Device Context
- [ ] Is Parent Mode on CHILD's device or PARENT's device?
- [ ] Or are we building for BOTH devices?
- [ ] Should the app detect device role automatically?

### 2. Mode Selection
- [ ] Should mode selection be at app launch (ModeSelectionView)?
- [ ] Or should mode be pre-configured per device?
- [ ] Should both modes always be available?

### 3. PIN Protection
- [ ] When is PIN required?
  - [ ] At mode selection (before entering Parent Mode)?
  - [ ] After entering Parent Mode?
  - [ ] Only on first launch?
  - [ ] Every time?

### 4. Child Mode Access
- [ ] Should Child Mode have ANY access to parent features?
- [ ] Should there be a "parent override" in Child Mode?
- [ ] Or should Child Mode be completely locked down?

### 5. Gear Icon
- [ ] Should there be a gear icon anywhere?
- [ ] If yes, where and what should it do?
- [ ] If no, remove it entirely?

---

## Post-Pivot Constraints

From ADR-001 and pivot documentation:

1. **ApplicationTokens are device-specific**
   - Parent's device tokens ≠ Child's device tokens
   - Can't select apps on parent device and shield on child device
   - Configuration (app categorization) MUST happen on child's device

2. **Implications**
   - Parent Mode configuration (Apps tab) must be on child's device
   - Parent's device can only be monitoring/read-only
   - OR: Parent installs app on their own device for testing but can't shield child's device

3. **CloudKit Sync**
   - Child device writes configuration (points rules, redemption rules)
   - Parent device reads configuration for monitoring
   - App categorization is local-only (tokens don't sync)

---

## Recommended Next Steps

1. **User clarifies architecture** (device context, mode access pattern)
2. **I create visual diagram** of correct architecture
3. **We agree on design** before writing code
4. **Then implement properly** with documentation

---

## Files That Need Rework

Once architecture is clear:

### If Parent Mode is on child's device
- `ClaudexApp.swift` - Change mode selection to launch-time choice
- `ChildDeviceParentModeView.swift` - Keep but change access pattern
- Remove gear icon from Child Mode

### If Parent Mode is on parent's device
- Need new `ParentDeviceParentModeView.swift` for monitoring
- `ChildDeviceParentModeView.swift` becomes config-only, stays on child device
- Need device role detection

### PIN Protection
- Might move from `ChildDeviceParentModeView` to `ModeSelectionView`
- Or keep inside Parent Mode but change how it's accessed

---

## Current Blockers

❌ Cannot proceed with implementation until architecture is clarified
❌ PIN UI issue secondary to architecture problem
❌ All work depends on understanding correct mode access pattern

**Awaiting user clarification before making any more changes.**
