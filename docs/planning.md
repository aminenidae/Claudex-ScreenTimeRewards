# Planning Board Setup

This guide helps you bootstrap Epics/Stories and a lightweight board using GitHub Issues and Labels.

## 1) Labels

- Labels are defined in `.github/labels.yml` and synced by a GitHub Action in `.github/workflows/labels.yml`.
- After pushing to `main`, labels will appear automatically on the repository.

Key labels
- `type: epic`, `type: story`, `type: task`, `type: bug`
- `phase: mvp`, `phase: post-mvp`
- `platform: ios`, `platform: macos`
- `role: parent`, `role: child`
- `priority: p0|p1|p2`
- `epic: ep-01` … `epic: ep-14`

## 2) Issue Templates

- Use `New issue` → choose "Epic" or "Story" templates.
- Epics reference PRD §23 and track their Stories via checklists.

## 3) Project Board (Suggested)

- Columns: Backlog, Ready, In Progress, In Review, Blocked, Done.
- Automation: New issues → Backlog; Closed → Done.
- Filters: Use labels to filter by `phase`, `platform`, `epic`.

## 4) Seeding Epics via GitHub CLI (optional)

Requirements
- Install GitHub CLI: `brew install gh`
- Auth: `gh auth login`

Run script
- `bash scripts/seed_epics.sh`
- The script creates one issue per Epic with title `[EPIC] EP-XX: …`, labels `type: epic`, `epic: ep-XX`, and a `phase` label.

## 5) Seeding Stories via GitHub CLI (optional)

Seed MVP stories from PRD §23 under their corresponding epics.

Commands
- Dry run: `bash scripts/seed_stories.sh --dry-run`
- Seed MVP only: `bash scripts/seed_stories.sh`
- Include optional MVP (EP-11): `bash scripts/seed_stories.sh --include-optional`
- Include Post-MVP (EP-12 and EP-13 S-1302): `bash scripts/seed_stories.sh --include-post-mvp`
- Single epic: `bash scripts/seed_stories.sh --epic EP-04`

Notes
- Script applies labels: `type: story`, `epic: ep-XX`, `phase: mvp|post-mvp`, `platform: ios|macos`, `role: parent|child`.
- After creation, open each story to add detailed AC and link to its Epic issue.

## 5) Creating Stories

- From each Epic, create Story issues using the Story template.
- Title format: `[STORY] S-XXXX: …` and add labels `type: story`, `epic: ep-XX`, and a `phase`.
- Reference acceptance criteria from `PRD.md` §23 and `docs/checklists.md` DoR/DoD.

## 6) Mapping (PRD §23)

- EP-01 → Screen Time Foundations (MVP)
- EP-02 → Pairing & Family Association (MVP)
- EP-03 → App Categorization & Rules (MVP)
- EP-04 → Points Engine & Integrity (MVP)
- EP-05 → Redemption & Shielding (MVP)
- EP-06 → Sync & Multi-Parent (MVP)
- EP-07 → Dashboard & Reporting (MVP)
- EP-08 → Notifications (MVP)
- EP-09 → Privacy, Security, Compliance (MVP)
- EP-10 → Accessibility & Localization (MVP)
- EP-11 → Monetization & Paywall (Optional MVP)
- EP-12 → Learning Depth & Engagement (Post-MVP)
- EP-13 → macOS Enhancements (MVP/Post-MVP)
- EP-14 → Dev Experience & QA Infra (MVP)
