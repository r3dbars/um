#!/usr/bin/env bash
# Fail if Swift diagnostic logs interpolate transcript text as privacy: .public.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! command -v rg >/dev/null 2>&1; then
  echo "error: rg (ripgrep) is required" >&2
  exit 1
fi

# Interpolating transcript / cleaned transcript as a public log field.
if rg -n --pcre2 -g '*.swift' \
  '\\\((transcript|cleaned)\b[^)]*privacy:\s*\.public' \
  . ; then
  echo "error: diagnostic logs must not record transcript text as public" >&2
  exit 1
fi

# Labeled transcript payloads in logger strings.
if rg -n --pcre2 -g '*.swift' \
  'logger\.\w+\("[^"]*[Tt]ranscript: \\' \
  . ; then
  echo "error: do not log transcript payloads" >&2
  exit 1
fi

echo "OK: no public transcript logs"
