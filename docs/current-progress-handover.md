# Current Progress Handover

This handover captures the **implemented state of the repository as of 2026-03-24**, not just the original product intent.

## Current state

The repo is now a standalone Git repository with:

- a public-facing README
- repo policies for contribution, conduct, support, security, and licensing
- a Swift Package scaffold for scope inventory work
- a working CLI for Google Drive scope discovery
- a lightweight SwiftUI app shell for discovered scopes
- persisted inventory snapshots written to `cache/scope-inventory/latest.json`
- persisted inventory history written to `cache/scope-inventory/history/`
- an app-only beta packaging script for an unsigned downloadable `.app`
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

- the final polished SwiftUI app shell
- the privileged helper/service boundary
- enforcement or remediation behavior
- signed and notarized beta release packaging
- helper/installer packaging in public beta downloads

## Testing and toolchain note

The repo includes a Swift test target and a macOS GitHub Actions workflow.

Local testing can be misleading on machines that use only Apple Command Line Tools. For reliable local Swift test behavior, use full Xcode and point `xcode-select` at it.

## Recommended next steps

1. Add audit-only hidden artefact scanning on top of the current scope inventory.
2. Decide when to sign and notarize public beta builds.
3. Keep the original handover aligned with implementation milestones as the repo evolves.

## Key docs

- [Original project handover](./google-drive-icon-guard-handover.md)
- [Milestone 1 scope discovery notes](./milestone-1-scope-inventory.md)
- [Public launch checklist](./public-launch-checklist.md)
