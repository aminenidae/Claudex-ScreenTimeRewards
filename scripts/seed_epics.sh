#!/usr/bin/env bash
set -euo pipefail

# Seed Epic issues using GitHub CLI
# Requirements: gh auth login; repo context set (run inside the repo directory)

declare -A EPICS=(
  ["EP-01"]="Screen Time Foundations (Entitlements & Authorization)"
  ["EP-02"]="Pairing & Family Association"
  ["EP-03"]="App Categorization & Rules"
  ["EP-04"]="Points Engine & Integrity"
  ["EP-05"]="Redemption & Shielding"
  ["EP-06"]="Sync & Multi-Parent"
  ["EP-07"]="Dashboard & Reporting"
  ["EP-08"]="Notifications"
  ["EP-09"]="Privacy, Security, Compliance"
  ["EP-10"]="Accessibility & Localization"
  ["EP-11"]="Monetization & Paywall (Optional)"
  ["EP-12"]="Learning Depth & Engagement (Post-MVP)"
  ["EP-13"]="macOS Enhancements"
  ["EP-14"]="Dev Experience & QA Infrastructure"
)

function phase_for_epic() {
  case "$1" in
    EP-12) echo "phase: post-mvp" ;;
    *) echo "phase: mvp" ;;
  esac
}

for EP in "${!EPICS[@]}"; do
  TITLE="[EPIC] ${EP}: ${EPICS[$EP]}"
  EP_NUM=$(echo "$EP" | tr '[:upper:]' '[:lower:]')
  EP_LABEL="epic: ${EP_NUM}"
  PHASE_LABEL=$(phase_for_epic "$EP")

  echo "Creating: $TITLE"
  gh issue create \
    --title "$TITLE" \
    --label "type: epic" \
    --label "$EP_LABEL" \
    --label "$PHASE_LABEL" \
    --body "Refer to PRD.md §23 for stories and acceptance. Add story checklists and link child issues here."
done

echo "Done. Review issues and adjust labels as needed."

