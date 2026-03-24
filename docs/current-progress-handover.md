# Current Progress Handover

This handover captures the **implemented state of the repository as of 2026-03-24**, not just the original product intent.

## Current state

The repo is now a standalone Git repository with:

- a public-facing README
- repo policies for contribution, conduct, support, security, and licensing
- a Swift Package scaffold for scope inventory work
- a working CLI for Google Drive scope discovery
- persisted inventory snapshots written to `cache/scope-inventory/latest.json`
- GitHub issue templates and a public launch checklist

The project is still in **beta / active development**. It is not yet the final downloadable app release.

## What is implemented

### Scope discovery

The current implementation can:

- discover common DriveFS config locations on macOS
- read DriveFS `root_preference_sqlite.db`
- identify configured My Drive and backup roots from that database
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

This output is ignored by Git and intended as repo-local generated state.

## What is not implemented yet

- the final SwiftUI app
- the privileged helper/service boundary
- enforcement or remediation behavior
- deeper parsing of per-account DriveFS settings beyond root preferences
- inventory history beyond the latest persisted snapshot
- app packaging for a downloadable beta release

## Testing and toolchain note

The repo includes a Swift test target and a macOS GitHub Actions workflow.

Local testing can be misleading if the machine uses only Apple Command Line Tools. For reliable local Swift test behavior, use full Xcode and point `xcode-select` at it.

## Recommended next steps

1. Parse deeper DriveFS account settings beyond root preferences.
2. Add a SwiftUI inventory viewer for discovered scopes.
3. Persist inventory history instead of only `latest.json`.
4. Add release packaging for a downloadable macOS beta.
5. Keep the original handover aligned with implementation milestones as the repo evolves.

## Key docs

- [Original project handover](./google-drive-icon-guard-handover.md)
- [Milestone 1 scope discovery notes](./milestone-1-scope-inventory.md)
- [Public launch checklist](./public-launch-checklist.md)
