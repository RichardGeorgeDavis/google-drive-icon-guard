#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRODUCT_NAME="Google Drive Icon Guard"
ARCHIVE_BASENAME="${ARCHIVE_BASENAME:-google-drive-icon-guard-beta-unsigned}"
APP_PATH="${PROJECT_ROOT}/dist/${PRODUCT_NAME}.app"
ZIP_PATH="${PROJECT_ROOT}/dist/${ARCHIVE_BASENAME}.zip"
CHECKSUM_PATH="${ZIP_PATH}.sha256"
HELPER_PATH="${APP_PATH}/Contents/Helpers/drive-icon-guard-helper"
INFO_PLIST_PATH="${APP_PATH}/Contents/Info.plist"
HELPER_STATUS_PATH="${PROJECT_ROOT}/dist/${ARCHIVE_BASENAME}.helper-status.json"
PROVENANCE_PATH="${PROJECT_ROOT}/dist/${ARCHIVE_BASENAME}.provenance.json"
PROVENANCE_SIGNATURE_PATH="${PROVENANCE_PATH}.cms"

echo "Verifying beta artifacts..."

if [ ! -d "${APP_PATH}" ]; then
  echo "Missing app bundle: ${APP_PATH}" >&2
  exit 1
fi

if [ ! -f "${ZIP_PATH}" ]; then
  echo "Missing zip artifact: ${ZIP_PATH}" >&2
  exit 1
fi

if [ ! -f "${CHECKSUM_PATH}" ]; then
  echo "Missing zip checksum artifact: ${CHECKSUM_PATH}" >&2
  exit 1
fi

if [ ! -x "${HELPER_PATH}" ]; then
  echo "Missing executable helper: ${HELPER_PATH}" >&2
  exit 1
fi

if [ ! -f "${HELPER_STATUS_PATH}" ]; then
  echo "Missing helper status artifact: ${HELPER_STATUS_PATH}" >&2
  exit 1
fi

if [ ! -f "${PROVENANCE_PATH}" ]; then
  echo "Missing provenance artifact: ${PROVENANCE_PATH}" >&2
  exit 1
fi

plutil -lint "${INFO_PLIST_PATH}" >/dev/null
plutil -extract CFBundleIdentifier raw "${INFO_PLIST_PATH}" >/dev/null
plutil -extract CFBundleExecutable raw "${INFO_PLIST_PATH}" >/dev/null

unzip -t "${ZIP_PATH}" >/dev/null
(
  cd "${PROJECT_ROOT}/dist"
  shasum -a 256 -c "$(basename "${CHECKSUM_PATH}")" >/dev/null
)

STATUS_JSON="$("${HELPER_PATH}" --status --json)"

STATUS_JSON="${STATUS_JSON}" HELPER_STATUS_PATH="${HELPER_STATUS_PATH}" python3 - <<'PY'
import json
import os
import sys

try:
    runtime_payload = json.loads(os.environ["STATUS_JSON"])
except Exception as exc:
    print(f"Invalid helper status JSON from helper executable: {exc}", file=sys.stderr)
    raise SystemExit(1)

try:
    with open(os.environ["HELPER_STATUS_PATH"], "r", encoding="utf-8") as handle:
        file_payload = json.load(handle)
except Exception as exc:
    print(f"Invalid helper status JSON artifact: {exc}", file=sys.stderr)
    raise SystemExit(1)

required_keys = ("eventSourceStatus", "installationStatus")
for payload_name, payload in (("runtime", runtime_payload), ("artifact", file_payload)):
    missing = [key for key in required_keys if key not in payload]
    if missing:
        print(
            f"Helper status {payload_name} JSON missing keys: {', '.join(missing)}",
            file=sys.stderr,
        )
        raise SystemExit(1)

if runtime_payload != file_payload:
    print("Helper status artifact does not match helper executable output.", file=sys.stderr)
    raise SystemExit(1)
PY

PROVENANCE_PATH="${PROVENANCE_PATH}" ZIP_PATH="${ZIP_PATH}" CHECKSUM_PATH="${CHECKSUM_PATH}" python3 - <<'PY'
import json
import os
import sys

try:
    with open(os.environ["PROVENANCE_PATH"], "r", encoding="utf-8") as handle:
        payload = json.load(handle)
except Exception as exc:
    print(f"Invalid provenance JSON: {exc}", file=sys.stderr)
    raise SystemExit(1)

required_top_level = ("product", "build", "artifacts", "releaseTrust", "helperStatus")
missing_top_level = [key for key in required_top_level if key not in payload]
if missing_top_level:
    print(
        f"Provenance JSON missing keys: {', '.join(missing_top_level)}",
        file=sys.stderr,
    )
    raise SystemExit(1)

artifacts = payload["artifacts"]
required_artifact_keys = ("zip", "zipSha256", "checksumFile", "helperStatusFile")
missing_artifact_keys = [key for key in required_artifact_keys if key not in artifacts]
if missing_artifact_keys:
    print(
        f"Provenance artifact section missing keys: {', '.join(missing_artifact_keys)}",
        file=sys.stderr,
    )
    raise SystemExit(1)

if artifacts["zip"] != os.environ["ZIP_PATH"]:
    print("Provenance zip path does not match expected artifact.", file=sys.stderr)
    raise SystemExit(1)

if artifacts["checksumFile"] != os.environ["CHECKSUM_PATH"]:
    print("Provenance checksum path does not match expected artifact.", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(payload["releaseTrust"].get("codesigned"), bool):
    print("Provenance releaseTrust.codesigned must be boolean.", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(payload["releaseTrust"].get("notarized"), bool):
    print("Provenance releaseTrust.notarized must be boolean.", file=sys.stderr)
    raise SystemExit(1)
PY

TRUST_DATA="$(
PROVENANCE_PATH="${PROVENANCE_PATH}" CHECKSUM_PATH="${CHECKSUM_PATH}" python3 - <<'PY'
import json
import os
import sys

with open(os.environ["PROVENANCE_PATH"], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

with open(os.environ["CHECKSUM_PATH"], "r", encoding="utf-8") as handle:
    checksum_line = handle.read().strip()

checksum_value = checksum_line.split()[0]
if payload["artifacts"]["zipSha256"] != checksum_value:
    print("Provenance checksum does not match checksum file.", file=sys.stderr)
    raise SystemExit(1)

print("codesigned" if payload["releaseTrust"]["codesigned"] else "unsigned")
print("notarized" if payload["releaseTrust"]["notarized"] else "not-notarized")
PY
)"

CODESIGN_STATE="${TRUST_DATA%%$'\n'*}"
SIGNATURE_STATE="${TRUST_DATA##*$'\n'}"

if [ "${CODESIGN_STATE}" = "codesigned" ]; then
  codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
fi

if [ "${SIGNATURE_STATE}" = "notarized" ]; then
  xcrun stapler validate "${APP_PATH}" >/dev/null
fi

if [ -f "${PROVENANCE_SIGNATURE_PATH}" ]; then
  security cms -D -i "${PROVENANCE_SIGNATURE_PATH}" >/dev/null
fi

file "${HELPER_PATH}" | rg -q "Mach-O"

echo "Artifact verification passed."
echo "  App: ${APP_PATH}"
echo "  Zip: ${ZIP_PATH}"
echo "  Checksum: ${CHECKSUM_PATH}"
echo "  Helper: ${HELPER_PATH}"
echo "  Helper status artifact: ${HELPER_STATUS_PATH}"
echo "  Provenance: ${PROVENANCE_PATH}"

if [ -f "${PROVENANCE_SIGNATURE_PATH}" ]; then
  echo "  Provenance signature: ${PROVENANCE_SIGNATURE_PATH}"
fi
