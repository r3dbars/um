#!/usr/bin/env bash
# Create a UDZO disk image containing Um.app and an Applications symlink.
#
# Usage:
#   ./scripts/create-dmg.sh [path/to/Um.app]
#
# Environment:
#   VERSION   Used in the filename Um-${VERSION}.dmg (default: read from Info.plist, else 1.0.0)
#
# Output:
#   dist/Um-${VERSION}.dmg
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: create-dmg.sh must run on macOS (found $(uname -s))." >&2
    exit 1
  fi
}

read_version_from_plist() {
  local plist="$1"
  if [[ -f "${plist}" ]] && command -v plutil >/dev/null 2>&1; then
    plutil -extract CFBundleShortVersionString raw "${plist}" 2>/dev/null || true
  fi
}

require_macos

APP="${1:-${ROOT}/dist/Um.app}"
if [[ ! -d "${APP}" ]]; then
  echo "error: ${APP} does not exist. Run ./scripts/package-app.sh first." >&2
  exit 1
fi

PLIST="${APP}/Contents/Info.plist"
if [[ -z "${VERSION:-}" ]]; then
  VERSION="$(read_version_from_plist "${PLIST}")"
fi
VERSION="${VERSION:-1.0.0}"
VERSION="${VERSION#v}"

DMG_NAME="Um-${VERSION}.dmg"
DEST="${ROOT}/dist/${DMG_NAME}"
VOLNAME="Um ${VERSION}"

echo "==> Creating ${DEST}"
echo "    App: ${APP}"

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/um-dmg.XXXXXX")"
cleanup() {
  rm -rf "${STAGING}"
}
trap cleanup EXIT

echo "    Staging folder: ${STAGING}"
ditto "${APP}" "${STAGING}/Um.app"
ln -s /Applications "${STAGING}/Applications"

# First-launch note (ad-hoc signed; no Developer ID in CI).
cat > "${STAGING}/How to open.txt" <<EOF
Um ${VERSION}

This build is ad-hoc signed. Apple Gatekeeper will warn that the developer
cannot be verified the first time you open it.

To launch:
  1. Drag Um into Applications (or run it from this disk image).
  2. Right-click Um.app and choose Open.
  3. Click Open in the dialog.

After that, you can open Um normally from Applications or Spotlight.

macOS 13 or later is required. Audio is processed on your Mac only.
EOF

mkdir -p "${ROOT}/dist"
rm -f "${DEST}"

echo "    hdiutil create -format UDZO ${DEST}"
hdiutil create \
  -volname "${VOLNAME}" \
  -srcfolder "${STAGING}" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "${DEST}"

if [[ ! -f "${DEST}" ]]; then
  echo "error: hdiutil finished but ${DEST} is missing" >&2
  exit 1
fi

echo "==> DMG ready: ${DEST}"
du -sh "${DEST}" || true
