# Feasibility & Spike Plan

This document outlines the technical feasibility checks, spikes, and acceptance criteria needed to validate the MVP for the reward-based screen time management app on iOS.

## Objectives

- Verify that Apple’s Screen Time APIs support the MVP loop: monitor “learning” app usage, award points, convert points into temporary access for “reward” apps, and present reports to parents.
- Validate multi-device support (parent and child), real-time sync, and basic anti-abuse guardrails under Apple’s platform constraints.
- De-risk App Store entitlement and review requirements early.

## Assumptions & Constraints

- Platform scope: Universal iOS/iPadOS 16+ app (parent and child modes). Optimize for iOS/iPadOS 17+.
- Official APIs only: FamilyControls, ManagedSettings, DeviceActivity, DeviceActivityReport extension.
- Family Controls entitlement is required and must be requested from Apple with justification.
- No use of MDM or private APIs.

## Apple Screen Time APIs Overview

- FamilyControls: Authorization and selection of applications/categories to supervise; pairing/authorization flow. Available on iOS/iPadOS 16+.
- ManagedSettings: Apply shields to apps/categories and grant temporary exemptions (earned time windows). Available on iOS/iPadOS 16+.
- DeviceActivity: Define schedules and events to observe usage of selected apps/categories; provides metrics for reporting. Available on iOS/iPadOS 16+.
- DeviceActivityReport Extension: Supplies summarized usage data and UI for parental reports. Available on iOS/iPadOS 16+.

Key review considerations:
- Kids Category and parental controls guidelines compliance.
- Clear parental gating and consent flows.
- Data minimization and no third-party tracking/ads in child contexts.

## Highest-Risk Areas

1. Entitlement approval timing and scope (Family Controls entitlement).
2. Granularity and reliability of DeviceActivity signals for point accrual.
3. Real-time application of ManagedSettings exemptions while a reward app is in use.
4. Multi-device sync (parent <-> child) and conflict handling under connectivity changes.
5. Anti-abuse: detecting idle/parked screen in “learning” apps within platform limits.

## Spikes & Experiments (P0/P1)

P0 = must prove before building MVP core; P1 = important but can follow immediately after.

### P0-1: Monitor Foreground Usage (DeviceActivity)
- Goal: Confirm we can observe foreground usage for selected apps/categories and receive events suitable for point accrual.
- Method: Create a spike app using DeviceActivity to register a schedule, select 2–3 test apps, and log observed events/totals.
- Validate: Events fire for foreground usage; background/locked screen time is not counted; daily totals align within ±5% of manual checks.

### P0-2: Shielding and Exemptions (ManagedSettings)
- Goal: Enforce blocks on “reward” apps and grant temporary exemptions to reflect earned time.
- Method: Apply category/app shields, start a timed exemption, observe access during exemption, then auto-expire and re-shield.
- Validate: App launches only during active exemption window; re-lock occurs within 5 seconds of expiry; works across device restarts.

### P0-3: Authorization & Entitlement Flow (FamilyControls)
- Goal: Exercise the authorization flow and app selection UI; document entitlement request requirements.
- Method: Implement authorization prompts in the spike (parent mode on iPhone/iPad); attempt to compile/run with the entitlement in a development team context; if blocked, prepare entitlement request materials.
- Validate: Authorization UI appears; selected apps/categories are persisted and readable by the app; document any gating that requires Apple approval.
- Spike log (S-102):
  - Device(s) used: iPhone 15 (iOS 18.6.2 build 22G100)
  - Result: Authorization prompt displayed, approval succeeded; banner reflects state transitions; denial path verified by revoking in Settings.
  - Notes: Screenshots captured (see `docs/assets/entitlement/authorization/notes.md`); FamilyActivityPicker opens successfully post-authorization.

### P0-4: Child/Parent Pairing & Roles
- Goal: Prove a basic pairing flow and role separation (Parent vs Child).
- Method: Implement a simple pairing code or Family Sharing lookup; restrict configuration to Parent mode; Child mode can only view points and request redemptions.
- Validate: Two-device flow completes under 2 minutes; role-based access enforced.

### P0-5: Anti-Abuse Guardrails
- Goal: Establish minimum viable protections against idle farming.
- Method: Accrue points only when device is unlocked and app is foreground; apply idle timeout (no events for N minutes => pause accrual). Consider small in-app micro-interactions for first-party “learning” content; acknowledge limitation for third-party apps.
- Validate: Leaving a learning app open without interaction pauses accrual within N minutes; daily caps/rate limits applied.

### P0-6: Real-Time Decrement of Earned Time
- Goal: Ensure earned time decrements while a reward app is in use and re-locks when depleted.
- Method: Start an exemption for X minutes from the parent device (iOS), open reward app on the child device (iOS), verify live countdown and enforced re-lock.
- Validate: Countdown accuracy within ±5 seconds; re-lock enforces promptly when time reaches zero.

### P0-7: Reporting (DeviceActivityReport Extension)
- Goal: Provide daily/weekly summaries for parents.
- Method: Implement a minimal report extension that aggregates observed activity into per-category totals; render simple charts/tables.
- Validate: Totals match DeviceActivity logs and parent dashboard within ±5%.

### P1-1: Cloud Sync Path (CloudKit vs Firebase)
- Goal: Choose sync/storage for MVP with minimal review friction.
- Method: Prototype CloudKit shared database for family records; test conflict resolution and offline behavior.
- Validate: Sync latency < 2s on good network; last-writer-wins with audit entries; offline edits reconcile within 10s after reconnect.

### P1-2: Monetization & Paywall Flow
- Goal: Validate a simple subscription/paywall appropriate for parental control use case.
- Method: Implement a basic paywall with introductory offer and family plan; limit premium features accordingly.
- Validate: Purchase/restore flows function; non-premium path remains fully review-compliant.

## Test Harness & Measurement

- Two physical devices recommended: one Parent-mode device (iOS/iPadOS) and one Child-mode device (iOS/iPadOS) on current OS versions.
- Logging: Structured logs with timestamps for events (activity observed, shield applied/expired, exemption start/stop).
- Manual validation sheets for each spike with expected vs. observed timings.

## Data & Privacy Checklist

- Data minimization: store aggregates, not raw per-event timelines where possible.
- No third-party analytics/ads in child-facing surfaces.
- Parental consent, data export/delete pathways, and transparent disclosures.
- Security: Keychain for tokens; encrypt sensitive records at rest; least-privilege access patterns.

## Review/Entitlement Preparation

- Draft entitlement request: describe parental-control purpose, user benefits, and compliance posture.
- Document flows/screenshots for authorization, shields, and parental gating.
- Note Kids Category rules and any content rating implications.

## Go/No-Go Criteria (MVP)

- DeviceActivity reliably reports foreground usage for selected apps/categories.
- ManagedSettings shields and exemptions work predictably and recover after restarts.
- Pairing and roles are functional with clear parental gating.
- Anti-abuse guardrails prevent trivial farming within defined thresholds.
- Cloud sync path selected and proven with basic conflict handling.
- Entitlement request package ready; review risks documented.

## Timeline (Indicative)

- Week 1: P0-1, P0-2 spikes; begin entitlement docs.
- Week 2: P0-3, P0-4; draft pairing UX; start P0-6.
- Week 3: P0-5, P0-6 validation; add reporting extension (P0-7).
- Week 4: P1-1 sync spike; P1-2 monetization plan; finalize Go/No-Go.

## Deliverables

- Spike app code with togglable modules for monitoring, shielding, exemptions, and reporting.
- Logs and validation sheets for each spike with measured results.
- Entitlement request draft and review checklist.
