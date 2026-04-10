# Google Drive Icon Guard

<img src="icon.png" alt="Google Drive Icon Guard icon" width="128" />

Google Drive Icon Guard is a macOS utility aimed at stopping Google Drive from generating invisible icon files across synced locations.

Today it does that conservatively: it discovers Google Drive-managed locations, scans those scopes in audit-only mode for hidden icon artefacts, and includes the helper/runtime scaffolding needed before narrower protection can be turned on safely.

This repository is in active development and should be treated as **beta**. The current codebase is still in the inventory, cleanup, and helper-readiness stage, not the final prevention release stage.

If you found this repo while searching for a fix for Google Drive hidden files on Mac, that is the right problem space. This project is specifically about Google Drive for desktop on macOS creating or preserving invisible Finder icon artefacts such as `Icon\r` and `._*`, but the current public build is still a beta diagnostic and audit tool rather than a finished one-click fix.

## Current Ask

The main blocker to real closed-app blocking is the Apple platform lane around Endpoint Security, not basic app scaffolding.

This project is actively looking for help with:

- access to a paid Apple Developer Program team
- sponsorship or approval help for `com.apple.developer.endpoint-security.client`
- help setting up the signed macOS host app plus system extension target in Xcode
- real-Mac validation of the signed build and system-extension approval flow

Start here:

- [Help Wanted](./docs/help-wanted.md)
- [Open issues](https://github.com/RichardGeorgeDavis/google-drive-icon-guard/issues)
- [Support](./.github/SUPPORT.md)

## What Works Today

- discovers Google Drive-managed locations on the Mac
- scans supported and audit-only scopes for `Icon\r` and `._*`
- shows scope details, history, recent activity, and helper readiness in the app
- installs, refreshes, updates, and removes the background LaunchAgent helper
- exports support diagnostics and inventory reports
- publishes alpha/beta prereleases through GitHub Releases

## What Is Blocked

It does **not** yet ship the real Endpoint Security host target, approved entitlement path, or final Google-Drive-only live blocking path needed for true closed-app prevention.

Without that Apple Developer Program and entitlement lane, the project can continue as an audit, cleanup, and background-helper beta, but it cannot truthfully ship real Google-Drive-only closed-app blocking.

## Ways To Help

- Apple platform sponsorship or entitlement help: [Help Wanted](./docs/help-wanted.md)
- Xcode/system-extension architecture help: [Architecture](./docs/architecture.md)
- packaged-build validation and tester feedback: [First-run guidance and troubleshooting](./docs/first-run-and-troubleshooting.md)
- alternative approaches without Endpoint Security (and trade-offs): [Non-Endpoint-Security alternatives](./docs/non-endpoint-security-alternatives.md)
- normal repo contributions: [Contributing](./.github/CONTRIBUTING.md)

## Preview

Representative app captures from the current beta build:

![Dashboard Preview](./docs/images/readme-hero-dashboard.png)

![Live Protection Preview](./docs/images/support-helper-panel.png)

[Full App Screenshot](./docs/images/app-full-screenshot.png)

## Quick Start

```bash
swift build
swift run drive-icon-guard-scope-inventory
swift run drive-icon-guard-viewer
swift run drive-icon-guard-helper --status
swift run drive-icon-guard-helper --help
swift test
```

For a packaged local app build:

```bash
./Tools/release/build-beta-app.sh
```

## Why This Exists

On macOS, hidden files like `Icon\r` and `._*` can quietly multiply when folder icon metadata gets preserved across synced locations. What starts as harmless Finder metadata can turn into thousands of invisible files, wasted storage, and unnecessary sync noise.

This app was built to tackle that problem. On my own Mac, those hidden artefacts grew to **40,000+ files using more than 6 GB** of space. The goal is simple: identify where Google Drive is managing files, surface the hidden icon clutter building up behind the scenes, and ultimately stop Google Drive from repeatedly generating that invisible mess in places where it is safe to do so.

In practical terms, this repo is for people dealing with symptoms such as:

- Google Drive for desktop creating invisible files on macOS
- repeated `Icon\r` files inside synced folders
- `._*` AppleDouble sidecar files multiplying in Google Drive locations
- Finder folder icon metadata leaking into mirrored or backup roots
- sync noise, storage bloat, or cleanup churn caused by hidden icon artefacts

## Common Search Symptoms

People usually land here while searching for things like:

- `google drive hidden files mac`
- `google drive creates icon files on mac`
- `Icon\\r files google drive`
- `._ files google drive mac`
- `google drive invisible files finder metadata`
- `google drive folder icons syncing to external drive`
- `mac google drive keeps creating hidden icon files`

This repo is intended to help with that class of problem by making the affected Google Drive-managed locations visible, measuring the artefacts, and preparing for narrower prevention in supported scopes.

## Test Builds

Alpha and beta tester builds can now be published directly through GitHub Releases with the packaged zip, checksum, helper-status JSON, and provenance JSON attached to the release entry.

Those releases should still be treated as prereleases. Even when the packaging lane is green, the shipped claim remains audit-first until the entitlement-backed Endpoint Security host lane exists.

Optional release-hardening inputs:

```bash
CODESIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)"
NOTARYTOOL_PROFILE="google-drive-icon-guard-notary"
CMS_SIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)"
./Tools/release/build-beta-app.sh
```

See:

- [Beta release packaging](./docs/beta-release-packaging.md)

## Testing

The test target in this repo runs real assertions when a full Xcode toolchain is available.

If a contributor is using only Apple Command Line Tools, `swift test` may degrade into a build-only pass because Apple does not expose the usual Swift test frameworks in that setup.

To fix that locally:

1. Install full Xcode.
2. Point the active developer directory at Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

3. Verify the toolchain:

```bash
xcode-select -p
swift --version
swift test
```

This machine is now using full Xcode successfully, and the repo also includes a macOS GitHub Actions workflow so CI runs against a full Apple toolchain instead of Command Line Tools alone.

## Project Docs

- [Current state](./docs/current-state.md)
- [Roadmap](./docs/roadmap.md)
- [Architecture](./docs/architecture.md)
- [Help wanted](./docs/help-wanted.md)
- [Changelog](./docs/CHANGELOG.md)
- [Development setup](./docs/development-setup.md)
- [Beta release packaging](./docs/beta-release-packaging.md)
- [Milestone 1 scope discovery notes](./docs/milestone-1-scope-inventory.md)
- [First-run guidance and troubleshooting](./docs/first-run-and-troubleshooting.md)
- [Current progress handover](./docs/current-progress-handover.md)
- [Public launch checklist](./docs/public-launch-checklist.md)
- [Code of Conduct](./.github/CODE_OF_CONDUCT.md)
- [Contributing](./.github/CONTRIBUTING.md)
- [Security Policy](./.github/SECURITY.md)
- [Support](./.github/SUPPORT.md)
- [MIT License](./LICENSE)

## Repo Layout

```text
google-drive-icon-guard/
├── App/
│   ├── ScopeInventory/
│   ├── UI/
│   ├── Logs/
│   ├── Settings/
│   └── XPCClient/
├── Helper/
├── RuntimeHostSupport/
├── Shared/
│   ├── Models/
│   ├── IPC/
│   └── Utilities/
├── Installer/
├── Tools/
│   ├── ProtectionHelperCLI/
│   └── ScopeInventoryCLI/
└── Tests/
```

The current implementation keeps the project honest: inventory first, audit visibility next, helper host plus install scaffolding now, and true Google-Drive-only blocking only after Endpoint Security integration and a real signed runtime path.
