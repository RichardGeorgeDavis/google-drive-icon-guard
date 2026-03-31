# Beta Release Packaging

This repo now includes a concrete beta packaging path for the current SwiftUI app shell.

## Current beta format

The current beta packaging target is:

- an **unsigned** `.app` bundle
- zipped as a downloadable archive
- built from the `drive-icon-guard-viewer` SwiftUI target
- bundles a standalone `drive-icon-guard-helper` executable under `Contents/Helpers/`
- packages installer scaffold resources under `Contents/Resources/Installer/`
- does not yet install or register a real helper/service or system extension

This is a practical first beta format, not the final release/distribution model.

## Current assumptions

- minimum macOS version: `13.0`
- current beta status: **unsigned**
- current notarization status: **not notarized**
- current packaging output:
  - `dist/Google Drive Icon Guard.app`
  - `dist/google-drive-icon-guard-beta-unsigned.zip`
  - `dist/Google Drive Icon Guard.app/Contents/Helpers/drive-icon-guard-helper`
  - `dist/Google Drive Icon Guard.app/Contents/Resources/Installer/ServiceRegistration/`

## Build the beta package locally

Use:

```bash
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

What it does **not** do yet:

- install or register any helper/service component
- ship a real Endpoint Security system extension
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

That workflow has now been run successfully on `main`, confirming that CI can produce the current unsigned beta archive.

The first GitHub Release draft for `v0.1.0-beta.1` also exists, although attaching the built zip is still a manual release-management step.
