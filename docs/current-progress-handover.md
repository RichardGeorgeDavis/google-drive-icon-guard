# Current Progress Handover

This handover captures the **implemented state of the repository as of 2026-04-01**, not just the original product intent.

## Current state

The repo is now a standalone Git repository with:

- a public-facing README
- repo policies for contribution, conduct, support, security, and licensing
- a Swift Package scaffold for scope inventory work
- a working CLI for Google Drive scope discovery
- a lightweight SwiftUI app shell for discovered scopes
- persisted inventory snapshots written to `cache/scope-inventory/latest.json`
- persisted inventory history written to `cache/scope-inventory/history/`
- a beta packaging script for an unsigned downloadable `.app`
- a bundled standalone helper host executable for replay/test protection evaluation
- packaged installer scaffold resources for future helper/system-extension registration
- a manual GitHub Actions workflow for building the beta app archive
- a verified GitHub Actions beta packaging run on `main`
- a saved GitHub Release draft for `v0.1.0-beta.1`
- GitHub issue templates and a public launch checklist

The project is still in **beta / active development**. It is not yet the final downloadable app release.

## What is implemented

### Scope discovery

The current implementation can:

- discover common DriveFS config locations on macOS
- read DriveFS `root_preference_sqlite.db`
- read per-account DriveFS `mirror_sqlite.db`
- identify configured My Drive and backup roots from that database
- confirm configured roots against per-account DriveFS root records
- fall back to visible `~/Library/CloudStorage/GoogleDrive*` locations when needed
- scan supported and audit-only scopes for `Icon\r` and `._*` hidden artefacts
- capture per-scope artefact counts, sample paths, and total storage impact
- show recent persisted snapshots plus current-versus-previous deltas in the viewer
- package and run a standalone helper host against replayed process-attributed events
- report helper readiness as unavailable/bundled/needs-approval instead of implying live blocking is already active
- package installer scaffold resources so the app can distinguish `bundled only` from `install plan ready`
- expose helper runtime and install-plan readiness through the packaged helper CLI
- classify each discovered scope by:
  - drive mode
  - scope kind
  - volume kind
  - filesystem kind
  - support status

### Current real-world output

On the maintainer machine used during implementation, the CLI successfully discovered:

- `Desktop`
- `Documents`
- `Downloads`
- mirrored My Drive at `/Volumes/Sync/G Drive`

That proves the current code is already reading meaningful DriveFS state rather than only returning placeholder output.

### Persistence

The CLI now writes the latest inventory snapshot to:

```text
cache/scope-inventory/latest.json
```

It also writes timestamped history snapshots to:

```text
cache/scope-inventory/history/
```

These outputs are ignored by Git and intended as repo-local generated state.

## What is not implemented yet

- the final installed helper/service boundary
- real process-attributed event capture via macOS Endpoint Security
- signed and notarized beta release packaging
- real installer packaging and registration for public beta downloads

## Testing and toolchain note

The repo includes a Swift test target and a macOS GitHub Actions workflow.

Local testing can be misleading on machines that use only Apple Command Line Tools. For reliable local Swift test behavior, use full Xcode and point `xcode-select` at it.

## Recommended next steps

1. Replace replay-only helper input with a real Endpoint Security event source and system-extension packaging.
2. Decide when to sign and notarize public beta builds.
3. Turn the current install scaffold into a real helper/system-extension registration flow.

## Key docs

- [Original project handover](./google-drive-icon-guard-handover.md)
- [Milestone 1 scope discovery notes](./milestone-1-scope-inventory.md)
- [Public launch checklist](./public-launch-checklist.md)
