# Google Drive Icon Guard

Google Drive Icon Guard is a macOS utility focused on discovering Google Drive-managed locations, surfacing hidden icon artefacts, and eventually helping users control that sync noise safely.

This repository is currently in active development and should be treated as **beta**. The current codebase is still in the inventory and audit stage, not the final app release stage.

## What This App Aims To Be

The intended final release is a downloadable macOS app, not just a source-only CLI.

The release target is a Mac app that can:

- identify Google Drive-managed locations on the machine
- show where icon-related hidden clutter is building up
- measure the scope of that clutter so it becomes visible and actionable
- classify which locations are safe for audit-only handling versus stronger protection
- eventually provide narrow remediation or protection in supported scopes

Early public releases should be considered beta builds while the discovery, classification, and safety model are proven out.

## Why This App?

On macOS, hidden files like `Icon\r` and `._*` can quietly multiply when folder icon metadata gets preserved across synced locations. What starts as harmless Finder metadata can turn into thousands of invisible files, wasted storage, and unnecessary sync noise.

This app was built to tackle that problem. On my own Mac, those hidden artefacts grew to **40,000+ files using more than 6 GB** of space. The goal is simple: identify where Google Drive is managing files, surface the hidden icon clutter building up behind the scenes, and help make that invisible mess visible, measurable, and manageable.

## Current Development Status

The repo is currently centered on **Milestone 1: scope discovery**.

Right now the codebase can:

- probe common Google Drive macOS config roots
- read DriveFS `root_preference_sqlite.db` for configured My Drive and backup roots
- fall back to visible `~/Library/CloudStorage/GoogleDrive*` stream-style scopes when configured My Drive roots are unavailable
- classify scopes by volume kind, filesystem kind, and support status
- persist the latest scope snapshot to `cache/scope-inventory/latest.json`
- open a minimal SwiftUI viewer for discovered scopes via `swift run drive-icon-guard-viewer`

It does **not** yet ship the final full app shell, privileged helper, or end-user remediation flow.

## Quick Start

```bash
swift build
swift run drive-icon-guard-scope-inventory
swift run drive-icon-guard-viewer
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
│   └── ScopeInventoryCLI/
└── Tests/
```

The current implementation keeps the project honest: inventory first, audit visibility next, enforcement later.
