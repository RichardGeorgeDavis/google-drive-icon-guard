#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRODUCT_NAME="Google Drive Icon Guard"
EXECUTABLE_PRODUCT="drive-icon-guard-viewer"
APP_NAME="${PRODUCT_NAME}.app"
BUNDLE_ID="com.richardgeorgedavis.google-drive-icon-guard.beta"
MINIMUM_MACOS_VERSION="13.0"
DIST_ROOT="${PROJECT_ROOT}/dist"
BUILD_ROOT="${DIST_ROOT}/build"
APP_ROOT="${DIST_ROOT}/${APP_NAME}"
APP_CONTENTS="${APP_ROOT}/Contents"
APP_MACOS="${APP_CONTENTS}/MacOS"
APP_RESOURCES="${APP_CONTENTS}/Resources"
EXECUTABLE_SOURCE="${PROJECT_ROOT}/.build/release/${EXECUTABLE_PRODUCT}"
EXECUTABLE_DESTINATION="${APP_MACOS}/${PRODUCT_NAME}"
ZIP_PATH="${DIST_ROOT}/google-drive-icon-guard-beta-unsigned.zip"

echo "Building release executable..."
cd "${PROJECT_ROOT}"
swift build -c release --product "${EXECUTABLE_PRODUCT}"

echo "Preparing app bundle..."
rm -rf "${APP_ROOT}" "${ZIP_PATH}" "${BUILD_ROOT}"
mkdir -p "${APP_MACOS}" "${APP_RESOURCES}" "${BUILD_ROOT}"

cp "${EXECUTABLE_SOURCE}" "${EXECUTABLE_DESTINATION}"
chmod +x "${EXECUTABLE_DESTINATION}"

if [ -f "${PROJECT_ROOT}/icon.png" ]; then
  cp "${PROJECT_ROOT}/icon.png" "${APP_RESOURCES}/icon.png"
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
echo
echo "Notes:"
echo "  - This beta bundle is unsigned and not notarized."
echo "  - Users may need to bypass Gatekeeper manually on first launch."
