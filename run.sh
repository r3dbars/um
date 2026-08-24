#!/bin/bash
# Quick debug loop: model + SwiftPM debug build + launch.
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Um is a Mac app. Build it on macOS (or use the GitHub Actions Release workflow)."
  exit 1
fi

./scripts/download-model.sh
echo "Building Um (debug)..."
swift build
echo "Launching Um — look for the bubble in the menu bar."
.build/debug/Um &
