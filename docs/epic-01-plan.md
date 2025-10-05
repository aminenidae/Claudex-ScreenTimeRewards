# EP-01 — Screen Time Foundations (Entitlements & Authorization)

This plan breaks down execution for Stories S-101 through S-105.

## Story Tracker

| Story | Title | Owner | Status | Notes |
| --- | --- | --- | --- | --- |
| S-101 | Entitlement Request Package | | Completed | Submission doc updated with testing notes; artefact capture scheduled for export. |
| S-102 | Authorization Prompt & State | | Completed | Authorization helper integrated; on-device validation recorded in feasibility log. |
| S-103 | Child Selection via System UI | | Not started | Validate multi-child selection and persistence of opaque IDs. |
| S-104 | Revocation & Edge Cases | | Not started | Enumerate failure cases and UX copy. |
| S-105 | iPad Authorization Experience | | Not started | Ensure smooth experience across iPhone/iPad size classes. |

## Prerequisites

- Development entitlement active (confirmed).
- Distribution entitlement request submitted (pending) — tracked in `docs/entitlement-request.md`.
- Test devices: at least one iPhone and one iPad on iOS/iPadOS 16+.
- Xcode project builds on device (ClaudexScreenTimeRewards.xcodeproj – `ClaudexScreenTimeRewardsApp`).

## Deliverables per Story

### S-101 – Entitlement Request Package
- Update `docs/entitlement-request.md` with rationale, flows, privacy summary, and current status.
- Collect screenshots/video of:
  - Parent auth flow
  - Child selection
  - Settings screens showing entitlement usage
- Document any special review notes Apple should be aware of.

### S-102 – Authorization Prompt & State
- Spike app code (can live under `Spikes/Authorization/` or feature branch) demonstrating:
  - Requesting FamilyControls authorization behind a parental gate (biometric/passcode requirement TBD).
  - Persisting authorization status in app state.
  - Handling denied/restricted/cancelled states with messaging.
- Update `docs/feasibility.md` P0-3 section with findings.
- Capture reusable helper for production code (e.g., `AuthorizationCoordinator`).

### S-103 – Child Selection via System UI
- Extend spike to present `FamilyActivityPicker` multiple times.
- Log structure of opaque identifiers; ensure we don’t store PII.
- Define storage format for `ChildContext` (ties into CloudKit schema).
- Update `docs/data-model.md` if adjustments needed.

### S-104 – Revocation & Edge Cases
- Enumerate how revocation happens (Settings, timeouts, child removal).
- Ensure app detects revocation on launch/foreground and prompts parent gracefully.
- Draft UX copy for each error state; add to `docs/ux-copy.md` (create if needed).

### S-105 – iPad Authorization Experience
- Verify flows on iPad (portrait/landscape, multitasking).
- Note layout requirements for production UI (safe areas, popovers).
- Capture screenshots for design review.

## Execution Notes

- Work in feature branches per story; merge back once DoR/DoD satisfied (`docs/checklists.md`).
- Share spike findings via short Loom/QuickTime clips when helpful.
- Flag any API limitations immediately; adjust PRD if necessary.
