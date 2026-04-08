#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRODUCT_NAME="Google Drive Icon Guard"
EXECUTABLE_PRODUCT="drive-icon-guard-viewer"
HELPER_EXECUTABLE_PRODUCT="drive-icon-guard-helper"
APP_NAME="${PRODUCT_NAME}.app"
BUNDLE_ID="com.richardgeorgedavis.google-drive-icon-guard.beta"
MINIMUM_MACOS_VERSION="13.0"
RELEASE_VERSION="${RELEASE_VERSION:-0.1.0-beta}"
RELEASE_BUILD_NUMBER="${RELEASE_BUILD_NUMBER:-1}"
ARCHIVE_BASENAME="${ARCHIVE_BASENAME:-google-drive-icon-guard-beta-unsigned}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
APP_CODESIGN_ENTITLEMENTS="${APP_CODESIGN_ENTITLEMENTS:-}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"
CMS_SIGN_IDENTITY="${CMS_SIGN_IDENTITY:-}"
DIST_ROOT="${PROJECT_ROOT}/dist"
BUILD_ROOT="${DIST_ROOT}/build"
APP_ROOT="${DIST_ROOT}/${APP_NAME}"
APP_CONTENTS="${APP_ROOT}/Contents"
APP_MACOS="${APP_CONTENTS}/MacOS"
APP_HELPERS="${APP_CONTENTS}/Helpers"
APP_RESOURCES="${APP_CONTENTS}/Resources"
APP_INSTALLER_RESOURCES="${APP_RESOURCES}/Installer"
EXECUTABLE_SOURCE="${PROJECT_ROOT}/.build/release/${EXECUTABLE_PRODUCT}"
EXECUTABLE_DESTINATION="${APP_MACOS}/${PRODUCT_NAME}"
HELPER_EXECUTABLE_SOURCE="${PROJECT_ROOT}/.build/release/${HELPER_EXECUTABLE_PRODUCT}"
HELPER_EXECUTABLE_DESTINATION="${APP_HELPERS}/${HELPER_EXECUTABLE_PRODUCT}"
INSTALLER_RESOURCE_SOURCE="${PROJECT_ROOT}/Installer/ServiceRegistration"
ZIP_PATH="${DIST_ROOT}/${ARCHIVE_BASENAME}.zip"
CHECKSUM_PATH="${ZIP_PATH}.sha256"
HELPER_STATUS_PATH="${DIST_ROOT}/${ARCHIVE_BASENAME}.helper-status.json"
PROVENANCE_PATH="${DIST_ROOT}/${ARCHIVE_BASENAME}.provenance.json"
PROVENANCE_SIGNATURE_PATH="${PROVENANCE_PATH}.cms"
ICON_SOURCE="${PROJECT_ROOT}/icon.png"
ICON_BASENAME="AppIcon"
ICONSET_PATH="${BUILD_ROOT}/${ICON_BASENAME}.iconset"
ICON_ICNS_PATH="${APP_RESOURCES}/${ICON_BASENAME}.icns"

if [ -n "${NOTARYTOOL_PROFILE}" ] && [ -z "${CODESIGN_IDENTITY}" ]; then
  echo "NOTARYTOOL_PROFILE requires CODESIGN_IDENTITY." >&2
  exit 1
fi

if [ -n "${APP_CODESIGN_ENTITLEMENTS}" ] && [ ! -f "${APP_CODESIGN_ENTITLEMENTS}" ]; then
  echo "Missing APP_CODESIGN_ENTITLEMENTS file: ${APP_CODESIGN_ENTITLEMENTS}" >&2
  exit 1
fi

create_archive() {
  echo "Creating zip archive..."
  /usr/bin/ditto -c -k --keepParent "${APP_ROOT}" "${ZIP_PATH}"
  (
    cd "${DIST_ROOT}"
    shasum -a 256 "$(basename "${ZIP_PATH}")" > "$(basename "${CHECKSUM_PATH}")"
  )
}

sign_bundle_if_configured() {
  if [ -z "${CODESIGN_IDENTITY}" ]; then
    return
  fi

  echo "Signing helper executable..."
  codesign --force --sign "${CODESIGN_IDENTITY}" --timestamp --options runtime "${HELPER_EXECUTABLE_DESTINATION}"

  echo "Signing app bundle..."
  if [ -n "${APP_CODESIGN_ENTITLEMENTS}" ]; then
    codesign \
      --force \
      --sign "${CODESIGN_IDENTITY}" \
      --timestamp \
      --options runtime \
      --entitlements "${APP_CODESIGN_ENTITLEMENTS}" \
      "${APP_ROOT}"
  else
    codesign --force --sign "${CODESIGN_IDENTITY}" --timestamp --options runtime "${APP_ROOT}"
  fi

  codesign --verify --deep --strict --verbose=2 "${APP_ROOT}"
}

notarize_if_configured() {
  if [ -z "${NOTARYTOOL_PROFILE}" ]; then
    return
  fi

  echo "Submitting archive for notarization..."
  xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARYTOOL_PROFILE}" --wait

  echo "Stapling notarization ticket..."
  xcrun stapler staple "${APP_ROOT}"
  xcrun stapler validate "${APP_ROOT}"

  create_archive
}

write_helper_status() {
  "${HELPER_EXECUTABLE_DESTINATION}" --status --json > "${HELPER_STATUS_PATH}"
}

write_provenance() {
  local checksum_value
  local built_at_utc
  local git_commit
  local git_ref
  local git_branch
  local swift_version
  local developer_dir
  local signed_state
  local notarized_state

  checksum_value="$(awk '{print $1}' "${CHECKSUM_PATH}")"
  built_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  git_commit="$(git -C "${PROJECT_ROOT}" rev-parse HEAD 2>/dev/null || echo unknown)"
  git_ref="$(git -C "${PROJECT_ROOT}" describe --tags --always --dirty 2>/dev/null || echo unknown)"
  git_branch="$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  swift_version="$(swift --version | head -n 1)"
  developer_dir="$(xcode-select -p)"
  signed_state="false"
  notarized_state="false"

  if [ -n "${CODESIGN_IDENTITY}" ]; then
    signed_state="true"
  fi

  if [ -n "${NOTARYTOOL_PROFILE}" ]; then
    notarized_state="true"
  fi

  CHECKSUM_VALUE="${checksum_value}" \
  BUILT_AT_UTC="${built_at_utc}" \
  GIT_COMMIT="${git_commit}" \
  GIT_REF="${git_ref}" \
  GIT_BRANCH="${git_branch}" \
  SWIFT_VERSION="${swift_version}" \
  DEVELOPER_DIR="${developer_dir}" \
  SIGNED_STATE="${signed_state}" \
  NOTARIZED_STATE="${notarized_state}" \
  python3 - <<'PY' > "${PROVENANCE_PATH}"
import json
import os
from pathlib import Path

with open(os.environ["HELPER_STATUS_PATH"], "r", encoding="utf-8") as handle:
    helper_status = json.load(handle)

payload = {
    "product": {
        "name": os.environ["PRODUCT_NAME"],
        "bundleIdentifier": os.environ["BUNDLE_ID"],
        "version": os.environ["RELEASE_VERSION"],
        "buildNumber": os.environ["RELEASE_BUILD_NUMBER"],
        "minimumMacOSVersion": os.environ["MINIMUM_MACOS_VERSION"],
    },
    "build": {
        "builtAtUTC": os.environ["BUILT_AT_UTC"],
        "gitCommit": os.environ["GIT_COMMIT"],
        "gitRef": os.environ["GIT_REF"],
        "gitBranch": os.environ["GIT_BRANCH"],
        "swiftVersion": os.environ["SWIFT_VERSION"],
        "developerDirectory": os.environ["DEVELOPER_DIR"],
    },
    "artifacts": {
        "appBundle": os.environ["APP_ROOT"],
        "zip": os.environ["ZIP_PATH"],
        "zipSha256": os.environ["CHECKSUM_VALUE"],
        "checksumFile": os.environ["CHECKSUM_PATH"],
        "helperStatusFile": os.environ["HELPER_STATUS_PATH"],
        "helperExecutable": os.environ["HELPER_EXECUTABLE_DESTINATION"],
    },
    "releaseTrust": {
        "codesigned": os.environ["SIGNED_STATE"] == "true",
        "notarized": os.environ["NOTARIZED_STATE"] == "true",
        "codesignIdentity": os.environ["CODESIGN_IDENTITY"] or None,
        "notarytoolProfile": os.environ["NOTARYTOOL_PROFILE"] or None,
        "provenanceSignatureFile": (
            str(Path(os.environ["PROVENANCE_SIGNATURE_PATH"]).name)
            if os.environ["CMS_SIGN_IDENTITY"]
            else None
        ),
    },
    "helperStatus": helper_status,
}

json.dump(payload, fp=os.sys.stdout, indent=2)
os.sys.stdout.write("\n")
PY
}

sign_provenance_if_configured() {
  if [ -z "${CMS_SIGN_IDENTITY}" ]; then
    return
  fi

  echo "Signing provenance manifest..."
  security cms \
    -S \
    -N "${CMS_SIGN_IDENTITY}" \
    -u 6 \
    -H SHA256 \
    -G \
    -i "${PROVENANCE_PATH}" \
    -o "${PROVENANCE_SIGNATURE_PATH}"
}

echo "Building release executable..."
cd "${PROJECT_ROOT}"
swift build -c release

echo "Preparing app bundle..."
rm -rf \
  "${APP_ROOT}" \
  "${ZIP_PATH}" \
  "${CHECKSUM_PATH}" \
  "${HELPER_STATUS_PATH}" \
  "${PROVENANCE_PATH}" \
  "${PROVENANCE_SIGNATURE_PATH}" \
  "${BUILD_ROOT}"
mkdir -p "${APP_MACOS}" "${APP_HELPERS}" "${APP_RESOURCES}" "${APP_INSTALLER_RESOURCES}" "${BUILD_ROOT}"

cp "${EXECUTABLE_SOURCE}" "${EXECUTABLE_DESTINATION}"
chmod +x "${EXECUTABLE_DESTINATION}"
cp "${HELPER_EXECUTABLE_SOURCE}" "${HELPER_EXECUTABLE_DESTINATION}"
chmod +x "${HELPER_EXECUTABLE_DESTINATION}"

if [ -d "${INSTALLER_RESOURCE_SOURCE}" ]; then
  cp -R "${INSTALLER_RESOURCE_SOURCE}" "${APP_INSTALLER_RESOURCES}/"
fi

if [ -f "${ICON_SOURCE}" ]; then
  ICON_WIDTH="$(sips -g pixelWidth "${ICON_SOURCE}" | awk '/pixelWidth:/ { print $2 }')"
  ICON_HEIGHT="$(sips -g pixelHeight "${ICON_SOURCE}" | awk '/pixelHeight:/ { print $2 }')"
  ICON_SQUARE_SIZE="${ICON_WIDTH}"

  if [ "${ICON_HEIGHT}" -lt "${ICON_SQUARE_SIZE}" ]; then
    ICON_SQUARE_SIZE="${ICON_HEIGHT}"
  fi

  mkdir -p "${ICONSET_PATH}"
  SQUARE_SOURCE="${BUILD_ROOT}/${ICON_BASENAME}-square.png"
  cp "${ICON_SOURCE}" "${SQUARE_SOURCE}"
  sips -c "${ICON_SQUARE_SIZE}" "${ICON_SQUARE_SIZE}" "${SQUARE_SOURCE}" >/dev/null

  for SIZE in 16 32 128 256 512; do
    sips -z "${SIZE}" "${SIZE}" "${SQUARE_SOURCE}" --out "${ICONSET_PATH}/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE_SIZE="$((SIZE * 2))"
    sips -z "${DOUBLE_SIZE}" "${DOUBLE_SIZE}" "${SQUARE_SOURCE}" --out "${ICONSET_PATH}/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
  done

  iconutil -c icns "${ICONSET_PATH}" -o "${ICON_ICNS_PATH}"
fi

cat > "${APP_CONTENTS}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>${ICON_BASENAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${RELEASE_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${RELEASE_BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MINIMUM_MACOS_VERSION}</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

sign_bundle_if_configured
create_archive
notarize_if_configured
write_helper_status

export PRODUCT_NAME
export BUNDLE_ID
export RELEASE_VERSION
export RELEASE_BUILD_NUMBER
export MINIMUM_MACOS_VERSION
export APP_ROOT
export ZIP_PATH
export CHECKSUM_PATH
export HELPER_STATUS_PATH
export HELPER_EXECUTABLE_DESTINATION
export CODESIGN_IDENTITY
export NOTARYTOOL_PROFILE
export CMS_SIGN_IDENTITY
export PROVENANCE_SIGNATURE_PATH
write_provenance
sign_provenance_if_configured

echo "Running artifact verification..."
ARCHIVE_BASENAME="${ARCHIVE_BASENAME}" "${PROJECT_ROOT}/Tools/release/verify-beta-artifacts.sh"

echo
echo "Beta app created:"
echo "  App: ${APP_ROOT}"
echo "  Zip: ${ZIP_PATH}"
echo "  Checksum: ${CHECKSUM_PATH}"
echo "  Helper: ${HELPER_EXECUTABLE_DESTINATION}"
echo "  Helper status: ${HELPER_STATUS_PATH}"
echo "  Provenance: ${PROVENANCE_PATH}"

if [ -f "${PROVENANCE_SIGNATURE_PATH}" ]; then
  echo "  Provenance signature: ${PROVENANCE_SIGNATURE_PATH}"
fi

echo
echo "Release trust:"
if [ -n "${CODESIGN_IDENTITY}" ]; then
  echo "  - App bundle and helper are signed."
else
  echo "  - App bundle is unsigned."
fi

if [ -n "${NOTARYTOOL_PROFILE}" ]; then
  echo "  - App bundle is notarized and stapled."
else
  echo "  - App bundle is not notarized."
fi
