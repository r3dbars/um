#!/usr/bin/env bash
# Fail if Swift diagnostic logs interpolate transcript text as privacy: .public.
# Python so CI does not depend on ripgrep.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

python3 - <<'PY'
from pathlib import Path
import re
import sys

interpolated = re.compile(
    r"\\\((transcript|cleaned)\b[^)]*privacy:\s*\.public"
)
labeled = re.compile(r'logger\.\w+\("[^"]*[Tt]ranscript: \\')
hits = []
skip_dirs = {".build", "DerivedData", ".git", "node_modules"}
for path in Path(".").rglob("*.swift"):
    if not path.is_file() or any(part in skip_dirs for part in path.parts):
        continue
    text = path.read_text(encoding="utf-8")
    for lineno, line in enumerate(text.splitlines(), 1):
        if interpolated.search(line) or labeled.search(line):
            hits.append(f"{path}:{lineno}:{line}")
if hits:
    print("\n".join(hits), file=sys.stderr)
    if any(interpolated.search(line.split(":", 2)[-1]) for line in hits):
        print(
            "error: diagnostic logs must not record transcript text as public",
            file=sys.stderr,
        )
    else:
        print("error: do not log transcript payloads", file=sys.stderr)
    raise SystemExit(1)
print("OK: no public transcript logs")
PY
