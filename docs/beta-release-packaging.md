# Beta Release Packaging

This repo now includes a concrete beta packaging path for the current SwiftUI app shell.

## Current beta format

The current beta packaging target is:

- an unsigned-by-default `.app` bundle
- an optional signed/notarized archive when release credentials are configured
- zipped as a downloadable archive
- built from the `drive-icon-guard-viewer` SwiftUI target
- bundles a standalone `drive-icon-guard-helper` executable under `Contents/Helpers/`
- packages installer scaffold resources under `Contents/Resources/Installer/`
- emits helper-status and provenance JSON alongside the archive
- does not yet install or register a real helper/service or system extension

This is a practical first beta format, not the final release/distribution model.

## Current assumptions

- minimum macOS version: `13.0`
- current default beta status: **unsigned**
- current default notarization status: **not notarized**
- current packaging output:
  - `dist/Google Drive Icon Guard.app`
  - `dist/google-drive-icon-guard-beta-unsigned.zip`
  - `dist/google-drive-icon-guard-beta-unsigned.zip.sha256`
  - `dist/google-drive-icon-guard-beta-unsigned.helper-status.json`
  - `dist/google-drive-icon-guard-beta-unsigned.provenance.json`
  - `dist/Google Drive Icon Guard.app/Contents/Helpers/drive-icon-guard-helper`
  - `dist/Google Drive Icon Guard.app/Contents/Resources/Installer/ServiceRegistration/`

## Build the beta package locally

Use:

```bash
./Tools/release/build-beta-app.sh
```

Optional hardened release inputs:

```bash
ARCHIVE_BASENAME=google-drive-icon-guard-beta-release
RELEASE_VERSION=0.1.0-beta.2
RELEASE_BUILD_NUMBER=42
CODESIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)"
NOTARYTOOL_PROFILE=google-drive-icon-guard-notary
CMS_SIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)"
./Tools/release/build-beta-app.sh
```

What it does:

- builds the release executable with Swift Package Manager
- builds the standalone helper host executable with Swift Package Manager
- creates a minimal macOS `.app` bundle
- writes an `Info.plist`
- converts `icon.png` into an `.icns` app icon bundle
- places the helper host in `Contents/Helpers/`
- copies installer scaffold resources into `Contents/Resources/Installer/`
- creates a zip archive for distribution
- writes `helper-status` JSON for the packaged helper
- writes a provenance JSON manifest with git/build/checksum metadata
- optionally signs the app/helper and notarizes the bundle when credentials are supplied
- optionally emits a CMS-signed provenance file when `CMS_SIGN_IDENTITY` is supplied

What it does **not** do yet:

- install or register any helper/service component
- ship a real Endpoint Security system extension
- ship the final app + helper architecture described in the handover

## First beta install expectations

Because the default local build is still unsigned and not notarized:

- Gatekeeper may warn on first launch
- users may need to right-click and choose `Open`
- this should be documented clearly in any release notes

## CI and verification lanes

The repo now splits release validation into two lanes:

- `Swift Package CI` runs fast unit coverage everywhere and runs an unsigned packaging smoke build on `main` or manual dispatch
- `Build Beta App` runs the full release packaging lane for beta tags or manual dispatch, including optional signing/notarization/provenance outputs

## Remaining release work outside the repo

- import the real Developer ID certificate into CI or the maintainer keychain
- configure the `notarytool` keychain profile used by the release lane
- decide whether the provenance CMS signature should use the same identity or a dedicated signing identity
- attach the hardened archive plus provenance outputs to GitHub Releases
- add screenshots to the GitHub release notes

## GitHub workflow

The repo now includes:

- a fast Swift Package CI workflow
- a slower beta-package smoke lane for packaging verification
- a release packaging workflow for beta tags/manual runs

The first GitHub Release draft for `v0.1.0-beta.1` already exists, although attaching the hardened release artifacts is still a release-management step.
