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

- Platforms: Parent app on iOS/iPadOS 16+ and macOS 13+; Child app on iOS 16+ only.
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

- Parent Admin: Full control; can authorize children via system UI, set point rates, categorize apps, redeem, review history.
- Co-Parent: Same as Parent by default; optionally restricted on destructive actions; all actions audited.
- Child: No configuration; can view points and request redemption; child app is informational and request-based only.

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

- Apps: SwiftUI-first for iOS/iPadOS/macOS; UIKit/AppKit where necessary.
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

12.1 Parent Onboarding (iOS/macOS)
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

- Dependencies: Apple Family Controls entitlement; iOS/iPadOS/macOS versions; CloudKit availability.
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

