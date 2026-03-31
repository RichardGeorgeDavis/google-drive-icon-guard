#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRODUCT_NAME="Google Drive Icon Guard"
EXECUTABLE_PRODUCT="drive-icon-guard-viewer"
HELPER_EXECUTABLE_PRODUCT="drive-icon-guard-helper"
APP_NAME="${PRODUCT_NAME}.app"
BUNDLE_ID="com.richardgeorgedavis.google-drive-icon-guard.beta"
MINIMUM_MACOS_VERSION="13.0"
DIST_ROOT="${PROJECT_ROOT}/dist"
BUILD_ROOT="${DIST_ROOT}/build"
APP_ROOT="${DIST_ROOT}/${APP_NAME}"
APP_CONTENTS="${APP_ROOT}/Contents"
APP_MACOS="${APP_CONTENTS}/MacOS"
APP_HELPERS="${APP_CONTENTS}/Helpers"
APP_RESOURCES="${APP_CONTENTS}/Resources"
EXECUTABLE_SOURCE="${PROJECT_ROOT}/.build/release/${EXECUTABLE_PRODUCT}"
EXECUTABLE_DESTINATION="${APP_MACOS}/${PRODUCT_NAME}"
HELPER_EXECUTABLE_SOURCE="${PROJECT_ROOT}/.build/release/${HELPER_EXECUTABLE_PRODUCT}"
HELPER_EXECUTABLE_DESTINATION="${APP_HELPERS}/${HELPER_EXECUTABLE_PRODUCT}"
ZIP_PATH="${DIST_ROOT}/google-drive-icon-guard-beta-unsigned.zip"
ICON_SOURCE="${PROJECT_ROOT}/icon.png"
ICON_BASENAME="AppIcon"
ICONSET_PATH="${BUILD_ROOT}/${ICON_BASENAME}.iconset"
ICON_ICNS_PATH="${APP_RESOURCES}/${ICON_BASENAME}.icns"

echo "Building release executable..."
cd "${PROJECT_ROOT}"
swift build -c release --product "${EXECUTABLE_PRODUCT}"
swift build -c release --product "${HELPER_EXECUTABLE_PRODUCT}"

echo "Preparing app bundle..."
rm -rf "${APP_ROOT}" "${ZIP_PATH}" "${BUILD_ROOT}"
mkdir -p "${APP_MACOS}" "${APP_HELPERS}" "${APP_RESOURCES}" "${BUILD_ROOT}"

cp "${EXECUTABLE_SOURCE}" "${EXECUTABLE_DESTINATION}"
chmod +x "${EXECUTABLE_DESTINATION}"
cp "${HELPER_EXECUTABLE_SOURCE}" "${HELPER_EXECUTABLE_DESTINATION}"
chmod +x "${HELPER_EXECUTABLE_DESTINATION}"

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
  <string>0.1.0-beta</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MINIMUM_MACOS_VERSION}</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

echo "Creating zip archive..."
/usr/bin/ditto -c -k --keepParent "${APP_ROOT}" "${ZIP_PATH}"

echo
echo "Unsigned beta app created:"
echo "  App: ${APP_ROOT}"
echo "  Zip: ${ZIP_PATH}"
echo "  Helper: ${HELPER_EXECUTABLE_DESTINATION}"
echo
echo "Notes:"
echo "  - This beta bundle is unsigned and not notarized."
echo "  - Users may need to bypass Gatekeeper manually on first launch."
