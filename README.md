# Google Drive Icon Guard

Google Drive Icon Guard is a macOS utility project aimed at discovering every Google Drive-managed location on a Mac before attempting any narrow icon artefact protection.

The current repo state is intentionally scoped to **Milestone 1: scope discovery**. It does not include enforcement logic, Finder extension work, or a blind cleanup loop.

## Current repo contents

- [Project handover](./google-drive-icon-guard-handover.md)
- workspace metadata in `.workspace/project.json`
- a Swift Package scaffold for scope inventory probing
- an initial support classifier aligned to the handover's `supported`, `auditOnly`, and `unsupported` model

## Quick start

```bash
swift build
swift run drive-icon-guard-scope-inventory
swift test
```

## What the current scaffold does

- probes for common Google Drive macOS config roots
- reads DriveFS `root_preference_sqlite.db` for configured My Drive and backup roots
- falls back to visible `~/Library/CloudStorage/GoogleDrive*` stream-style scopes when configured My Drive roots are unavailable
- classifies detected scopes by volume kind, filesystem kind, and support status
- emits a JSON report and persists the latest snapshot to `cache/scope-inventory/latest.json`

## What is still pending

- parsing deeper per-account Google Drive config/state beyond the root preference database
- persisting the discovered scope inventory
- adding a SwiftUI control-plane app and privileged helper boundary

## Repo layout

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

The source scaffold stays aligned to the handover: inventory first, audit visibility next, enforcement later.
