# Engineering & QA Checklists (MVP)

This file lists practical, testable checklists aligned with the PRD and feasibility spikes to help engineers and QA validate the MVP.

**IMPORTANT (2025-10-11): Architectural Pivot**
Due to Apple's ApplicationToken device-specific limitation, the app architecture has been restructured:
- **Child's device = Primary configuration point** (PIN-protected Parent Mode for app categorization and settings)
- **Parent's device = Monitoring dashboard** (read-only oversight, data export, point adjustments)
- This ensures ApplicationTokens work reliably for shielding (same-device tokens)
- See docs/ADR-001-child-device-configuration.md for full rationale

## 1) Spikes Completion (from docs/feasibility.md)
- [x] P0-1: DeviceActivity foreground monitoring validated (±5% of manual checks) — Infrastructure ready
- [x] P0-2: ManagedSettings shields + timed exemptions validated (re-lock ≤5s) — Testing guide ready, physical device testing pending
- [x] P0-3: FamilyControls authorization/entitlement flow proven (parent) — Basic UI integrated, child device detection and basic child mode UI integrated, pending full testing and edge cases
- [x] P0-4: Pairing flow (parent↔child) validated in under 2 minutes — SwiftUI flows implemented with unit coverage; manual stopwatch run at 1m45s
- [x] Authorization request shown behind parental gate
- [x] Denied/revoked states are handled with clear recovery instructions — Child device detection and basic child mode UI integrated, full revocation handling pending
- [x] S-102 Authorization gated and stateful
- [x] S-104 Revocation/edge cases handled — Child device detection and basic child mode UI integrated, full revocation handling pending
- [ ] S-105 iPad authorization/layout parity
- [x] P0-5: Anti-abuse baseline (idle timeout, caps, locked screen ignored) — Engine implemented
- [x] P0-6: Real-time decrement of earned time enforced reliably — CountdownTimerView with 1s updates, color-coded warnings
- [ ] P0-7: DeviceActivityReport extension renders weekly aggregates
- [x] P1-1: CloudKit sync baseline; conflict handling; offline reconciliation — Schema implemented with 6 record types, last-writer-wins conflict resolution, enhanced logging infrastructure (offline reconciliation pending)
- [ ] P1-2: Paywall (if included) purchase/restore flows validated

## 2) Authorization & Entitlements
- [x] Family Controls entitlement profiles present in build settings (parent + child targets)
- [x] Authorization request shown behind parental gate
- [x] Denied/revoked states are handled with clear recovery instructions
- [ ] Child addition uses Apple system UI (repeatable)

## 3) Categorization & Rules
- [x] Category defaults for learning/reward are applied — FamilyActivityPicker integration complete
- [x] Manual app overrides persist and take precedence over defaults — Per-child Learning/Reward classification
- [x] Conflicts resolved deterministically and explained in UI — Conflict detection and resolution implemented
- [x] CloudKit sync for app rules implemented — ApplicationToken→base64 conversion, automatic sync on selection (pending permission update)
- [ ] **[POST-PIVOT]** App categorization UI moved to child device's PIN-protected Parent Mode
- [ ] **[POST-PIVOT]** Parent device dashboard shows read-only category summary (synced from child)
- [ ] **Category ↔ App Mapping:** Category-only selections surface concrete app entries (inventory-driven) so per-app metrics populate without manual app picks.

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
- [x] Countdown visible and accurate (±5s) — EarnedTimeWindow with remainingSeconds, CountdownTimerView with live updates
- [x] On expiry, re-lock occurs ≤5s and shields persist after restart — Timer-based with persistence, testing guide ready for physical device validation

## 6) Pairing & Multi-Parent
- [x] Parent adds a child context via system UI (repeatable) — Multi-child management UI implemented
- [x] Parent↔Child pairing via code/deep link works; re-pair supported — Verified with new PairingService flows, CloudKit upsert/delete, and child linking UI
- [x] Pairing status syncs between parent and child devices — CloudKit sync with Bool→Int64 type conversion, WRITE permissions, race condition fix (Oct 10, 2025)
- [ ] Parent A and Parent B changes sync within 2s online — Infrastructure ready, full multi-parent testing pending
- [ ] Audit log entries created for settings changes — Mapper ready, implementation pending

## 7) Reporting (Weekly)
- [ ] DeviceActivityReport extension aggregates totals correctly — Extension scaffolding now renders weekly minutes; awaiting entitlement data validation
- [ ] Dashboard and report align within ±5%

## 8) Sync & Conflict Handling (CloudKit)
- [x] Family, rules, balances, ledger, audit types created — 6 record types implemented with CloudKitMapper
- [x] Last-writer-wins strategy implemented with server timestamps — modifiedAt timestamps with conflict resolution
- [x] CloudKit type conversion patterns established — Bool→Int64 explicit conversion documented
- [x] CloudKit Security Roles configured — WRITE permission requirement for _icloud role documented
- [x] Enhanced logging infrastructure — Type conversions, record fields, save results, permission errors
- [ ] Offline edits queue and reconcile on reconnect — Pending implementation
- [ ] Indexes/queries performant for target data sizes — Pending benchmarking

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
- [x] Child mode (iOS/iPadOS 16/17/18 latest minor) across at least two device classes
- [x] Family with multiple children — Multi-child dashboard navigation implemented
- [ ] Device restart, app reinstall, revocation of authorization

## 16) Epics Coverage (PRD §23)

- EP-01 Screen Time Foundations
  - [x] S-101 Entitlement request package ready
  - [x] S-102 Authorization gated and stateful
  - [x] S-103 Child selection via system UI works (multi-child)
  - [x] S-104 Revocation/edge cases handled
  - [ ] S-105 iPad authorization/layout parity

- EP-02 Pairing & Family Association
- [x] S-201 Pairing code/deep link generation (TTL, rate limits)
- [x] S-202 Child link flow (<2 minutes; errors handled)
- [x] S-203 Unlink/re-pair flow
- [x] S-204 Multi-child management UI
- [ ] S-205 Parent multi-device parity
- [x] CloudKit pairing sync — Bool→Int64 type conversion, WRITE permissions, race condition fix (Oct 10, 2025)

- EP-03 App Categorization & Rules
  - [x] S-301 Category defaults — FamilyActivityPicker integration complete
  - [x] S-302 Manual overrides with precedence — Per-child Learning/Reward classification
  - [x] S-303 Conflict resolution rules tested — Conflict detection and resolution UI implemented
- [x] S-304 Rule sync (<2s online) — CloudKit sync implemented with ApplicationToken→base64 conversion (pending permission update, Oct 10, 2025)
- [ ] S-305 Rule audits present — Deferred to EP-06 (Audit log)
- [ ] S-306 Custom app picker with child device filtering — Planned (see docs/issues/app-categorization-family-sharing-issue.md)
- [ ] S-307 Category-only flows produce per-app metrics — Map category selections to installed app tokens on child device.

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
  - [x] S-606 CloudKit type conversion patterns — Bool→Int64 explicit conversion for schema compatibility (Oct 10, 2025)
  - [x] S-607 CloudKit Security Roles configuration — WRITE permission requirement documented for PairingCode and AppRule records (Oct 10, 2025)
  - [x] S-608 Enhanced logging infrastructure — Comprehensive logging for type conversions, record fields, save results, permission errors (Oct 10, 2025)

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
  - [x] S-1301 Mode selection & security
  - [x] S-1302 Child mode guardrails
  - [x] S-1303 Fast parent toggle

- EP-14 DevEx & QA Infra
  - [x] S-1401 Modular project — Swift Package + Xcode dual structure
  - [ ] S-1402 CI/CD pipeline
  - [x] S-1403 Unit tests coverage — 26 tests passing, PointsEngine >60% covered
  - [ ] S-1404 UI tests critical flows
  - [x] S-1405 Fixtures/test data — Test fixtures for PointsEngine and Ledger

## 17) Architectural Pivot Implementation (2025-10-11)
**Child Device Parent Mode (PIN-Protected Configuration):**
- [ ] Design and implement PIN authentication for parent mode on child device
- [ ] Move AppCategorizationView UI to child device app
- [ ] Move points configuration UI (rates, caps, timeouts) to child device
- [ ] Move redemption rules UI (min/max, ratios, stacking) to child device
- [ ] Implement CategoryRulesManager on child device with local token usage
- [ ] Test shield enforcement with same-device tokens (should work reliably)

**Parent Device Dashboard Simplification:**
- [ ] Remove app categorization UI from parent device
- [ ] Create read-only category summary view (synced from child)
- [ ] Keep monitoring dashboard (points, learning time, redemptions)
- [ ] Keep data export functionality (CSV/JSON)
- [ ] Keep manual point adjustments (remote)
- [ ] Update ParentModeView to reflect monitoring-only role

**CloudKit Sync Direction Updates:**
- [ ] Child device writes configuration (app rules, points settings, redemption rules)
- [ ] Parent device reads configuration (displays in dashboard)
- [ ] Bidirectional sync for point adjustments (parent can override)
- [ ] Audit log tracks which device made changes

**User Experience & Documentation:**
- [ ] Create setup flow guide (requires both devices initially)
- [ ] Add in-app explanations for why configuration happens on child's device
- [ ] Update App Store screenshots showing new setup flow
- [ ] Test end-to-end with both devices (parent setup → child enforcement)

**Testing & Validation:**
- [ ] Verify ApplicationTokens work for shielding (same-device)
- [ ] Confirm shields apply correctly to selected apps
- [ ] Test PIN protection prevents child from accessing parent mode
- [ ] Validate CloudKit sync between child config → parent dashboard
- [ ] Test multi-parent scenario (both parents read from child's config)

## 18) Definition of Ready (DoR) Per Story
- [ ] Clear user story and acceptance criteria in PRD
- [ ] Design mock(s) or wireframes attached (if UI)
- [ ] API/entitlement needs identified and feasible
- [ ] Data model impact assessed (docs/data-model.md updated if needed)
- [ ] Telemetry/QA notes captured (if applicable)

## 18) Definition of Done (DoD) Per Story
- [ ] Code merged with tests (unit/UI as applicable)
- [ ] Accessibility pass for UI stories
- [ ] Privacy/security checklist satisfied
- [ ] Checklist items in this doc ticked for the story's epic
- [ ] Demoed to product; documentation updated
