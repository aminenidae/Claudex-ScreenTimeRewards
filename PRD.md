# Product Requirements Document (PRD)

Reward-Based Screen Time Management App

Version: 1.0 (MVP)

Owners: Product + Engineering

Last Updated: YYYY-MM-DD

## 1. Overview

This PRD defines the MVP for a reward-based screen time management app that reframes screen time from a restrictive model into a positive, earned-privilege system. Parents configure which apps are “learning” vs “reward,” set point rates for learning, and children convert earned points into time allowances for reward apps. The app uses Apple’s Screen Time APIs with the Family Controls entitlement to monitor app usage and apply app shields/exemptions.

## 2. Goals

- Reduce family conflict around screen time by incentivizing learning.
- Increase educational app usage among children.
- Provide parents with simple controls and clear visibility of outcomes.
- Maintain strict privacy, compliance, and App Store review alignment.

## 3. Scope (MVP)

- Platforms: Single universal iOS/iPadOS 16+ app with parent and child modes.
- APIs: Apple Screen Time APIs (FamilyControls, ManagedSettings, DeviceActivity) and DeviceActivityReport extension.
- Data: CloudKit-based sync and storage (privacy-first); no third-party trackers in child context.
- In: Parent/child onboarding, authorization, app categorization, point accrual, redemption to earned time, shielding/exemptions, dashboard, weekly reporting, minimal anti-abuse guardrails, multi-parent sync with audit entries.
- Out (MVP): Real-world rewards marketplace, advanced analytics, adaptive difficulty, competitions, third-party integrations, subject-specific multipliers.

## 4. Non-Goals (MVP)

- Auto-importing Family Sharing roster (not possible via public API).
- Android/web child clients.
- Detailed per-event raw timeline storage of child usage.
- Teacher/Institutional accounts.

## 5. Users & Roles

- Parent Admin (Parent Mode within app): Full control; can authorize children via system UI, set point rates, categorize apps, redeem, review history.
- Co-Parent (Parent Mode): Same as Parent by default; optionally restricted on destructive actions; all actions audited.
- Child (Child Mode within app): No configuration; can view points and request redemption; child surfaces are informational/request-based only.

## 6. User Stories (MVP)

US-01 Parent Onboarding
- As a parent, I can set up the app and grant Family Controls authorization to manage my child.
- Acceptance: Authorization prompt displayed; app reflects authorized state; no access without authorization.

US-02 Add Child via System UI
- As a parent, I can add one or more children from my Family Sharing group using Apple’s authorization UI.
- Acceptance: Parent can add N children via repeated flow; app stores opaque identifiers; no PII required.

US-03 Child Pairing (App Instance)
- As a parent/child, we can pair the child’s device app instance with the authorized child context (code or deep link).
- Acceptance: Pairing completes under 2 minutes; incorrect code is handled; revocation supported.

US-04 App Categorization
- As a parent, I can label apps as “learning” or “reward,” including category-based defaults and manual overrides.
- Acceptance: Selected apps/categories persist; conflicts resolved deterministically; overrides win over defaults.

US-05 Point Accrual
- As a child, I earn points while actively using learning apps.
- Acceptance: Points accrue only for foreground, unlocked usage; rate is configurable; daily cap and idle timeout enforced.

US-06 Redemption to Earned Time
- As a child, I can convert points to time for reward apps, with clear feedback and countdown.
- Acceptance: Exemption applies immediately; countdown decrements live; re-lock occurs on expiry.

US-07 Shields & Controls
- As a parent, I can ensure reward apps are blocked except during earned-time windows.
- Acceptance: Shields applied; exemptions honored; re-lock within 5 seconds of expiry.

US-08 Dashboard & Reports
- As a parent, I can see current points, recent learning time, reward time used, and weekly summaries.
- Acceptance: DeviceActivityReport extension shows weekly aggregates; dashboard matches within ±5%.

US-09 Multi-Parent
- As a family, both parents can configure settings and see activity with consistency across devices.
- Acceptance: Changes sync within 2s online; last-writer-wins with audit log entries.

US-10 Notifications
- As a parent/child, I receive helpful notifications for thresholds (e.g., cap reached, time expiring).
- Acceptance: Opt-in; rate-limited; actionable where relevant.

US-11 Privacy & Controls
- As a parent, I can export/delete my family’s data and understand what is stored.
- Acceptance: Data export and deletion flows work; disclosures shown; no trackers in child context.

## 7. Functional Requirements

FR-01 Authorization (FamilyControls)
- Request and manage Family Controls authorization; reflect status in UI.
- Error states: denied, restricted, revoked.

FR-02 Child Selection via System UI
- Present Apple’s child selection UI; store opaque child contexts for each authorized child.
- No programmatic enumeration of family roster; flow must be initiated by parent.

FR-03 Pairing Flow
- Generate pairing code or deep link to associate child app instance with a child context.
- Support re-pairing and revocation.

FR-04 App Categorization & Rules
- Category defaults for “learning” and “reward”; manual overrides per app.
- Conflict resolution: app override > category default.

FR-05 Points Engine
- Configurable accrual rate (e.g., X points/minute).
- Foreground-only while unlocked; idle timeout (no activity for N minutes => pause accrual).
- Daily cap and optional rate limit burst control; transaction log for accruals.

FR-06 Redemption & Exemptions
- Convert points to earned time at a configurable ratio.
- Start/extend exemptions for reward apps; live countdown; auto re-lock.
- Prevent negative balance; enforce min/max redemption sizes.

FR-07 Shields (ManagedSettings)
- Apply shields to reward apps/categories; ensure blocked outside exemption windows.
- Re-apply shields after device restart/resume.

FR-08 Parent Dashboard
- Show points balance, today/weekly learning time, recent redemptions, current shields/exemptions state.

FR-09 Weekly Reporting (DeviceActivityReport)
- Provide weekly summaries of learning and reward usage; chart or table.

FR-10 Multi-Parent & Audit
- Cloud sync with last-writer-wins; audit entries for changes (who/when/what).

FR-11 Notifications
- Parent: entitlement changes, weekly summaries, threshold alerts.
- Child: redemption success, time expiring (local notification).

FR-12 Privacy & Controls
- Data export and deletion; disclosures in-app; parental gate for settings.

FR-13 Accessibility & Localization
- Support Dynamic Type, VoiceOver, sufficient contrast; prepare for localization (English MVP).

## 8. Non-Functional Requirements

- Performance: <5% daily battery impact on child device; smooth UI (60 fps targets where feasible).
- Reliability: Re-lock within 5 seconds of exemption expiry; recovery after app/device restart.
- Storage: <100 MB app size; compact CloudKit footprint.
- Security: Least-privilege access; Keychain for secrets; encrypt sensitive data at rest.
- Privacy: Data minimization; no third-party tracking/ads in child context; COPPA/GDPR-K compliance.
- Offline: Continue accrual with local buffers; reconcile on reconnect; conflict resolution deterministic.
- Observability: Structured logs; essential telemetry in parent context only; no PII.

## 9. Anti-Abuse & Integrity (MVP)

- Foreground-only accrual; require unlocked device.
- Idle timeout (no interaction or activity events => pause accrual).
- Daily caps and rate limits; redemption min/max.
- Optional micro-interactions for first-party learning content (where applicable).
- Detect clock manipulation via monotonic timers for session calculations.

## 10. Platform & Architecture

- Apps: SwiftUI-first for iOS/iPadOS; UIKit where necessary.
- Modules: Core (models/services), ScreenTimeService (FamilyControls/DeviceActivity/ManagedSettings), PointsEngine, ShieldController, Sync (CloudKit), UI, Notifications, Report Extension.
- Data Layer: CloudKit (shared DB) for families, child contexts, rules, balances, transactions, audit entries.
- Extensions: DeviceActivityReport for weekly summaries.

## 11. Data Model (Initial)

- Family { id (CloudKit), createdAt }
- ParentProfile { id, familyId, role, deviceIds }
- ChildContext { id (opaque from API), familyId, displayName (optional), pairedDeviceIds }
- AppRule { id, familyId, bundleId, classification: learning|reward, source: default|override }
- PointsLedgerEntry { id, childId, type: accrual|redemption|adjustment, amount, timestamp, reason }
- EarnedTimeBalance { childId, balanceSeconds, updatedAt }
- ShieldPolicy { familyId, rewardCategories, rewardApps }
- AuditEntry { id, actorParentId, action, target, timestamp, metadata }

Note: Store only aggregates where possible; avoid raw event timelines.

## 12. Key Flows & Acceptance Criteria

12.1 Parent Onboarding (iOS)
- Steps: Welcome → Authorization request → Success state → Add Child CTA.
- Acceptance: Denied/restricted paths handled; retry supported.

12.2 Add Child via System UI
- Steps: Add Child → Present system UI → Parent selects child → App stores context.
- Acceptance: Multiple children supported; no listing programmatically; revocation handled.

12.3 Pair Child App (iOS)
- Steps: Parent generates code/deep link → Child enters code/taps link → Linked.
- Acceptance: Under 2 minutes; error states clear; unlink available.

12.4 Categorize Apps
- Steps: Choose categories and overrides for learning/reward.
- Acceptance: Override wins; persistence verified after restart.

12.5 Earn Points
- Steps: Child uses learning app → DeviceActivity reports usage → Points accrue.
- Acceptance: Idle timeout pauses accrual; daily cap enforced; logs recorded.

12.6 Redeem Points → Earned Time
- Steps: Child requests redemption → Parent confirms or auto-policy applies → Exemption starts → Countdown visible.
- Acceptance: Countdown accurate (±5s); re-lock on expiry; no negative balance.

12.7 Weekly Report
- Steps: Parent opens report → See weekly totals for learning/reward usage and redemptions.
- Acceptance: Matches dashboard within ±5%.

12.8 Multi-Parent Sync
- Steps: Parent A changes point rate → Parent B sees update quickly.
- Acceptance: <2s latency online; audit entry created.

## 13. Analytics & Metrics (MVP)

- Setup Completion: % of families with at least one parent and one child paired.
- Earning Activity: % of families with weekly point accrual; median points.
- Redemption Activity: % of families with weekly redemptions; median count.
- Control Effectiveness: Shield blocks vs exemptions granted; re-lock timing.
- Engagement: WAU/MAU for parents; weekly task completion rates.

Note: No analytics in child-facing surfaces beyond essential local logic; telemetry only in parent context.

## 14. Monetization

- Model: Subscription (monthly/yearly), family plan. MVP may ship without paywall; if included, limit premium to advanced controls/reporting.
- Trials: Intro offer; clear cancellation instructions.
- Compliance: Kids Category and parental-control rules.

## 15. Privacy, Security, and Compliance

- COPPA/GDPR-K: Parental consent flows; data export/delete; transparent disclosures.
- Data Minimization: Aggregates only; no third-party trackers/ads in child UI.
- Security: Keychain, encrypted at rest, least-privilege CloudKit access.

## 16. Accessibility & Localization

- Accessibility: Dynamic Type, VoiceOver, contrast, hit targets.
- Localization: English MVP; structure strings for future locales.

## 17. Error Handling & Offline

- Offline accrual with eventual consistency; conflict resolution deterministic.
- Clear messaging for entitlement/authorization errors and revocation.

## 18. Dependencies & Risks

- Dependencies: Apple Family Controls entitlement; iOS/iPadOS versions; CloudKit availability.
- Risks: Entitlement approval timing; API limitations; App Review; user adoption; privacy concerns.
- Mitigations: Early spikes (see docs/feasibility.md), strict adherence to guidelines, user research.

## 19. Rollout & Milestones (Indicative)

- M1: Spikes complete; entitlement request package ready.
- M2: Authorization + child selection + shields/exemptions prototype.
- M3: Points engine + redemption + dashboard.
- M4: Reporting extension + notifications + audit trail.
- M5: Hardening, privacy review, accessibility pass, beta (TestFlight).

## 20. Acceptance Criteria (Go/No-Go)

- DeviceActivity reliably reports foreground usage for selected apps/categories.
- ManagedSettings shields and exemptions are reliable and recover after restarts.
- Pairing and roles function with clear parental gating.
- Anti-abuse guardrails prevent trivial farming within thresholds.
- Cloud sync works with conflict handling; audits present.
- App passes internal privacy/accessibility checks.

## 21. Open Questions

- Redemption UX: Parent approval required per redemption or policy-based auto-approval?
- Points decay: Should balances decay over time to encourage steady engagement?
- Child display name: Permit optional nickname stored locally to avoid PII in CloudKit?

## 22. Glossary

- Shield: Block access to specified apps/categories.
- Exemption: Temporary allowance window where shielded apps are permitted.
- Child Context: Opaque identifier representing an authorized child managed via Screen Time APIs.

## 23. Epics & Stories (Full Development Phase)

Each epic lists user stories with concise acceptance criteria and phase labels. MVP indicates must-have for initial release; Post-MVP indicates Phase 2+.

EP-01 Screen Time Foundations (Entitlements & Authorization) — Phase: MVP
- S-101 Entitlement Request Package: Draft and submit Family Controls entitlement docs (purpose, flows, screenshots). Acceptance: Apple-ready packet produced and tracked. **Status: In Progress**
- S-102 Authorization Prompt & State: Request authorization behind parental gate; persist and reflect state. Acceptance: Denied/revoked handled with retry. **Status: Completed ✅**
- S-103 Child Selection UI: Present Apple system UI to select child; store opaque context. Acceptance: Multiple children added via repeated flow. **Status: Completed ✅**
- S-104 Revocation/Edge Cases: Handle authorization revocation, no-family group, and restricted devices. Acceptance: Clear messaging and safe fallback. **Status: In Progress (Child Device Detection & Basic Child Mode UI Integrated)**
- S-105 iPad Experience: Ensure authorization UI adapts to iPad multitasking/layouts. Acceptance: Works consistently across size classes. **Status: In Progress**

EP-02 Pairing & Family Association — Phase: MVP
- S-201 Pairing Code Generation: Parent generates short-lived code/deep link. Acceptance: Code TTL, one-time use, rate-limited.
- S-202 Child Link: Child app enters code or deep link to associate app instance to child context. Acceptance: <2 minutes; invalid/expired handled.
- S-203 Unlink/Re-pair: Parent can revoke and re-pair child device. Acceptance: Previous link invalidated; new link active.
- S-204 Multi-Child Management: Manage multiple children in UI. Acceptance: Clear selection; no cross-leakage.
- S-205 Parent Multi-Device: Parent can sign in on multiple devices. Acceptance: Sync parity; audit preserved.

EP-03 App Categorization & Rules — Phase: MVP
- S-301 Category Defaults: Choose default categories for learning/reward. Acceptance: Persisted.
- S-302 Manual Overrides: Set per-app overrides. Acceptance: Override > default.
- S-303 Conflict Resolution: Deterministic rule precedence and UI explanation. Acceptance: Tests cover edge cases.
- S-304 Rule Sync: Changes reflect across devices in <2s online. Acceptance: Verified.
- S-305 Rule Audits: Record who/when/what for changes. Acceptance: Audit entries stored.

EP-04 Points Engine & Integrity — Phase: MVP
- S-401 Foreground Accrual: Points accrue for foreground, unlocked learning usage. Acceptance: Matches DeviceActivity within ±5%. **Status: Completed ✅**
- S-402 Idle Timeout: Pause accrual after N minutes of inactivity. Acceptance: Configurable N; tests. **Status: Completed ✅**
- S-403 Daily Caps & Rate Limits: Enforce per-child caps and rate limits. Acceptance: Caps respected; clear messages. **Status: Completed ✅**
- S-404 Ledger persistence: PointsLedger with file storage, CloudKit-ready. **Status: Completed ✅**
- S-405 Clock Integrity: Use monotonic timers for sessions; detect clock changes. Acceptance: No negative/duplicate accruals. **Status: Completed ✅**
- S-406 Admin Adjustments: Parent can add/remove points with audit. Acceptance: Tracked and reversible. **Status: Completed ✅**
- **PointsLedger Observable:** `PointsLedger` now conforms to `ObservableObject` and its `entries` are `@Published` for UI reactivity. **Status: Completed ✅**

EP-05 Redemption & Shielding — Phase: MVP
- S-501 Redemption UX: Convert points to time with min/max and ratio. Acceptance: Validation and feedback.
- S-502 Start Timed Exemption: Begin exemption for reward apps/categories. Acceptance: Immediate effect.
- S-503 Extend/Stack Rules: Controlled extension of active exemption (policy-defined). Acceptance: No infinite stacking; upper bound.
- S-504 Re-lock Enforcement: Re-lock ≤5s at expiry; resume shield. Acceptance: Works after restart.
- S-505 Per-App vs Category: Support both; category wins unless app override set. Acceptance: Tested precedence.

EP-06 Sync & Multi-Parent — Phase: MVP
- S-601 CloudKit Schema: Implement record types and indexes (see docs/data-model.md). Acceptance: Migration script and tests.
- S-602 Conflict Resolution: Last-writer-wins with server timestamps. Acceptance: Deterministic outcomes.
- S-603 Offline Queue: Local queue and replay. Acceptance: Survives app restarts.
- S-604 Audit Log: Append-only audit for admin changes. Acceptance: Visible and filterable.
- S-605 Performance: Typical operations complete <200 ms locally; sync <2s online. Acceptance: Benchmarks recorded.

EP-07 Dashboard & Reporting — Phase: MVP
- S-701 Parent Dashboard: Points, learning time, redemptions, shields state. Acceptance: Refresh ≤1s.
- S-702 Weekly Report Extension: DeviceActivityReport summarizes week. Acceptance: Matches dashboard ±5%.
- S-703 Export Data: Parent can export summary CSV/JSON. Acceptance: Sanitized; no raw timelines.
- S-704 Tablet Dashboard Layout: Optimize dashboard for iPad split-view/multitasking. Acceptance: Layout adapts without clipping.

EP-08 Notifications — Phase: MVP
- S-801 Entitlement State: Notify on revoked/changed authorization. Acceptance: Actionable, rate-limited.
- S-802 Weekly Summary: Parent weekly digest. Acceptance: Opt-in, schedulable.
- S-803 Redemption Success: Child receives local notification when redemption begins. Acceptance: Immediate.
- S-804 Time Expiring: Alerts near expiry (e.g., 1 minute remaining). Acceptance: Not spammy; once per window.

EP-09 Privacy, Security, Compliance — Phase: MVP
- S-901 Parental Consent: Gate sensitive actions; inform data usage. Acceptance: Copy approved.
- S-902 Data Export/Delete: Family-level export and deletion. Acceptance: Completes within SLA; audit entry.
- S-903 Policy & Disclosures: Privacy policy and in-app disclosures. Acceptance: Links accessible; content approved.
- S-904 Kids/Parental-Control Compliance: Review checklist pass. Acceptance: Internal sign-off.
- S-905 Secrets & Storage: Keychain, encryption, least privilege. Acceptance: Security review passed.

EP-10 Accessibility & Localization — Phase: MVP
- S-1001 Dynamic Type & Layout: Scales across sizes. Acceptance: No clipping.
- S-1002 VoiceOver: Labels and hints. Acceptance: Navigable.
- S-1003 Contrast & Targets: Meets guidelines. Acceptance: Verified.
- S-1004 Localizable Strings: Strings externalized; English shipped. Acceptance: Build passes with base localization.

EP-11 Monetization & Paywall — Phase: Optional for MVP
- S-1101 Purchase: Subscription product purchase. Acceptance: Sandbox tested.
- S-1102 Restore: Restore purchases across devices. Acceptance: Reliable.
- S-1103 Family Plan: Family sharing for subscription if applicable. Acceptance: Verified.
- S-1104 Feature Gating: Premium flag gates advanced features. Acceptance: Non-premium path usable.

EP-12 Learning Depth & Engagement — Phase: Post-MVP
- S-1201 Subject Multipliers: Different point rates per subject. Acceptance: Configurable; analytics tracked.
- S-1202 Adaptive Difficulty: Adjust accrual or goals based on history. Acceptance: Safeguards and transparency.
- S-1203 Family Competitions: Opt-in leaderboards with privacy controls. Acceptance: Private by default.
- S-1204 Real-World Rewards: Partner integration scaffolding. Acceptance: Feature-flagged; parental approval.
- S-1205 Advanced Analytics: Trends and insights (parent-only). Acceptance: Aggregated; privacy-compliant.

EP-13 Parent & Child Mode Experience — Phase: MVP
- S-1301 Mode Selection & Security: Provide clear parent vs child mode entry with biometrics/parental gate. Acceptance: Switch requires auth; child cannot enter parent mode.
- S-1302 Child Mode Guardrails: Restrict navigation, hide settings, and present kid-friendly UI. Acceptance: No escape hatch without parent auth.
- S-1303 Fast Parent Toggle: Allow parent to re-enter parent mode quickly after authentication (e.g., shortcut). Acceptance: Flow <3 steps.

EP-14 Dev Experience & QA Infrastructure — Phase: MVP
- S-1401 Modular Project Setup: Targets and frameworks. Acceptance: Builds locally and CI. ✅ **DONE** - Swift Package + Xcode dual structure, debug build succeeds
- S-1402 CI/CD: Lint, build, unit tests on PR. Acceptance: Green pipeline.
- S-1403 Unit Tests: Core modules coverage targets (≥60% for engine). Acceptance: Threshold met. ✅ **DONE** - 54 tests passing, PointsEngine >60% coverage
- S-1404 UI Tests: Critical flows (onboarding, redemption). Acceptance: Stable.
- S-1405 Fixtures & Test Data: Deterministic seeds. Acceptance: Shared in repo. ✅ **DONE** - Test fixtures for PointsEngine and Ledger

## 24. Implementation Status (as of 2025-10-05)

**Completed Epics:**
- ✅ EP-04: Points Engine & Integrity - Full implementation with session-based accrual, idle timeout, daily caps, ledger persistence with MainActor isolation
- ✅ EP-05: Redemption & Shielding - RedemptionService, ShieldController, ExemptionManager with timer-based expiry and persistence
- ✅ EP-06: CloudKit Sync Infrastructure (Partial) - CloudKitMapper with 6 record types, SyncService with CRUD + change tracking, last-writer-wins conflict resolution
- ✅ EP-07: Dashboard & Reporting - DashboardViewModel, 5 card components, DataExporter (CSV/JSON), multi-child navigation with horizontal swipe

**Partially Completed:**
- 🔄 EP-03: App Categorization - CategoryRulesManager with per-child Learning/Reward classification, FamilyActivityPicker integration complete, conflict resolution pending
- 🔄 EP-06: Sync & Multi-Parent - Schema + mappers complete, offline queue and subscriptions pending

**Build Status:**
- ✅ Debug build succeeds on iOS Simulator (iPhone 17, iOS 26.0)
- ✅ 54 unit tests passing (0 failures)
- ✅ MainActor isolation fixes applied for thread-safe UI updates
- ✅ CloudKit sync code compiles without errors
- ⚠️ Warnings present (non-Sendable types, unused return values in preview code)
