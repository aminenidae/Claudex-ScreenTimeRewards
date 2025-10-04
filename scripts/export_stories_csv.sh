#!/usr/bin/env bash
set -euo pipefail

# Export stories (ID, Epic, Title, Phase, Platforms, Roles) to CSV
# Source of truth: scripts/seed_stories.sh STORIES array

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SEED_FILE="$SCRIPT_DIR/seed_stories.sh"
OUT_FILE="$SCRIPT_DIR/../docs/stories.csv"

if [[ ! -f "$SEED_FILE" ]]; then
  echo "Cannot find seed_stories.sh at $SEED_FILE" >&2
  exit 1
fi

# Extract STORIES array entries and print CSV
{
  echo "story_id,epic_id,title,phase,platforms,roles"
  awk -v dq='"' '/^STORIES=\(/, /^\)/ { \
    if ($0 ~ /\"S-[0-9]+\|EP-[0-9]+\|/) { \
      line=$0; \
      gsub(/^\s*\"|\",?\s*$/, "", line); \
      n=split(line, parts, "\\|"); \
      if (n==6) { \
        id=parts[1]; epic=parts[2]; title=parts[3]; phase=parts[4]; plats=parts[5]; roles=parts[6]; \
        # Escape quotes in title
        gsub(dq, dq dq, title); \
        printf "%s,%s,%s,%s,%s,%s\n", id, epic, dq title dq, phase, plats, roles; \
      } \
    } \
  }' "$SEED_FILE"
} > "$OUT_FILE"

echo "Wrote $OUT_FILE"

