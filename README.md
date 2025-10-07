# Claudex Screen Time Rewards

Reward-based screen time management for families using Apple Screen Time APIs.

## Quick Start

- Read the product plan: `PRD.md`
- Validate feasibility and spikes: `docs/feasibility.md`
- Review QA checklists: `docs/checklists.md`
- See CloudKit schema draft: `docs/data-model.md`
- Planning board guide: `docs/planning.md`
- Story inventory (CSV): `docs/stories.csv`
- Track implementation progress: `docs/progress-log.md`

## Platforms

- Universal iOS/iPadOS 16+ app with parent and child modes
- Child mode displays live points data and allows reward time requests
- Parent mode provides configuration and management interface

## Planning Helpers

- Labels sync (GitHub Action): `.github/labels.yml`
- Issue templates: `.github/ISSUE_TEMPLATE/`
- Seed epics: `bash scripts/seed_epics.sh`
- Seed stories: `bash scripts/seed_stories.sh [--dry-run|--epic EP-04|--include-optional|--include-post-mvp]`
- Export stories CSV: `bash scripts/export_stories_csv.sh`

## Xcode Project Scaffold

- `ClaudexScreenTimeRewards.xcodeproj` lives at the repo root and includes the iOS app target (parent & child modes).
- Swift sources under `Sources/` are shared across features (pending modularization).
- Entitlement files (`entitlements/`) are placeholders; add Family Controls entitlement after approval.
- Info plists are minimal placeholders in `plist/`.

## Notes

- Requires Apple Family Controls entitlement.
- Uses `FamilyControls`, `ManagedSettings`, `DeviceActivity` (iOS/iPadOS 16+).
- Privacy-first; CloudKit-backed sync; no third-party tracking in child context.
