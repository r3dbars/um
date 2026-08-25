#!/usr/bin/env bash
# Notarize a Developer ID–signed Um.app or DMG.
# Requires:
#   - "Developer ID Application" in the keychain (Apple Development is not enough)
#   - a notarytool keychain profile, default name um-notarize
#     (xcrun notarytool store-credentials um-notarize)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET="${1:-${ROOT}/dist/Um.app}"
PROFILE="${NOTARY_PROFILE:-um-notarize}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: notarize.sh must run on macOS" >&2
  exit 1
fi

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q 'Developer ID Application'; then
  echo "error: no Developer ID Application certificate in the keychain." >&2
  echo "    This Mac only has Apple Development, which cannot notarize a download." >&2
  echo "    Create a Developer ID cert at https://developer.apple.com/account/resources/certificates/list" >&2
  echo "    then: xcrun notarytool store-credentials ${PROFILE}" >&2
  exit 1
fi

if [[ ! -e "${TARGET}" ]]; then
  echo "error: ${TARGET} does not exist. Package first." >&2
  exit 1
fi

echo "==> Submitting ${TARGET} with profile ${PROFILE}"
xcrun notarytool submit "${TARGET}" --keychain-profile "${PROFILE}" --wait
if [[ -d "${TARGET}" ]]; then
  xcrun stapler staple "${TARGET}"
fi
echo "==> Notarized ${TARGET}"
