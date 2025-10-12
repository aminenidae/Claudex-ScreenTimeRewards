# Architecture Confirmed - October 11, 2025

## User Clarifications Received

### Parent Mode (on CHILD's device)
- ✅ Configure app categories (Learning/Reward)
- ✅ Set points rules **BY APP** - each selected app has its own point settings
- ✅ Monitor child's activity
- ✅ Setup screentime config
- 🔐 **PIN-protected at mode selection level** (before entering Parent Mode)

### Child Mode (on CHILD's device)
- ✅ See points balance
- ✅ Redeem points **PER APP** - points can go totally or partially to specific app
- ✅ Remaining points can be used for other apps
- ✅ See active reward time
- 📋 More features to be advised later

### Key Decisions
1. **PIN Protection**: At mode selection level (not inside Parent Mode)
2. **Gear Icon**: Not needed. The parent should authenticate with their own PIN/biometric authentication as parent/organizer/guardian
3. **Parent Mode Location**: On CHILD's device
4. **Points System**: Per-app (NOT global per child)

---

## Architecture Diagram (Correct)

### Child's Device
```
App Launch
    ↓
ModeSelectionView
    ├─→ [Parent Mode] button
    │       ↓
    │   🔐 Authentification (protects from child)
    │       ↓
    │   ParentDeviceParentModeView (Monitoring Dashboard For All Family Members)
    │       ├─ Child Tab: DashboardView (aggregated points balance)
    │       └─ Account Tab: Manage SubscriptionView (future)
    │       ↓
    │   ChildDeviceParentModeView
    │       ├─ Apps Tab: Configure Learning/Reward categories (App selection)
    │       ├─ Points Tab: Set points rules PER APP (App list updates based on app selection)
    │       ├─ Rewards Tab: Set redemption rules PER APP (App list updates based on app selection)
    │       └─ Settings Tab: Screentime config, PIN management
    │
    └─→ [Child Mode] button (no PIN)
            ↓
        ChildModeHomeView
            ├─ Points balance (per-app)
            ├─ Redeem points PER APP
            │   └─ Partial or full redemption
            │   └─ Remaining points available for other apps
            └─ Active reward time display
```

### Parent's Device (Not Yet Implemented)
```
App Launch
    ↓
ModeSelectionView
    ├─→ [Parent Mode] button
    │       ↓
    │   ParentDeviceParentModeView (Monitoring Dashboard)
    │       ├─ Monitor child's activity (read-only)
    │       ├─ View points history
    │       ├─ View redemptions
    │       └─ ⚙️ Gear icon for settings (future)
    │
    └─→ [Child Mode] button (for testing)
            ↓
        (Maybe disabled or demo mode)
```

---

## Critical Discovery: Per-App Points System

### Current Implementation (WRONG ❌)
- **PointsLedger**: Tracks points globally per child
  ```swift
  childId: ChildID → total points balance
  ```
- **Redemption**: Deducts from global balance
- **Configuration**: Global points-per-minute, global daily cap

### Required Implementation (CORRECT ✅)
- **PointsLedger**: Tracks points per app per child
  ```swift
  childId: ChildID → appId: AppID → points balance
  ```
- **Redemption**: Deducts from specific app balance
  - Can redeem partial points from one app
  - Can redeem remaining points from other apps
- **Configuration**: Per-app points-per-minute, per-app daily cap

### Impact
🔴 **MAJOR REFACTOR REQUIRED**
- PointsLedger data model change
- PointsEngine tracking per app
- Redemption UI per app
- Configuration UI per app
- All tests need updates

---

## What's Wrong with Current Implementation

### 1. Mode Selection & PIN Protection ❌
**Current**:
- Gear icon in Child Mode → PIN entry → Parent Mode

**Correct**:
- Mode selection at launch
- "Parent Mode" button → PIN entry → Parent Mode
- "Child Mode" button → Child Mode (no PIN)

**Files to Fix**:
- `apps/ParentiOS/ClaudexApp.swift` - Modify ModeSelectionView to add PIN before Parent Mode
- Remove gear icon from ChildModeView

---

### 2. Gear Icon Location ❌
**Current**:
- Gear icon in Child Mode on child device

**Correct**:
- NO gear icon in Child Mode
- Gear icon should be in Parent Mode on parent device (monitoring dashboard)
- Parent device monitoring not yet implemented

**Files to Fix**:
- `apps/ParentiOS/ClaudexApp.swift` - Remove gear icon from ChildModeView

---

### 3. Points System Architecture ❌
**Current**:
- Global points balance per child
- Global points-per-minute configuration
- Global redemption

**Correct**:
- Per-app points balance per child
- Per-app points-per-minute configuration
- Per-app redemption (partial or full)
- Remaining points available for other apps

**Files to Refactor**:
- `Sources/Core/AppModels.swift` - Add AppID to PointsLedgerEntry
- `Sources/PointsEngine/PointsLedger.swift` - Track points per app
- `Sources/PointsEngine/PointsEngine.swift` - Accrue points per app
- `Sources/PointsEngine/RedemptionService.swift` - Redeem per app
- `apps/ParentiOS/Views/ChildDeviceParentModeView.swift` - Configuration per app
- `apps/ParentiOS/Views/ChildModeHomeView.swift` - Display per-app balances
- Need new view for per-app redemption

---

## Action Plan (Prioritized)

### Priority 1: Fix Mode Selection & PIN Protection ✅
**Effort**: Small (1-2 hours)
**Impact**: Unblocks architecture

**Changes**:
1. Modify `ClaudexApp.swift`:
   - Add PIN protection to "Parent Mode" button in ModeSelectionView
   - Remove gear icon from ChildModeView
   - Keep PIN sheets/covers but trigger from mode selection

**Deliverable**: Correct mode selection flow with PIN protection

---

### Priority 2: Document Per-App Points System 📋
**Effort**: Documentation (1 hour)
**Impact**: Critical for coordination

**Deliverables**:
1. Detailed data model for per-app points
2. User stories for per-app redemption
3. UI mockups for per-app configuration
4. Migration plan from current implementation

**Block**: Need more clarification on:
- How to display per-app balances in Child Mode?
- How to select which app to redeem for?
- Can child see points for reward apps before earning them?
- What happens if child has 0 points for a learning app?

---

### Priority 3: Fix PIN Setup UI 🔧
**Effort**: Medium (2-4 hours)
**Impact**: Blocking user testing

**Approach**:
- Test on actual device (not simulator)
- Use GeometryReader to calculate available space
- Consider alternative layouts (button in navigation bar?)

**Deliverable**: Working PIN setup flow

---

### Priority 4: Implement Per-App Points System 🔴
**Effort**: Large (2-3 days)
**Impact**: Core functionality

**Phases**:
1. Data model refactor
2. PointsEngine per-app tracking
3. Configuration UI per app
4. Redemption UI per app
5. Testing
6. Migration

**Block**: Awaiting Priority 2 documentation and user feedback

---

## Questions for User (Per-App Points System)

### Display & UX
1. **Child Mode Points Display**:
   - Show aggregated total? Or list per-app balances? Per App balances.
   - Example: "Total: 500 points" or "Khan Academy: 200, Duolingo: 300"

2. **Redemption Flow**:
   - How does child select which app to unlock?
   - UI: Dropdown? Grid of app icons? List? Grid of app icons with points
   - Can child see their balance for each app before selecting? YES

3. **Partial Redemption**:
   - Child has 200 points in Khan Academy
   - Wants to unlock Instagram (costs 300 points)
   - Flow: Use 200 from Khan Academy, 100 from Duolingo? Yes
   - Or: Show error "Not enough points in Khan Academy"? No

4. **Zero Balance Apps**:
   - If child has 0 points in a learning app, show it as 0? Yes
   - Or hide apps with 0 balance? No

### Configuration
5. **Per-App Point Rules**:
   - Each learning app has its own points-per-minute? YES (Configured by Parent)
   - Example: Khan Academy = 10 pts/min, Duolingo = 15 pts/min?
   - Or: All learning apps earn same rate? No

6. **Per-App Daily Cap**:
   - Each learning app has its own daily cap? YES (Configured by Parent)
   - Or: Global daily cap across all learning apps? NO (but parent will set the total daily cap of reward apps)

7. **Cross-App Redemption**:
   - Can points from any learning app unlock any reward app? YES
   - Or: Khan Academy points only unlock Education-tagged rewards? No

### Data Model
8. **Point Tracking**:
   - Option A: Separate balance per app
     - `childId → appId → balance`
     - Allows per-app rules, per-app redemption
   - Option B: Global pool with per-app earning rates
     - `childId → total balance`
     - Earn at different rates per app, but single pool
   - Which model matches your vision? Option A

### User Responses (2025-10-12)
- Show per-app balances in Child Mode (grid of app icons with points) and surface balances before redemption.
- Partial redemption can combine points from multiple learning apps automatically; do not block when a single app lacks sufficient points.
- Apps with zero balance should remain visible (display `0`).
- Parents configure points-per-minute and daily caps per learning app; they also define a total daily cap for reward apps.
- Any learning app’s points can unlock any reward app.
- **Data model choice:** Option A – maintain balances per app. (Earlier Option B response retracted to avoid conflict with per-app balances.)

---

## Immediate Next Steps

1. **Fix mode selection (Priority 1)** - Can do now
2. **Wait for per-app points clarification** - Blocking Priority 4
3. **Fix PIN UI (Priority 3)** - Can do in parallel

**Which should I tackle first?**
- Option A: Fix mode selection now (unblocks architecture)
- Option B: Answer per-app points questions first (informs all design)

---

## Files Staged for Changes

### Immediate (Priority 1)
- `apps/ParentiOS/ClaudexApp.swift` - Mode selection fix

### After Clarification (Priority 4)
- `Sources/Core/AppModels.swift`
- `Sources/PointsEngine/PointsLedger.swift`
- `Sources/PointsEngine/PointsEngine.swift`
- `Sources/PointsEngine/RedemptionService.swift`
- `apps/ParentiOS/Views/ChildDeviceParentModeView.swift`
- `apps/ParentiOS/Views/ChildModeHomeView.swift`
- New: `apps/ParentiOS/Views/PerAppRedemptionView.swift`

---

## Coordination Notes

- **Other developer**: Can work on PIN UI fix (Priority 3) while I handle mode selection
- **Documentation**: All per-app points design should be documented before coding
- **Testing**: Per-app system needs comprehensive test suite
- **Migration**: Need plan for existing data (if any)

---

## Status: Ready to Proceed

✅ Architecture clarified
✅ Issues identified
✅ Action plan created
⏸️ Awaiting decision on next priority

**Awaiting user confirmation to proceed with Priority 1 (mode selection fix) or wait for per-app points clarification.**
