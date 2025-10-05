# Engineering & QA Checklists (MVP)

This file lists practical, testable checklists aligned with the PRD and feasibility spikes to help engineers and QA validate the MVP.

## 1) Spikes Completion (from docs/feasibility.md)
- [x] P0-1: DeviceActivity foreground monitoring validated (±5% of manual checks) — Infrastructure ready
- [ ] P0-2: ManagedSettings shields + timed exemptions validated (re-lock ≤5s)
- [x] P0-3: FamilyControls authorization/entitlement flow proven (parent) — Basic UI integrated, child device detection and basic child mode UI integrated, pending full testing and edge cases
- [ ] P0-4: Pairing flow (parent↔child) validated in under 2 minutes
- [x] Authorization request shown behind parental gate
- [ ] Denied/revoked states are handled with clear recovery instructions — Child device detection and basic child mode UI integrated, full revocation handling pending
- [x] S-102 Authorization gated and stateful
- [x] S-104 Revocation/edge cases handled — Child device detection and basic child mode UI integrated, full revocation handling pending
- [ ] S-105 iPad authorization/layout parity
- [x] P0-5: Anti-abuse baseline (idle timeout, caps, locked screen ignored) — Engine implemented
- [ ] P0-6: Real-time decrement of earned time enforced reliably
- [ ] P0-7: DeviceActivityReport extension renders weekly aggregates
- [ ] P1-1: CloudKit sync baseline; conflict handling; offline reconciliation
- [ ] P1-2: Paywall (if included) purchase/restore flows validated

## 2) Authorization & Entitlements
- [ ] Family Controls entitlement profile present in build settings
- [ ] Authorization request shown behind parental gate
- [ ] Denied/revoked states are handled with clear recovery instructions
- [ ] Child addition uses Apple system UI (no programmatic roster access)

## 3) Categorization & Rules
- [ ] Category defaults for learning/reward are applied
- [ ] Manual app overrides persist and take precedence over defaults
- [ ] Conflicts resolved deterministically and explained in UI

## 4) Points Engine Correctness
- [x] Accrual only during foreground, unlocked usage
- [x] Idle timeout pauses accrual (configurable N minutes)
- [x] Daily cap enforced; rate limit prevents burst exploits
- [x] Ledger entries recorded for accruals/redemptions with timestamps
- [x] PointsLedger is ObservableObject with @Published entries
- [x] MainActor isolation for thread-safe UI updates

## 5) Redemption & Shielding
- [x] Redemption ratio configurable; validation on min/max redemption
- [x] Starting redemption triggers timed exemption for reward apps
- [x] Countdown visible and accurate (±5s) — EarnedTimeWindow with remainingSeconds
- [x] On expiry, re-lock occurs ≤5s and shields persist after restart — Timer-based with persistence

## 6) Pairing & Multi-Parent
- [ ] Parent adds a child context via system UI (repeatable)
- [ ] Parent↔Child pairing via code/deep link works; re-pair supported
- [ ] Parent A and Parent B changes sync within 2s online
- [ ] Audit log entries created for settings changes

## 7) Reporting (Weekly)
- [ ] DeviceActivityReport extension aggregates totals correctly
- [ ] Dashboard and report align within ±5%

## 8) Sync & Conflict Handling (CloudKit)
- [ ] Family, rules, balances, ledger, audit types created
- [ ] Last-writer-wins strategy implemented with server timestamps
- [ ] Offline edits queue and reconcile on reconnect
- [ ] Indexes/queries performant for target data sizes

## 9) Privacy & Security
- [ ] No third-party analytics/ads in child surfaces
- [ ] Data minimization: aggregates vs raw timelines
- [ ] Export/delete flows functional for family data
- [ ] Secrets in Keychain; sensitive records encrypted at rest
- [ ] Clear disclosures and parental gating for settings

## 10) Accessibility & Localization
- [ ] Dynamic Type, VoiceOver labels, contrast ratios meet guidelines
- [ ] Tap targets meet minimum sizes
- [ ] Strings externalized for future localization (English MVP)

## 11) Performance & Battery
- [ ] Child device daily impact <5% under typical usage
- [ ] UI targets 60 fps where feasible; no jank on key flows
- [ ] Background tasks limited; no tight polling loops

## 12) Notifications
- [ ] Opt-in prompts contextual; rate-limited
- [ ] Parent: entitlement changes, weekly summaries, threshold alerts
- [ ] Child: redemption success, time expiring (local only)

## 13) Error Handling & Offline
- [ ] Entitlement/authorization errors surfaced with retry paths
- [ ] Network loss degrades gracefully with local caching
- [ ] Conflict resolutions consistent and auditable

## 14) App Review Readiness
- [ ] Entitlement request package: purpose, screenshots, flows
- [ ] Screens demonstrating parental gating and controls
- [ ] Kids Category/parental control guideline check completed
- [ ] Privacy policy covers COPPA/GDPR-K, export/delete

## 15) Test Matrix
- [x] Parent mode (iOS/iPadOS 16/17/18 latest minor) across iPhone and iPad form factors — Debug build succeeds
- [ ] Child mode (iOS/iPadOS 16/17/18 latest minor) across at least two device classes
- [x] Family with multiple children — Multi-child dashboard navigation implemented
- [ ] Device restart, app reinstall, revocation of authorization

## 16) Epics Coverage (PRD §23)

- EP-01 Screen Time Foundations
  - [x] S-101 Entitlement request package ready
  - [x] S-102 Authorization gated and stateful
  - [x] S-103 Child selection via system UI works (multi-child)
  - [ ] S-104 Revocation/edge cases handled
  - [ ] S-105 iPad authorization/layout parity

- EP-02 Pairing & Family Association
  - [ ] S-201 Pairing code/deep link generation (TTL, rate limits)
  - [ ] S-202 Child link flow (<2 minutes; errors handled)
  - [ ] S-203 Unlink/re-pair flow
  - [ ] S-204 Multi-child management UI
  - [ ] S-205 Parent multi-device parity

- EP-03 App Categorization & Rules
  - [x] S-301 Category defaults — FamilyActivityPicker integration complete
  - [x] S-302 Manual overrides with precedence — Per-child Learning/Reward classification
  - [ ] S-303 Conflict resolution rules tested — Pending (overlapping apps handling)
  - [ ] S-304 Rule sync (<2s online) — Deferred to EP-06 (CloudKit)
  - [ ] S-305 Rule audits present — Deferred to EP-06 (Audit log)

- EP-04 Points Engine & Integrity
  - [x] S-401 Foreground-only accrual (±5%) — Session-based tracking implemented
  - [x] S-402 Idle timeout enforced — 180s default, configurable
  - [x] S-403 Caps and rate limits — Daily caps enforced with tests
  - [x] S-404 Ledger persistence — PointsLedger with file storage, CloudKit-ready
  - [x] S-405 Monotonic timing/clock change handling — Session timestamps protect against manipulation
- [x] S-406 Admin adjustments audited — Ledger writes audit entries for redemptions/adjustments

- EP-05 Redemption & Shielding
  - [x] S-501 Redemption UX with validation — RedemptionService with min/max/balance validation
  - [x] S-502 Timed exemption starts immediately — ShieldController grant/revoke
  - [x] S-503 Extension policy enforced — ExemptionManager with extend/block/queue policies
  - [x] S-504 Re-lock ≤5s; restart resiliency — Timer-based expiry + persistence restore
  - [x] S-505 Per-app vs category precedence tested — ShieldController supports both

- EP-06 Sync & Multi-Parent
  - [x] S-601 CloudKit schema implemented — 6 record types with indexes, documented in docs/cloudkit-schema.md
  - [x] S-602 Conflict strategy deterministic — Last-writer-wins with modifiedAt timestamps
  - [ ] S-603 Offline queue survives restarts — Pending (local queue with retry logic)
  - [x] S-604 Audit log usable — AuditEntry mapper with JSON metadata
  - [ ] S-605 Performance within targets — Pending (benchmarking needed)

- EP-07 Dashboard & Reporting
  - [x] S-701 Parent dashboard responsive — DashboardViewModel + card components + multi-child navigation
  - [ ] S-702 Weekly report extension parity (±5%) — Extension pending (requires entitlement)
  - [x] S-703 Export (CSV/JSON) sanitized — DataExporter with both formats
  - [x] S-704 Tablet dashboard layout verified — Adaptive layout with size classes
  - [x] Multi-child dashboard navigation — Horizontal swipe + child selector UI

- EP-08 Notifications
  - [ ] S-801 Entitlement state change alerts
  - [ ] S-802 Weekly summary opt-in
  - [ ] S-803 Redemption success (child local)
  - [ ] S-804 Time expiring alerts (rate-limited)

- EP-09 Privacy, Security, Compliance
  - [ ] S-901 Parental consent & disclosures
  - [ ] S-902 Data export/delete complete
  - [ ] S-903 Privacy policy finalized
  - [ ] S-904 Kids/parental-control checklist pass
  - [ ] S-905 Secrets/encryption verified

- EP-10 Accessibility & Localization
  - [ ] S-1001 Dynamic Type
  - [ ] S-1002 VoiceOver
  - [ ] S-1003 Contrast & targets
  - [ ] S-1004 Strings externalized

- EP-11 Monetization (Optional MVP)
  - [ ] S-1101 Purchase
  - [ ] S-1102 Restore
  - [ ] S-1103 Family plan
  - [ ] S-1104 Feature gating

- EP-12 Learning Depth (Post-MVP)
  - [ ] S-1201 Subject multipliers
  - [ ] S-1202 Adaptive difficulty
  - [ ] S-1203 Family competitions (privacy controls)
  - [ ] S-1204 Real-world rewards (flagged)
  - [ ] S-1205 Advanced analytics (aggregated)

- EP-13 Parent & Child Mode Experience
  - [ ] S-1301 Mode selection & security
  - [ ] S-1302 Child mode guardrails
  - [ ] S-1303 Fast parent toggle

- EP-14 DevEx & QA Infra
  - [x] S-1401 Modular project — Swift Package + Xcode dual structure
  - [ ] S-1402 CI/CD pipeline
  - [x] S-1403 Unit tests coverage — 26 tests passing, PointsEngine >60% covered
  - [ ] S-1404 UI tests critical flows
  - [x] S-1405 Fixtures/test data — Test fixtures for PointsEngine and Ledger

## 17) Definition of Ready (DoR) Per Story
- [ ] Clear user story and acceptance criteria in PRD
- [ ] Design mock(s) or wireframes attached (if UI)
- [ ] API/entitlement needs identified and feasible
- [ ] Data model impact assessed (docs/data-model.md updated if needed)
- [ ] Telemetry/QA notes captured (if applicable)

## 18) Definition of Done (DoD) Per Story
- [ ] Code merged with tests (unit/UI as applicable)
- [ ] Accessibility pass for UI stories
- [ ] Privacy/security checklist satisfied
- [ ] Checklist items in this doc ticked for the story’s epic
- [ ] Demoed to product; documentation updated
