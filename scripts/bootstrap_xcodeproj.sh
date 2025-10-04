#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is not installed. Install via: brew install xcodegen" >&2
  exit 1
fi

pushd .xcodegen >/dev/null
xcodegen generate
popd >/dev/null

echo "Generated Xcode project in .xcodegen. Open ClaudexScreenTimeRewards.xcodeproj."

