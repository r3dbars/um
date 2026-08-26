#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
if rg -n --glob '*.swift' -e '\\\(transcript' -e '\\\(cleaned' -e '\\\(result\.bestTranscription' "$root/Um/Sources" | rg -i 'privacy:\s*\.public'; then
  echo "FAIL: transcript text logged with privacy: .public" >&2
  exit 1
fi
echo "OK: no public transcript logs"
