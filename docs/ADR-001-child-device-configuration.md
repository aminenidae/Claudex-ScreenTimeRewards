# ADR-001: Child Device as Primary Configuration Point

**Status:** Accepted
**Date:** 2025-10-11
**Decision Makers:** Product + Engineering
**Impact:** High - Requires architectural pivot

---

## Context

During implementation of EP-03 (App Categorization), we discovered a fundamental limitation in Apple's Family Controls framework that affects the entire product architecture.

### The Discovery

**Metadata Extraction Spike (Failed):**
- Attempted to extract app names from ApplicationTokens using `accessibilityLabel` traversal
- Tested `ManagedSettings.Application` API for `localizedDisplayName` and `bundleIdentifier`
- Results: 0% name extraction, 100% icon extraction
- Confirmed: **Apple intentionally prevents cross-device app identification for privacy**

**Critical Realization:**
The token limitation doesn't just affect the UI picker experience - it fundamentally breaks the enforcement mechanism:

1. Parent's device shows parent's apps in FamilyActivityPicker
2. Parent selects "TikTok" → gets `Token_A` (parent's device)
3. `Token_A` syncs to CloudKit
4. Child's device downloads `Token_A`
5. Child's device tries to shield apps using `Token_A`
6. **FAILS** - `Token_A` doesn't match child's TikTok (`Token_B`)
7. Child's TikTok stays unblocked ❌

**Why This Happens:**
- ApplicationTokens are **device-specific opaque identifiers**
- Cannot be decoded, transferred, or used across devices
- Apple's privacy model prevents parent from identifying child's specific apps
- `ManagedSettings.shield.applications` only works with tokens from the same device

### Previous Architecture (Parent-Centric)

**Original Design:**
```
Parent Device (Primary)
├── App Categorization (Learning/Reward selection)
├── Points Configuration (rates, caps, ratios)
├── Dashboard (monitoring)
├── Rules Management (remote control)
└── CloudKit Sync → Child Device (passive receiver)

Child Device (Passive)
├── Receive rules from CloudKit
├── Apply shields using received tokens ❌ BROKEN
├── Track usage
└── Report back to parent
```

**Fatal Flaw:** Shields cannot be applied using tokens from parent's device.

---

## Decision

**We will restructure the application architecture to make the child's device the primary configuration point for app-specific rules.**

### New Architecture (Child-Device-Centric)

```
Parent Device (Monitoring & Oversight)
├── Child Profile Management (pairing, adding children)
├── Dashboard (read-only monitoring)
│   ├── Points balance
│   ├── Learning time
│   ├── Redemption history
│   └── Shield status
├── Data Export (CSV/JSON)
├── Point Adjustments (manual overrides)
└── CloudKit Sync (read child data)

Child Device (Primary Configuration)
├── Parent Mode (PIN-Protected) ⭐ NEW PRIMARY
│   ├── App Categorization (Learning/Reward)
│   ├── Points Configuration (rates, caps, ratios)
│   ├── Redemption Rules (min/max, stacking policies)
│   ├── Shield Management
│   └── CloudKit Sync (write rules)
├── Child Mode (Regular Use)
│   ├── Points Balance Display
│   ├── Redemption Requests
│   ├── Active Shield Countdown
│   └── Recent Activity
└── Enforcement Layer (works with local tokens) ✅
    ├── ShieldController (uses child's tokens)
    ├── DeviceActivityMonitor
    ├── PointsEngine
    └── ExemptionManager
```

### Key Changes

**1. Parent Mode Moves to Child Device**
- All app categorization happens on child's device (where tokens work)
- PIN-protected to prevent child tampering
- Parent physically uses child's device for initial setup

**2. Parent Device Becomes Monitoring Dashboard**
- Read-only view of child's progress
- Data export and reporting
- Manual point adjustments (remote)
- No app selection UI

**3. Tokens Always Work**
- Configuration and enforcement on same device
- Shields reliably block correct apps
- No cross-device token issues

---

## Rationale

### Why This is the ONLY Solution

**Technical Constraints:**
1. **ApplicationTokens are device-specific** - Confirmed by Apple documentation and spike testing
2. **ManagedSettings requires same-device tokens** - Cannot shield apps with tokens from another device
3. **No API for cross-device token resolution** - Apple provides no mechanism to match tokens between devices
4. **Privacy by design** - Apple intentionally prevents parents from seeing child's app names

**Alternative Approaches Considered:**

**Option A: Category-Only Selection** ❌
- Parent selects categories (Education, Games, etc.) instead of individual apps
- **Problem:** Categories might not work reliably cross-device either
- **Problem:** Still shows parent's apps in picker (confusing UX)
- **Problem:** Less granular control

**Option B: Parent Uses Child's Physical Device (Supervised)** ⚠️
- Parent physically takes child's device for configuration
- **Problem:** Awkward UX (feels like borrowing device)
- **Problem:** Not remote-friendly
- **Decision:** This is essentially what we're doing, but formalizing it

**Option C: Child Selects, Parent Approves (Hybrid)** 🤔
- Child categorizes apps, parent reviews/approves
- **Problem:** More complex flow
- **Problem:** Child sees what they're selecting
- **Decision:** Could be future enhancement

**Option D: APNs for Remote Triggering** 📱
- Use push notifications to prompt configuration on child's device
- **Assessment:** Nice-to-have enhancement, doesn't solve core issue
- **Decision:** Future enhancement

### Why Child-Device-Centric is Best

1. **Tokens Always Work** - Configuration and enforcement on same device
2. **Aligns with Apple's Model** - Similar to Screen Time (configured on device itself)
3. **Clear User Mental Model** - "Settings live where the apps are"
4. **Reliable Enforcement** - Shields work because tokens match
5. **Future-Proof** - Won't break if Apple changes token implementation

---

## Consequences

### Positive

✅ **Reliable App Shielding** - Tokens always match, enforcement works
✅ **Clear UX** - "Configure on child's device" is easy to explain
✅ **Aligned with Platform** - Matches Apple's Screen Time model
✅ **Privacy-Preserving** - Respects Apple's privacy protections
✅ **Simpler Parent App** - No confusing multi-family app picker

### Negative

❌ **Requires Physical Access** - Parent must use child's device for setup
❌ **Not Fully Remote** - Cannot change rules from parent's device
❌ **Initial Setup Friction** - Both devices needed for first-time setup
❌ **Pivot Required** - Existing parent-side UI must be rebuilt

### Migration Impact

**Code Changes Required:**

1. **Move AppCategorizationView to Child App** (new ParentMode section)
2. **Simplify Parent Dashboard** (remove categorization UI, keep monitoring)
3. **Add PIN Protection** to child device's parent mode
4. **Update CloudKit Sync Direction** (child writes, parent reads)
5. **Restructure Service Dependencies** (enforcement stays on child)

**Documentation Updates:**

- PRD: Update architecture section and user flows
- Checklists: Reflect child-device-centric responsibilities
- Progress Log: Document the pivot and rationale
- User Guide: Explain setup process (both devices needed)

**Testing Changes:**

- EP-03 tests: Focus on child-device configuration
- Shield tests: Validate same-device token usage
- Parent dashboard tests: Read-only monitoring flows

---

## Implementation Plan

### Phase 1: Documentation & Planning (Current)
- ✅ Create ADR documenting decision
- [ ] Update PRD with new architecture
- [ ] Update progress-log.md
- [ ] Update checklists.md
- [ ] Create migration plan

### Phase 2: Child Device Parent Mode
- [ ] Design PIN-protected parent mode for child device
- [ ] Move AppCategorizationView to child app
- [ ] Implement CategoryRulesManager on child device
- [ ] Add points configuration UI
- [ ] Add redemption rules UI

### Phase 3: Parent Dashboard Simplification
- [ ] Remove app categorization from parent device
- [ ] Keep monitoring dashboard (read-only)
- [ ] Keep data export
- [ ] Keep point adjustments (remote)

### Phase 4: CloudKit Sync Updates
- [ ] Update sync direction (child writes, parent reads)
- [ ] Add parent mode state sync
- [ ] Handle multi-parent scenarios

### Phase 5: Testing & Documentation
- [ ] Test end-to-end setup flow (both devices)
- [ ] Validate shield enforcement with same-device tokens
- [ ] Create user guide explaining setup process
- [ ] Update App Store screenshots and description

---

## Lessons Learned

**For Future Platform Integration:**

1. **Spike Early** - Test critical assumptions before building UI
2. **Read Documentation Carefully** - Token limitations were documented, but subtle
3. **Test Cross-Device Scenarios** - Don't assume APIs work the same across devices
4. **Respect Platform Privacy Models** - Apple's privacy-first design affects architecture
5. **Be Ready to Pivot** - Sometimes platform constraints require architectural changes

**Key Insight:**
> Apple's Family Controls framework is designed for **same-device configuration**, not remote parental control. Our architecture must align with this design, not fight it.

---

## References

- Apple Family Controls Documentation: https://developer.apple.com/documentation/familycontrols
- Apple Screen Time Implementation (similar model)
- Metadata Extraction Spike Results (apps/ParentiOS/Utils/MetadataExtractionSpike.swift)
- Issue Tracker: docs/issues/app-categorization-family-sharing-issue.md
- Technical Brief: TECHNICAL_BRIEF_FAMILY_CONTROLS_LIMITATION.md

---

## Approval

**Approved By:** Product + Engineering
**Date:** 2025-10-11
**Next Review:** Post-MVP (evaluate APNs enhancement)
