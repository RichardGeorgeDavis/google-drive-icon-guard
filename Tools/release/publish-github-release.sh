#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_ROOT="${PROJECT_ROOT}/dist"
ARCHIVE_BASENAME="${ARCHIVE_BASENAME:-google-drive-icon-guard-beta-release}"
RELEASE_CHANNEL="${RELEASE_CHANNEL:-beta}"
RELEASE_TAG="${RELEASE_TAG:?RELEASE_TAG is required.}"
RELEASE_VERSION="${RELEASE_VERSION:-${RELEASE_TAG}}"
RELEASE_TITLE="${RELEASE_TITLE:-Google Drive Icon Guard ${RELEASE_VERSION}}"
RELEASE_TARGET="${RELEASE_TARGET:-$(git -C "${PROJECT_ROOT}" rev-parse HEAD)}"
RELEASE_NOTES_PATH="${RELEASE_NOTES_PATH:-${DIST_ROOT}/${ARCHIVE_BASENAME}.release-notes.md}"
RELEASE_DRAFT="${RELEASE_DRAFT:-false}"
RELEASE_PRERELEASE="${RELEASE_PRERELEASE:-true}"
DRY_RUN="${DRY_RUN:-false}"

if [ -z "${GH_REPOSITORY:-}" ]; then
  echo "GH_REPOSITORY is required." >&2
  exit 1
fi

assets=(
  "${DIST_ROOT}/${ARCHIVE_BASENAME}.zip"
  "${DIST_ROOT}/${ARCHIVE_BASENAME}.zip.sha256"
  "${DIST_ROOT}/${ARCHIVE_BASENAME}.helper-status.json"
  "${DIST_ROOT}/${ARCHIVE_BASENAME}.provenance.json"
)

optional_asset="${DIST_ROOT}/${ARCHIVE_BASENAME}.provenance.json.cms"
if [ -f "${optional_asset}" ]; then
  assets+=("${optional_asset}")
fi

for asset in "${assets[@]}" "${RELEASE_NOTES_PATH}"; do
  if [ ! -f "${asset}" ]; then
    echo "Missing required release file: ${asset}" >&2
    exit 1
  fi
done

build_payload() {
  RELEASE_TAG="${RELEASE_TAG}" \
  RELEASE_TARGET="${RELEASE_TARGET}" \
  RELEASE_TITLE="${RELEASE_TITLE}" \
  RELEASE_NOTES_PATH="${RELEASE_NOTES_PATH}" \
  RELEASE_DRAFT="${RELEASE_DRAFT}" \
  RELEASE_PRERELEASE="${RELEASE_PRERELEASE}" \
  python3 - <<'PY'
import json
import os

with open(os.environ["RELEASE_NOTES_PATH"], "r", encoding="utf-8") as handle:
    notes = handle.read()

payload = {
    "tag_name": os.environ["RELEASE_TAG"],
    "target_commitish": os.environ["RELEASE_TARGET"],
    "name": os.environ["RELEASE_TITLE"],
    "body": notes,
    "draft": os.environ["RELEASE_DRAFT"].lower() == "true",
    "prerelease": os.environ["RELEASE_PRERELEASE"].lower() == "true",
    "generate_release_notes": False,
}

print(json.dumps(payload))
PY
}

payload="$(build_payload)"
api_root="repos/${GH_REPOSITORY}/releases"

if [ "${DRY_RUN}" = "true" ]; then
  echo "Dry run: would create or update release ${RELEASE_TAG} (${RELEASE_CHANNEL}) targeting ${RELEASE_TARGET}"
  printf 'Dry run assets:\n'
  printf '  %s\n' "${assets[@]}"
  exit 0
fi

existing_release_id="$(
  gh api \
    -H "Accept: application/vnd.github+json" \
    "${api_root}/tags/${RELEASE_TAG}" \
    --jq .id 2>/dev/null || true
)"

if [ -n "${existing_release_id}" ]; then
  release_url="$(
    printf '%s' "${payload}" | gh api \
      --method PATCH \
      -H "Accept: application/vnd.github+json" \
      "${api_root}/${existing_release_id}" \
      --input - \
      --jq .html_url
  )"
else
  release_url="$(
    printf '%s' "${payload}" | gh api \
      --method POST \
      -H "Accept: application/vnd.github+json" \
      "${api_root}" \
      --input - \
      --jq .html_url
  )"
fi

gh release upload "${RELEASE_TAG}" "${assets[@]}" --clobber

echo "GitHub prerelease ready: ${release_url}"
