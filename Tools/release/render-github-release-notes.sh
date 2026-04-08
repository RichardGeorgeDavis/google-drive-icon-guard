#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_ROOT="${PROJECT_ROOT}/dist"
ARCHIVE_BASENAME="${ARCHIVE_BASENAME:-google-drive-icon-guard-beta-release}"
RELEASE_CHANNEL="${RELEASE_CHANNEL:-beta}"
RELEASE_TAG="${RELEASE_TAG:-${RELEASE_CHANNEL}}"
RELEASE_VERSION="${RELEASE_VERSION:-${RELEASE_TAG}}"
RELEASE_NOTES_PATH="${RELEASE_NOTES_PATH:-${DIST_ROOT}/${ARCHIVE_BASENAME}.release-notes.md}"
ZIP_PATH="${DIST_ROOT}/${ARCHIVE_BASENAME}.zip"
CHECKSUM_PATH="${ZIP_PATH}.sha256"
HELPER_STATUS_PATH="${DIST_ROOT}/${ARCHIVE_BASENAME}.helper-status.json"
PROVENANCE_PATH="${DIST_ROOT}/${ARCHIVE_BASENAME}.provenance.json"
SCREENSHOT_RAW_BASE_URL="${SCREENSHOT_RAW_BASE_URL:-}"

for required_file in \
  "${ZIP_PATH}" \
  "${CHECKSUM_PATH}" \
  "${HELPER_STATUS_PATH}" \
  "${PROVENANCE_PATH}"; do
  if [ ! -f "${required_file}" ]; then
    echo "Missing required release artifact: ${required_file}" >&2
    exit 1
  fi
done

read_release_metadata() {
  python3 - <<'PY'
import json
import os
import re

with open(os.environ["PROVENANCE_PATH"], "r", encoding="utf-8") as handle:
    provenance = json.load(handle)

path_pattern = re.compile(r"/(?:Users|home|private|Volumes|var|tmp|opt|Applications|Library|System|usr).*?(?=,|$)")

def sanitize(text: str) -> str:
    return path_pattern.sub("<path>", text)

release_trust = provenance.get("releaseTrust", {})
helper_status = provenance.get("helperStatus", {})
event_source = helper_status.get("eventSourceStatus", {})
installation = helper_status.get("installationStatus", {})

print("codesigned=" + ("yes" if release_trust.get("codesigned") else "no"))
print("notarized=" + ("yes" if release_trust.get("notarized") else "no"))
print("event_source_state=" + event_source.get("state", "unknown"))
print("event_source_detail=" + sanitize(event_source.get("detail", "No helper event-source detail recorded.")))
print("installation_state=" + installation.get("state", "unknown"))
print("installation_detail=" + sanitize(installation.get("detail", "No helper installation detail recorded.")))
PY
}

release_metadata="$(PROVENANCE_PATH="${PROVENANCE_PATH}" read_release_metadata)"
codesigned_state="$(printf '%s\n' "${release_metadata}" | awk -F= '$1 == "codesigned" {print substr($0, index($0, "=") + 1)}')"
notarized_state="$(printf '%s\n' "${release_metadata}" | awk -F= '$1 == "notarized" {print substr($0, index($0, "=") + 1)}')"
event_source_state="$(printf '%s\n' "${release_metadata}" | awk -F= '$1 == "event_source_state" {print substr($0, index($0, "=") + 1)}')"
event_source_detail="$(printf '%s\n' "${release_metadata}" | awk -F= '$1 == "event_source_detail" {print substr($0, index($0, "=") + 1)}')"
installation_state="$(printf '%s\n' "${release_metadata}" | awk -F= '$1 == "installation_state" {print substr($0, index($0, "=") + 1)}')"
installation_detail="$(printf '%s\n' "${release_metadata}" | awk -F= '$1 == "installation_detail" {print substr($0, index($0, "=") + 1)}')"
checksum_value="$(awk '{print $1}' "${CHECKSUM_PATH}")"
checksum_line="${checksum_value}  $(basename "${ZIP_PATH}")"

mkdir -p "$(dirname "${RELEASE_NOTES_PATH}")"

screenshots_section=""
if [ -n "${SCREENSHOT_RAW_BASE_URL}" ]; then
  screenshots_section=$(cat <<EOF
## Preview images

![Dashboard preview](${SCREENSHOT_RAW_BASE_URL}/release-dashboard-preview.png)

![Findings preview](${SCREENSHOT_RAW_BASE_URL}/release-findings-preview.png)

EOF
)
fi

cat > "${RELEASE_NOTES_PATH}" <<EOF
# Google Drive Icon Guard ${RELEASE_VERSION}

${RELEASE_CHANNEL:u} prerelease tag: \`${RELEASE_TAG}\`

## Testing status

This build is intended for tester validation and remains an **active ${RELEASE_CHANNEL} prerelease**.

Current product boundary:

- audit-first Google Drive scope discovery, artefact review, and export
- packaged SwiftUI app bundle plus background LaunchAgent helper path
- no entitlement-backed Endpoint Security host yet, so true closed-app live blocking is still **not** the shipped claim

## What to test

- launch the app and confirm the detected Google Drive-managed scopes look correct
- review the current findings summary and largest scope hotspots
- export findings and confirm the markdown report matches what the UI shows
- if you are specifically testing helper lifecycle behavior, validate install/remove/status only as a beta helper path

## How to report problems

- open a GitHub issue and include the release tag, macOS version, and whether the problem came from the app, helper status, or packaged zip
- attach the helper-status JSON and provenance JSON when the issue is packaging- or helper-related
- do not report the current lack of Endpoint Security-backed closed-app blocking as a regression; that is still an explicit prerelease limit

## Included assets

- \`$(basename "${ZIP_PATH}")\`
- \`$(basename "${CHECKSUM_PATH}")\`
- \`$(basename "${HELPER_STATUS_PATH}")\`
- \`$(basename "${PROVENANCE_PATH}")\`

## Release trust

- Codesigned: ${codesigned_state}
- Notarized: ${notarized_state}

## Helper runtime snapshot

- Event source state: \`${event_source_state}\`
- Event source detail: ${event_source_detail}
- Installation state: \`${installation_state}\`
- Installation detail: ${installation_detail}

## Install notes

- Minimum macOS version: \`13.0\`
- If this build is unsigned or not notarized, Gatekeeper may require right-click -> Open on first launch.
- The current helper path is for beta evaluation. It does not yet represent the final Endpoint Security-backed closed-app prevention architecture.

${screenshots_section}

## Checksum

\`\`\`text
${checksum_line}
\`\`\`
EOF

echo "Release notes written to ${RELEASE_NOTES_PATH}"
