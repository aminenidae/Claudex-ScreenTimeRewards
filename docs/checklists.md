# Engineering & QA Checklists (MVP)

This file lists practical, testable checklists aligned with the PRD and feasibility spikes to help engineers and QA validate the MVP.

## 1) Spikes Completion (from docs/feasibility.md)
- [ ] P0-1: DeviceActivity foreground monitoring validated (±5% of manual checks)
- [ ] P0-2: ManagedSettings shields + timed exemptions validated (re-lock ≤5s)
- [ ] P0-3: FamilyControls authorization/entitlement flow proven (parent)
- [ ] P0-4: Pairing flow (parent↔child) validated in under 2 minutes
- [ ] P0-5: Anti-abuse baseline (idle timeout, caps, locked screen ignored)
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
- [ ] Accrual only during foreground, unlocked usage
- [ ] Idle timeout pauses accrual (configurable N minutes)
- [ ] Daily cap enforced; rate limit prevents burst exploits
- [ ] Ledger entries recorded for accruals/redemptions with timestamps

## 5) Redemption & Shielding
- [ ] Redemption ratio configurable; validation on min/max redemption
- [ ] Starting redemption triggers timed exemption for reward apps
- [ ] Countdown visible and accurate (±5s)
- [ ] On expiry, re-lock occurs ≤5s and shields persist after restart

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
- [ ] iOS Parent: iOS 16/17/18 (latest minor), iPhone + iPad
- [ ] macOS Parent: macOS 13/14/15 (latest minor), Intel/Apple Silicon as available
- [ ] iOS Child: iOS 16/17/18 (latest minor), at least two device classes
- [ ] Family without Family Sharing (edge case) and with multiple children
- [ ] Device restart, app reinstall, revocation of authorization

## 16) Epics Coverage (PRD §23)

- EP-01 Screen Time Foundations
  - [ ] S-101 Entitlement request package ready
  - [ ] S-102 Authorization gated and stateful
  - [ ] S-103 Child selection via system UI works (multi-child)
  - [ ] S-104 Revocation/edge cases handled
  - [ ] S-105 macOS authorization parity

- EP-02 Pairing & Family Association
  - [ ] S-201 Pairing code/deep link generation (TTL, rate limits)
  - [ ] S-202 Child link flow (<2 minutes; errors handled)
  - [ ] S-203 Unlink/re-pair flow
  - [ ] S-204 Multi-child management UI
  - [ ] S-205 Parent multi-device parity

- EP-03 App Categorization & Rules
  - [ ] S-301 Category defaults
  - [ ] S-302 Manual overrides with precedence
  - [ ] S-303 Conflict resolution rules tested
  - [ ] S-304 Rule sync (<2s online)
  - [ ] S-305 Rule audits present

- EP-04 Points Engine & Integrity
  - [ ] S-401 Foreground-only accrual (±5%)
  - [ ] S-402 Idle timeout enforced
  - [ ] S-403 Caps and rate limits
  - [ ] S-404 Ledger persistence
  - [ ] S-405 Monotonic timing/clock change handling
  - [ ] S-406 Admin adjustments audited

- EP-05 Redemption & Shielding
  - [ ] S-501 Redemption UX with validation
  - [ ] S-502 Timed exemption starts immediately
  - [ ] S-503 Extension policy enforced
  - [ ] S-504 Re-lock ≤5s; restart resiliency
  - [ ] S-505 Per-app vs category precedence tested

- EP-06 Sync & Multi-Parent
  - [ ] S-601 CloudKit schema implemented
  - [ ] S-602 Conflict strategy deterministic
  - [ ] S-603 Offline queue survives restarts
  - [ ] S-604 Audit log usable
  - [ ] S-605 Performance within targets

- EP-07 Dashboard & Reporting
  - [ ] S-701 Parent dashboard responsive
  - [ ] S-702 Weekly report extension parity (±5%)
  - [ ] S-703 Export (CSV/JSON) sanitized
  - [ ] S-704 macOS dashboard parity

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

- EP-13 macOS Enhancements
  - [ ] S-1301 Onboarding parity
  - [ ] S-1302 Menu bar status (post-MVP)
  - [ ] S-1303 macOS notifications

- EP-14 DevEx & QA Infra
  - [ ] S-1401 Modular project
  - [ ] S-1402 CI/CD pipeline
  - [ ] S-1403 Unit tests coverage
  - [ ] S-1404 UI tests critical flows
  - [ ] S-1405 Fixtures/test data

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
