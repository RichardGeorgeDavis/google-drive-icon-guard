# Current Progress Handover

This handover captures the **implemented state of the repository as of 2026-04-07**, not just the original product intent.

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
- CI + beta workflow caching, concurrency controls, and timeout guards
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
- emit typed protection remediation status over shared IPC contracts
- centralize default protection status construction through shared `ProtectionStatusFactory`
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
- live process-attributed event capture via macOS Endpoint Security in an Xcode-linked runtime lane
- signed and notarized beta release packaging
- real installer packaging and registration for public beta downloads

## Recently completed optimization work

- CI pipeline now restores SwiftPM/build caches and cancels superseded runs.
- beta build workflow now enforces timeout guards and uploads diagnostics on failure.
- beta packaging now emits and verifies zip checksums and validates app/plist/zip/helper metadata.
- monitor scheduling now uses adaptive backoff with jitter and scope-change-triggered reevaluation.
- refresh flow now coalesces duplicate refresh requests to avoid repeated UI-side orchestration bursts.
- activity-log updates now avoid unnecessary reloads when an in-memory log is already available.
- remediation path handling now includes canonicalized-root validation and in-scope path revalidation before deletion.
- process classification now prioritizes signer/team-id and known Google bundle identifiers before heuristic fallback.
- deterministic regression tests were added for monitor cooldown/stop behavior and mapper edge handling.

## Current blocker for live Endpoint Security

- the repo builds and tests through SwiftPM, but live Endpoint Security activation (`es_new_client`/`es_subscribe`) requires:
  - an Xcode app/system-extension target that links `EndpointSecurity.framework`
  - approved `com.apple.developer.endpoint-security.client` entitlement
  - signing/provisioning and user approval path on-device
- integration guide and template are now in-repo:
  - `docs/endpoint-security-xcode-integration.md`
  - `Installer/EndpointSecurity/entitlements.example.plist`
- additional implementation note:
  - callback extraction now assembles create/rename new-path values using directory + filename and should be validated against real ES callback payloads in the Xcode runtime lane.

## Testing and toolchain note

The repo includes a Swift test target and a macOS GitHub Actions workflow.

Local testing can be misleading on machines that use only Apple Command Line Tools. For reliable local Swift test behavior, use full Xcode and point `xcode-select` at it.

## Recommended next steps

1. Replace replay-only helper input with a real Endpoint Security event source and system-extension packaging.
2. Decide when to sign and notarize public beta builds.
3. Turn the current install scaffold into a real helper/system-extension registration flow.

## Planned next-step execution (handover-ready)

### Phase 1: stabilize live path

- finalize Xcode runtime lane for Endpoint Security callback ingestion
- validate create/rename/unlink path extraction under real ES events
- keep beta audit-only guard enabled until live-path confidence criteria pass

### Phase 2: performance and reliability

- implement background refresh coordinator to minimize UI-thread work
- split test/CI lanes into fast unit and slower integration coverage
- instrument refresh, monitor, and remediation timings with repeatable baseline metrics

### Phase 3: security and release trust

- enforce authenticated app-helper boundary (caller verification + authorization)
- complete install lifecycle state machine with verified `installed`/`error` states
- add signed beta release lane (codesign, notarization, signed checksums, provenance)

### Phase 4: expansion

- add policy profiles and per-scope overrides
- add operator readiness/troubleshooting workflow views
- define provider adapter model for future non-Google Drive scope support

## Known gaps from latest review

- Review source: Cursor -> Codex review handoff item (plan/implementation gap review).
- **Resolved in follow-up:** beta runtime now enforces audit-only behavior by normalizing `blockKnownArtefacts` to `auditOnly` in embedded configuration.
- **Resolved in follow-up:** embedded/dev path status semantics were tightened to avoid reporting event source `ready` before real ES-backed monitoring exists.
- **Resolved in follow-up:** inventory refresh activity logging now records the latest persisted snapshot path directly.
- **Test coverage note:** `swift test` is green, and regression tests now cover beta enforcement coercion plus non-`ready` embedded event-source status.

## Review follow-up status (Cursor -> Codex)

The first follow-up pass for the Cursor -> Codex review item is complete:

- embedded beta runtime now normalizes `blockKnownArtefacts` to `auditOnly`, preventing unintended auto-enforcement in current beta paths
- embedded status semantics now avoid reporting event source `ready` in dev/test path (uses `bundled`)
- inventory refresh activity logging now records the latest persisted snapshot path directly
- latest validation rerun is green (`swift test`: 49 passing)

## Key docs

- [Original project handover](./google-drive-icon-guard-handover.md)
- [Milestone 1 scope discovery notes](./milestone-1-scope-inventory.md)
- [Public launch checklist](./public-launch-checklist.md)
- [Protection status transitions](./protection-status-state-transitions.md)
- [Codex handover 2026-04-07](./codex-handover-2026-04-07.md)
- [Next steps roadmap](./next-steps-roadmap.md)
- [Endpoint Security Xcode integration](./endpoint-security-xcode-integration.md)
