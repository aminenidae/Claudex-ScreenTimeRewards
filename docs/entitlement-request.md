# Family Controls Entitlement Submission

- **Bundle ID:** `com.claudex.screentimerewards`
- **Apple App ID:** `6753270211`
- **App ID Prefix / Team ID:** `KQ5KZR3DQ5`
- **Entitlement:** Family Controls (`com.apple.developer.family-controls`)
- **Distribution Status:** Submitted – pending Apple approval (as of 2025-10-04)
- **Development Status:** Active in Xcode for local builds

## Product Summary

| Item | Details |
| --- | --- |
| Purpose | Reward-based family screen time manager that reframes restrictions into earned privileges. |
| Primary Users | Parents managing child devices (iOS/iPadOS). |
| Child Presence | Yes – child-facing mode with limited, reward-centric UI. |
| Screen Time APIs | `FamilyControls`, `ManagedSettings`, `DeviceActivity`, `DeviceActivityReportExtension`. |
| Release Target | App Store (Family category / Parenting). |

## Use Cases Sent to Apple

1. **Parent Authorization & Setup** – Parent authenticates (Face ID / passcode) and grants the app access to manage their family group using Apple’s system UI.
2. **Learning vs Reward Categorisation** – Parent labels apps; learning time accumulates points automatically, reward apps remain shielded.
3. **Child Earns & Redeems** – Child mode presents point balance and allows redemption requests; redeemed points temporarily lift shields on reward apps.
4. **Family Reporting** – Parent mode provides weekly summaries (DeviceActivityReport) without exposing raw browsing history.

## Data Handling & Privacy Position

- **Data minimisation** – Store only aggregate usage metrics (points earned, time spent per category). No raw per-app timelines or sensitive content stored.
- **Cloud storage** – CloudKit shared database scoped to the family. All records encrypted at rest; no third-party analytics/ads in child context.
- **Parental controls compliance** – Parent gate required for configuration; child mode cannot modify controls. All sensitive views require Face ID / Touch ID / device passcode.
- **COPPA/GDPR-K** – Parental consent collected during onboarding. Parents can export or delete family data inside the app.

## Latest Testing Notes (2025-10-04)

- Development build installed on iPhone 15 (iOS 18.6.2). Authorization prompt succeeded; revocation in Settings correctly transitions banner to "Authorization required".
- FamilyActivityPicker launches post-authorization; learning/reward selections persist via `CategoryRulesManager`.
- Screenshots/video captured for entitlement package (see `docs/assets/entitlement/authorization/notes.md` for storage details).

## Attachments & Artefacts

| Artefact | Location | Status |
| --- | --- | --- |
| Authorization flow screenshots | `docs/assets/entitlement/authorization/` | Captured 2025-10-04 (pending export to repo) |
| Child selection flow video | Shared drive (`authorization-flow.mov`) | Captured 2025-10-04 |
| Privacy copy & FAQ | `docs/ux-copy.md` | TODO |
| App Review notes | `docs/review-notes.md` | TODO |

## Submission Package Checklist

- [x] Bundle configuration created in Apple Developer portal
- [x] Entitlement request submitted for distribution
- [ ] Apple response received and logged
- [ ] Entitlement enabled in production provisioning profiles once approved
- [ ] Artefacts captured and linked (screenshots, video, copy)

## Follow-up Tasks

1. Monitor Apple Developer notifications / email for approval updates.
2. Once approved, enable the entitlement in App ID capabilities and update provisioning profiles.
3. Capture screenshots or video of FamilyControls flows for potential App Review questions.
4. Update this document with approval date and any special conditions Apple provides.

## References

- PRD §23 – EP-01 Screen Time Foundations (stories S-101 … S-105)
- docs/feasibility.md – spike objectives for FamilyControls, ManagedSettings, DeviceActivity
- docs/checklists.md – Definition of Ready / Done for EP-01 stories
