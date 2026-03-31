# Google Drive Icon Guard

<img src="icon.png" alt="Google Drive Icon Guard icon" width="128" />

Google Drive Icon Guard is a macOS utility aimed at stopping Google Drive from generating invisible icon files across synced locations.

The current beta does that conservatively for now: it discovers Google Drive-managed locations, scans those scopes in audit-only mode for hidden icon artefacts, and includes the first helper/runtime scaffolding needed before narrow prevention can be turned on safely.

This repository is currently in active development and should be treated as **beta**. The current codebase is still in the inventory and audit stage, not the final app release stage.

## What This App Aims To Be

The intended final release is a downloadable macOS app, not just a source-only CLI.

The release target is a Mac app that can:

- identify Google Drive-managed locations on the machine
- show where Google Drive-generated invisible icon files and related hidden clutter are building up
- measure the scope of that clutter so it becomes visible and actionable
- classify which locations are safe for audit-only handling versus stronger protection
- eventually stop Google Drive from generating or persisting those invisible icon files in supported scopes

Early public releases should be considered beta builds while the discovery, classification, and safety model are proven out.

## Planned Architecture

The intended final product is not just a viewer app.

Planned components:

- a macOS app for inventory, review, settings, and user-facing workflow
- a helper/service boundary for later narrow, process-aware protection work
- installer/setup flow for registering that helper only when the project reaches that stage

The current public beta now bundles a standalone helper host binary plus installer scaffold resources, but it still does **not** ship the final installed helper/service or system-extension registration flow. Live Google-Drive-only blocking remains pending real macOS process-attributed events.

## Beta Release Format

The repo now includes a practical beta packaging path for a downloadable macOS app.

Current beta packaging:

- unsigned `.app` bundle
- zipped beta archive for download
- built from the current SwiftUI app shell
- bundles the viewer plus a standalone helper host binary
- packages helper install-plan scaffold resources
- still no real installed helper/service or system-extension registration flow

Build it locally with:

```bash
./Tools/release/build-beta-app.sh
```

See:

- [Beta release packaging](./docs/beta-release-packaging.md)

## Why This App?

On macOS, hidden files like `Icon\r` and `._*` can quietly multiply when folder icon metadata gets preserved across synced locations. What starts as harmless Finder metadata can turn into thousands of invisible files, wasted storage, and unnecessary sync noise.

This app was built to tackle that problem. On my own Mac, those hidden artefacts grew to **40,000+ files using more than 6 GB** of space. The goal is simple: identify where Google Drive is managing files, surface the hidden icon clutter building up behind the scenes, and ultimately stop Google Drive from repeatedly generating that invisible mess in places where it is safe to do so.

## Current Development Status

The repo is currently centered on **inventory, review, and helper scaffolding**, with live Google-Drive-only blocking still gated behind OS-specific integration.

Right now the codebase can:

- probe common Google Drive macOS config roots
- read DriveFS `root_preference_sqlite.db` for configured My Drive and backup roots
- read per-account DriveFS `mirror_sqlite.db` data to confirm configured roots
- fall back to visible `~/Library/CloudStorage/GoogleDrive*` stream-style scopes when configured My Drive roots are unavailable
- classify scopes by volume kind, filesystem kind, and support status
- scan supported and audit-only scopes for `Icon\r` and `._*` artefacts
- report per-scope match counts, sample paths, and total storage impact
- persist the latest scope snapshot to `cache/scope-inventory/latest.json`
- keep timestamped history snapshots under `cache/scope-inventory/history/`
- show recent snapshots and current-versus-previous history deltas in the viewer
- package a standalone helper host for replay/test protection evaluation
- expose helper runtime/install readiness in the app and helper CLI
- package installer scaffold resources so the build can report `installPlanReady`
- open a lightweight SwiftUI app shell for discovered scopes via `swift run drive-icon-guard-viewer`

It does **not** yet ship a real installed helper, live Endpoint Security event source, or the final Google-Drive-only blocking path.

## Quick Start

```bash
swift build
swift run drive-icon-guard-scope-inventory
swift run drive-icon-guard-viewer
swift run drive-icon-guard-helper --status
swift run drive-icon-guard-helper --help
swift test
```

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

- [Project handover](./docs/google-drive-icon-guard-handover.md)
- [Current progress handover](./docs/current-progress-handover.md)
- [Changelog](./docs/CHANGELOG.md)
- [Beta release packaging](./docs/beta-release-packaging.md)
- [Milestone 1 scope discovery notes](./docs/milestone-1-scope-inventory.md)
- [First-run guidance and troubleshooting](./docs/first-run-and-troubleshooting.md)
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

The current implementation keeps the project honest: inventory first, audit visibility next, helper host plus install scaffolding now, and true Google-Drive-only blocking only after Endpoint Security integration and a real install/runtime path.
