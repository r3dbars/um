#!/usr/bin/env bash
# Build a universal (arm64 + x86_64) Um.app with the Whisper model.
#
# Usage:
#   ./scripts/package-app.sh
#
# Environment:
#   VERSION            CFBundleShortVersionString (default: 1.0.0; leading "v" is stripped)
#   BUILD              CFBundleVersion            (default: 1)
#   SIGNING_IDENTITY   codesign identity; default is Developer ID Application if
#                      present in the keychain, otherwise ad-hoc ("-")
#
# CI has no Developer ID, so GitHub builds stay ad-hoc. Local machines with a
# Developer ID cert sign for notarization via scripts/notarize.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

VERSION="${VERSION:-1.0.0}"
VERSION="${VERSION#v}"
BUILD="${BUILD:-1}"
APP_NAME="Um"
BUNDLE_ID="com.r3dbars.um"
APP_DIR="${ROOT}/dist/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"
INFO_SRC="${ROOT}/Um/Resources/Info.plist"
ENTITLEMENTS="${ROOT}/Um/Resources/Um.entitlements"
MODEL_PATH="${ROOT}/models/ggml-tiny.en.bin"
MIN_MODEL_BYTES=$((10 * 1024 * 1024))

BINARY=""
BIN_DIR=""
SIGNED_IDENTITY="-"

file_size() {
  local path="$1"
  if stat -f%z "${path}" >/dev/null 2>&1; then
    stat -f%z "${path}"
  else
    stat -c%s "${path}"
  fi
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: package-app.sh must run on macOS (found $(uname -s))." >&2
    exit 1
  fi
}

plist_set_string() {
  local plist="$1"
  local key="$2"
  local value="$3"
  plutil -replace "${key}" -string "${value}" "${plist}"
}

ensure_model() {
  echo "==> Checking Whisper model"
  if [[ ! -f "${MODEL_PATH}" ]] || (( "$(file_size "${MODEL_PATH}")" <= MIN_MODEL_BYTES )); then
    echo "    Model missing or too small; calling download-model.sh"
    "${ROOT}/scripts/download-model.sh"
  else
    echo "    Using ${MODEL_PATH} ($(file_size "${MODEL_PATH}") bytes)"
  fi
}

build_with_xcodebuild() {
  local project="$1"
  local derived="${ROOT}/.build/DerivedData"

  echo "    xcodebuild -project ${project} -scheme ${APP_NAME} -configuration Release (arm64 + x86_64)"
  xcodebuild \
    -project "${project}" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${derived}" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    MACOSX_DEPLOYMENT_TARGET=13.0 \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGNING_REQUIRED=NO \
    build

  local built_app
  built_app="$(find "${derived}/Build/Products" -name "${APP_NAME}.app" -type d 2>/dev/null | head -n 1 || true)"
  if [[ -n "${built_app}" && -d "${built_app}" ]]; then
    echo "    xcodebuild produced ${built_app}"
    mkdir -p "${ROOT}/dist"
    rm -rf "${APP_DIR}"
    ditto "${built_app}" "${APP_DIR}"
    BINARY="${MACOS_DIR}/${APP_NAME}"
    BIN_DIR="$(dirname "${BINARY}")"
    return 0
  fi

  local built_bin
  built_bin="$(find "${derived}/Build/Products" -name "${APP_NAME}" -type f -perm +111 2>/dev/null | head -n 1 || true)"
  if [[ -n "${built_bin}" && -f "${built_bin}" ]]; then
    echo "    xcodebuild produced binary ${built_bin}"
    BINARY="${built_bin}"
    BIN_DIR="$(dirname "${BINARY}")"
    return 0
  fi

  echo "    xcodebuild succeeded but no ${APP_NAME} product was found under ${derived}"
  return 1
}

build_with_swift() {
  echo "    swift build -c release --product ${APP_NAME} --arch arm64 --arch x86_64"
  export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
  swift build -c release --product "${APP_NAME}" --arch arm64 --arch x86_64
  BIN_DIR="$(swift build -c release --show-bin-path --product "${APP_NAME}" --arch arm64 --arch x86_64)"
  BINARY="${BIN_DIR}/${APP_NAME}"
  if [[ ! -f "${BINARY}" ]]; then
    echo "error: swift build finished but ${BINARY} is missing" >&2
    exit 1
  fi
  echo "    Built ${BINARY}"
}

build_binary() {
  echo "==> Building ${APP_NAME}"
  if [[ -d "${ROOT}/Um.xcodeproj" ]]; then
    echo "    Found Um.xcodeproj; trying xcodebuild"
    if build_with_xcodebuild "${ROOT}/Um.xcodeproj"; then
      return 0
    fi
    echo "    xcodebuild failed or produced no product; falling back to swift build"
  else
    echo "    No Um.xcodeproj present; using swift build -c release"
  fi
  build_with_swift
}

copy_icon_if_present() {
  local candidate
  local found=""
  for candidate in \
    "${ROOT}/Um/Resources/AppIcon.icns" \
    "${ROOT}/Um/Resources/Assets/AppIcon.icns" \
    "${ROOT}/Um/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.icns" \
    "${ROOT}/Assets/AppIcon.icns" \
    "${ROOT}/Assets.xcassets/AppIcon.appiconset/AppIcon.icns"
  do
    if [[ -f "${candidate}" ]]; then
      found="${candidate}"
      break
    fi
  done

  if [[ -z "${found}" && -f "${ROOT}/Um/Resources/AppIcon-1024.png" ]] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
    echo "    Building AppIcon.icns from AppIcon-1024.png"
    local iconset
    iconset="$(mktemp -d "${TMPDIR:-/tmp}/um-iconset.XXXXXX")"
    mkdir -p "${iconset}/AppIcon.iconset"
    local src="${ROOT}/Um/Resources/AppIcon-1024.png"
    sips -z 16 16     "${src}" --out "${iconset}/AppIcon.iconset/icon_16x16.png" >/dev/null
    sips -z 32 32     "${src}" --out "${iconset}/AppIcon.iconset/icon_16x16@2x.png" >/dev/null
    sips -z 32 32     "${src}" --out "${iconset}/AppIcon.iconset/icon_32x32.png" >/dev/null
    sips -z 64 64     "${src}" --out "${iconset}/AppIcon.iconset/icon_32x32@2x.png" >/dev/null
    sips -z 128 128   "${src}" --out "${iconset}/AppIcon.iconset/icon_128x128.png" >/dev/null
    sips -z 256 256   "${src}" --out "${iconset}/AppIcon.iconset/icon_128x128@2x.png" >/dev/null
    sips -z 256 256   "${src}" --out "${iconset}/AppIcon.iconset/icon_256x256.png" >/dev/null
    sips -z 512 512   "${src}" --out "${iconset}/AppIcon.iconset/icon_256x256@2x.png" >/dev/null
    sips -z 512 512   "${src}" --out "${iconset}/AppIcon.iconset/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "${src}" --out "${iconset}/AppIcon.iconset/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "${iconset}/AppIcon.iconset" -o "${RESOURCES_DIR}/AppIcon.icns"
    rm -rf "${iconset}"
    plist_set_string "${CONTENTS}/Info.plist" "CFBundleIconFile" "AppIcon"
    return 0
  fi

  if [[ -z "${found}" ]]; then
    local search_roots=()
    [[ -d "${ROOT}/Um" ]] && search_roots+=("${ROOT}/Um")
    [[ -d "${ROOT}/Assets" ]] && search_roots+=("${ROOT}/Assets")
    if ((${#search_roots[@]} > 0)); then
      found="$(find "${search_roots[@]}" -name 'AppIcon.icns' -type f 2>/dev/null | head -n 1 || true)"
    fi
  fi

  if [[ -n "${found}" && -f "${found}" ]]; then
    echo "    Copying app icon from ${found}"
    cp -f "${found}" "${RESOURCES_DIR}/AppIcon.icns"
    plist_set_string "${CONTENTS}/Info.plist" "CFBundleIconFile" "AppIcon"
  else
    echo "    No AppIcon.icns found (looked in Um/Resources and Assets); skipping icon"
  fi
}

copy_support_libraries() {
  local binary="$1"
  local frameworks="${CONTENTS}/Frameworks"
  local copied=0
  local dep name

  if [[ -z "${BIN_DIR}" || ! -d "${BIN_DIR}" ]]; then
    return 0
  fi

  shopt -s nullglob
  local bundle
  for bundle in "${BIN_DIR}"/*.bundle; do
    echo "    Copying resource bundle $(basename "${bundle}")"
    cp -R "${bundle}" "${RESOURCES_DIR}/"
  done
  shopt -u nullglob

  if ! command -v otool >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r dep; do
    [[ -z "${dep}" ]] && continue
    name="$(basename "${dep}")"
    case "${dep}" in
      /usr/*|/System/*|/Library/*) continue ;;
    esac

    if [[ "${dep}" == @* ]]; then
      if [[ -f "${BIN_DIR}/${name}" ]]; then
        mkdir -p "${frameworks}"
        cp -f "${BIN_DIR}/${name}" "${frameworks}/${name}"
        install_name_tool -change "${dep}" "@executable_path/../Frameworks/${name}" "${binary}"
        copied=1
      fi
      continue
    fi

    if [[ -f "${dep}" ]]; then
      mkdir -p "${frameworks}"
      cp -f "${dep}" "${frameworks}/${name}"
      install_name_tool -change "${dep}" "@executable_path/../Frameworks/${name}" "${binary}"
      copied=1
    fi
  done < <(otool -L "${binary}" | awk 'NR > 1 { print $1 }')

  if (( copied )); then
    echo "    Copied bundled dynamic libraries into Contents/Frameworks"
  fi
}

assemble_bundle() {
  echo "==> Assembling ${APP_DIR}"

  if [[ -f "${MACOS_DIR}/${APP_NAME}" && "${BINARY}" == "${MACOS_DIR}/${APP_NAME}" ]]; then
    echo "    Using xcodebuild .app as the bundle base"
  else
    rm -rf "${APP_DIR}"
    mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
    echo "    Copying executable"
    cp -f "${BINARY}" "${MACOS_DIR}/${APP_NAME}"
    BINARY="${MACOS_DIR}/${APP_NAME}"
    copy_support_libraries "${BINARY}"
  fi

  mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
  chmod +x "${MACOS_DIR}/${APP_NAME}"

  if [[ ! -f "${INFO_SRC}" ]]; then
    echo "error: missing ${INFO_SRC}" >&2
    exit 1
  fi

  echo "    Writing Info.plist (version ${VERSION}, build ${BUILD}, id ${BUNDLE_ID})"
  cp -f "${INFO_SRC}" "${CONTENTS}/Info.plist"
  plist_set_string "${CONTENTS}/Info.plist" "CFBundleExecutable" "${APP_NAME}"
  plist_set_string "${CONTENTS}/Info.plist" "CFBundleName" "${APP_NAME}"
  plist_set_string "${CONTENTS}/Info.plist" "CFBundleDisplayName" "${APP_NAME}"
  plist_set_string "${CONTENTS}/Info.plist" "CFBundleIdentifier" "${BUNDLE_ID}"
  plist_set_string "${CONTENTS}/Info.plist" "CFBundleShortVersionString" "${VERSION}"
  plist_set_string "${CONTENTS}/Info.plist" "CFBundleVersion" "${BUILD}"
  plist_set_string "${CONTENTS}/Info.plist" "CFBundlePackageType" "APPL"

  printf 'APPL????' > "${CONTENTS}/PkgInfo"

  echo "    Copying model to Contents/Resources/ggml-tiny.en.bin"
  cp -f "${MODEL_PATH}" "${RESOURCES_DIR}/ggml-tiny.en.bin"

  copy_icon_if_present
}

resolve_signing_identity() {
  if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    echo "${SIGNING_IDENTITY}"
    return
  fi
  local name
  name="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ { print $2; exit }' || true)"
  if [[ -n "${name}" ]]; then
    echo "${name}"
    return
  fi
  echo "-"
}

codesign_app() {
  if [[ ! -f "${ENTITLEMENTS}" ]]; then
    echo "error: missing entitlements file ${ENTITLEMENTS}" >&2
    exit 1
  fi

  local identity
  identity="$(resolve_signing_identity)"
  SIGNED_IDENTITY="${identity}"

  if [[ "${identity}" == "-" ]]; then
    echo "==> Ad-hoc codesigning (no Developer ID Application in the keychain)"
    echo "    Gatekeeper will show an unidentified-developer warning."
    echo "    First launch: right-click Um.app → Open → Open."
    codesign --force --deep --sign - --entitlements "${ENTITLEMENTS}" "${APP_DIR}"
  else
    echo "==> Signing with Developer ID: ${identity}"
    codesign --force --deep --options runtime --timestamp --sign "${identity}" --entitlements "${ENTITLEMENTS}" "${APP_DIR}"
  fi
  chmod +x "${MACOS_DIR}/${APP_NAME}"

  echo "    Signature:"
  codesign -dv --verbose=2 "${APP_DIR}" 2>&1 || true
  codesign --verify --verbose "${APP_DIR}"
}

print_summary() {
  echo "==> Packaged ${APP_DIR}"
  echo "    Version:  ${VERSION} (${BUILD})"
  echo "    Bundle:   ${BUNDLE_ID}"
  echo "    Binary:   ${MACOS_DIR}/${APP_NAME}"
  echo "    Model:    ${RESOURCES_DIR}/ggml-tiny.en.bin"
  echo "    Signing:  ${SIGNED_IDENTITY} with ${ENTITLEMENTS}"
  du -sh "${APP_DIR}" || true
}

main() {
  require_macos
  mkdir -p "${ROOT}/dist"
  ensure_model
  build_binary
  assemble_bundle
  codesign_app
  print_summary
}

main "$@"
