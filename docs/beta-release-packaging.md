# Beta Release Packaging

This repo now includes a concrete beta packaging path for the current SwiftUI app shell.

## Current beta format

The current beta packaging target is:

- an **unsigned** `.app` bundle
- zipped as a downloadable archive
- built from the `drive-icon-guard-viewer` SwiftUI target
- app-only; no helper or installer is included in the current beta package

This is a practical first beta format, not the final release/distribution model.

## Current assumptions

- minimum macOS version: `13.0`
- current beta status: **unsigned**
- current notarization status: **not notarized**
- current packaging output:
  - `dist/Google Drive Icon Guard.app`
  - `dist/google-drive-icon-guard-beta-unsigned.zip`

## Build the beta package locally

Use:

```bash
./tools/release/build-beta-app.sh
```

What it does:

- builds the release executable with Swift Package Manager
- creates a minimal macOS `.app` bundle
- writes an `Info.plist`
- copies `icon.png` into the bundle resources
- creates a zip archive for distribution

What it does **not** do yet:

- package a privileged helper
- register any installer or service component
- ship the final app + helper architecture described in the handover

## First beta install expectations

Because the app is currently unsigned and not notarized:

- Gatekeeper may warn on first launch
- users may need to right-click and choose `Open`
- this should be documented clearly in any release notes

## Recommended next release improvements

- choose a real bundle identifier/versioning strategy
- decide when to sign the beta app
- decide when to notarize public builds
- add screenshots to the GitHub release notes
- attach the built zip to GitHub Releases

## GitHub workflow

The repo also includes a manual GitHub Actions workflow for building the beta app artifact in CI.
