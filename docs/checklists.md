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
