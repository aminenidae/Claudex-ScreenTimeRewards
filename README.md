# Claudex Screen Time Rewards

Reward-based screen time management for families using Apple Screen Time APIs.

## Quick Start

- Read the product plan: `PRD.md`
- Validate feasibility and spikes: `docs/feasibility.md`
- Review QA checklists: `docs/checklists.md`
- See CloudKit schema draft: `docs/data-model.md`
- Planning board guide: `docs/planning.md`
- Story inventory (CSV): `docs/stories.csv`

## Platforms

- Parent app: iOS/iPadOS 16+ and macOS 13+
- Child app: iOS 16+ only

## Planning Helpers

- Labels sync (GitHub Action): `.github/labels.yml`
- Issue templates: `.github/ISSUE_TEMPLATE/`
- Seed epics: `bash scripts/seed_epics.sh`
- Seed stories: `bash scripts/seed_stories.sh [--dry-run|--epic EP-04|--include-optional|--include-post-mvp]`
- Export stories CSV: `bash scripts/export_stories_csv.sh`

## Xcode Project Scaffold

- Modules are defined via Swift Package `Package.swift` (Core, ScreenTimeService, PointsEngine, SyncKit).
- App targets and the DeviceActivityReport extension are defined via XcodeGen spec at `.xcodegen/project.yml`.
- Generate the Xcode project:
  - Install XcodeGen: `brew install xcodegen`
  - Run: `bash scripts/bootstrap_xcodeproj.sh`
  - Open: `.xcodegen/ClaudexScreenTimeRewards.xcodeproj`

Notes
- Entitlements are placeholders in `entitlements/`. Request and add Family Controls entitlement for parent apps.
- Plists are minimal placeholders under `plist/`.

## Notes

- Requires Apple Family Controls entitlement.
- Uses `FamilyControls`, `ManagedSettings`, `DeviceActivity` (iOS/iPadOS 16+, macOS 13+).
- Privacy-first; CloudKit-backed sync; no third-party tracking in child context.
