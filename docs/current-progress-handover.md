# Current Progress Handover

This handover captures the **implemented state of the repository as of 2026-04-08**, not just the original product intent.

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
- a runtime-support library for Xcode-hosted Endpoint Security session wiring
- receipt-backed install-state verification for `installed` and `error`
- typed authorization primitives for future helper-bound commands
- release packaging support for optional codesign, notarization, and stapling
- machine-readable helper-status and provenance release artifacts
- generated GitHub release notes derived from the packaged artifacts
- a manual GitHub Actions workflow for building the beta app archive
- a GitHub Actions publication path that can create or update alpha/beta prereleases and attach the packaged assets directly to GitHub Releases
- CI split into fast unit coverage plus slower packaging smoke/release lanes
- a verified GitHub Actions beta packaging run on `main`
- a saved GitHub Release draft for `v0.1.0-beta.1`
- GitHub issue templates and a public launch checklist
- app-managed helper LaunchAgent bootstrap/bootout/status lifecycle support via the packaged helper CLI and deployment coordinator
- app-managed helper LaunchAgent install/start/remove/status controls in the SwiftUI app
- persisted helper protection configuration for the installed helper path
- automatic app-side switch to the named Mach-service helper boundary when the background helper is loaded
- finite-timeout XPC handling so a stale or unreachable installed helper does not hang the app UI
- recoverable helper install handling when `launchctl bootstrap` reports an error but the LaunchAgent is already loaded and reusable
- a custom About window with copied diagnostics, GitHub issue links, release/build trust state, and helper lifecycle details
- main-screen build/support diagnostics, stronger Live Protection error callouts, and direct support actions from the dashboard
- real shipped-app screenshots wired into the README, support docs, and generated GitHub release notes
- dedicated History and Logs views backed by persisted snapshot comparison and activity-log state

The project is still in **beta / active development**. It is not yet the final downloadable app release.

## Latest validated state

The latest local validation rerun on **2026-04-08** is green:

- `swift build --product drive-icon-guard-viewer`
- `swift build --product drive-icon-guard-helper`
- `swift test`
- `./Tools/release/build-beta-app.sh`
- current full suite size at handoff: `83` passing tests

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
- install, refresh, and remove the LaunchAgent helper path directly from the app UI
- persist helper protection configuration in Application Support for the installed helper path
- reconnect the app to the installed helper over the named Mach-service NSXPC boundary when that helper is loaded
- allow the protected helper boundary to accept a pluggable runtime controller instead of only the bare helper service
- surface runtime-start failure through boundary status and command outcomes
- deliver helper/runtime evaluations asynchronously so synchronous startup callbacks do not deadlock the endpoint queue
- time out and fall back cleanly when launchd says the helper is loaded but the Mach service is stale or unreachable
- treat already-loaded LaunchAgent helper reuse as an installed state instead of a false hard install error
- emit typed protection remediation status over shared IPC contracts
- centralize default protection status construction through shared `ProtectionStatusFactory`
- expose copied support diagnostics, release/build metadata, and GitHub issue links from both the About window and the main app surface
- present persisted snapshot history and operational activity logs as first-class views in the app
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
- real installer packaging and registration for public beta downloads

Signed/notarized packaging is now supported by the repo tooling, but the real Apple credentials and notary profile still need to be provisioned and validated in the actual release environment.

## New Batch 4 boundary/install support now in repo

- added `ProtectionInstallationReceiptLocator` so the client can elevate install state from scaffold-only to verified `installed` / `error`
- added `ProtectionServiceAuthorizer` and typed command/caller models for future helper-bound method authorization
- added `ProtectionInstallationStatusResolver`, `LocalProtectionServiceEndpoint`, and `BoundaryProtectionServiceClient` so the repo now exercises a protected helper/service boundary in-process
- added `ProtectionXPCListenerHost` and `XPCProtectionServiceClient` so the same boundary now runs over an anonymous NSXPC listener/client path inside SwiftPM
- added `ProtectionServiceInstaller` plus launch-agent receipt/plan support so the repo now writes concrete helper registration artefacts and can target a named Mach service
- added `ProtectionServiceLaunchdManager` and `ProtectionServiceDeploymentCoordinator` so the repo now bootstraps, kickstarts, inspects, and boots out that LaunchAgent registration
- added regression tests for:
  - valid installed receipt
  - mismatched or malformed receipts mapping to `error`
  - high-risk command authorization requirements
  - trusted installed helper-bound command flow
  - install-state and validation rejection in the protected endpoint
  - trusted installed NSXPC client flow
  - NSXPC untrusted-caller and install-state rejection
  - launch-agent/receipt install and uninstall flow
  - application-support receipt discovery
  - launchctl bootstrap/kickstart/status and bootstrap-failure receipt handling
  - launchctl bootout plus registration-file removal

This is now beyond anonymous test IPC. The repo can write launch-agent registration and installer-driven receipts, bootstrap that registration with `launchctl`, inspect the service state, boot it out again, run the helper as a named Mach-service host, and drive that lifecycle from the app UI. What still remains is signed deployment, clean-machine packaged validation, final caller-identity validation in the deployed environment, and the real Endpoint Security host/entitlement lane.

## New Batch 5 release-hardening support now in repo

- `build-beta-app.sh` now supports optional:
  - codesign for the app bundle and helper
  - notarization submission + stapling
  - CMS signing for the provenance manifest
- release builds now emit:
  - zip checksum
  - helper-status JSON
  - provenance JSON with build/ref/checksum metadata
- the release workflow now renders release notes from the generated artifacts and can publish them alongside the packaged assets to a GitHub prerelease entry
- artifact verification now validates:
  - checksum correctness
  - helper-status JSON consistency
  - provenance structure
  - codesign and stapling when the release metadata says they should exist
- CI is now split into:
  - fast unit-test coverage
  - slower packaging smoke verification
  - tag/manual beta release packaging

This completes the repo-side work for Batch 5 publication plumbing. The remaining release blocker is operational setup outside the repo: real Apple signing material, a working notary profile, and tester-facing screenshots/polish.

Subsequent repo work also refreshed the shipped-doc surface around that release lane:

- README now uses real app captures instead of generated mock preview images
- first-run/support docs now include actual app screenshots
- the custom About window and dashboard support actions make tester issue filing materially easier
- existing alpha/beta prerelease entries should be refreshed when these UI/support changes are pushed

## New runtime-lane support now in repo

- added `DriveIconGuardRuntimeSupport` as the package-side runtime lane support library
- added `EndpointSecurityRuntimeCoordinator` to combine:
  - helper policy evaluation
  - `EndpointSecurityProcessAttributedEventSubscriber`
  - live Endpoint Security session start/stop wiring
- added a shared runtime-controller contract so `LocalProtectionServiceEndpoint` and `ProtectionXPCListenerHost` can consume the live runtime coordinator without rewriting the protected helper boundary
- implemented `SystemEndpointSecurityLiveMonitoringSession` using dynamic framework loading so SwiftPM can compile the runtime lane support without directly linking `EndpointSecurity.framework`
- added regression tests for:
  - runtime session start success
  - runtime session start failure
  - live callback forwarding into policy evaluation
  - protected-endpoint runtime-start failure surfacing
  - synchronous startup callback delivery without deadlocking the endpoint queue

This is still not the final signed host target. It is the repo-side runtime support that the future Xcode app/system-extension lane should consume.

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
- what remains for a true live lane is outside SwiftPM alone:
  - an actual signed Xcode app or system extension target
  - the `com.apple.developer.endpoint-security.client` entitlement
  - on-device approval
- the repo now has the runtime code that host should consume
- the repo-side helper boundary can now consume that runtime coordinator directly once the signed Xcode host target exists
- integration guide and template are now in-repo:
  - `docs/endpoint-security-xcode-integration.md`
  - `Installer/EndpointSecurity/entitlements.example.plist`
- additional implementation note:
  - callback extraction now assembles create/rename new-path values using directory + filename and should be validated against real ES callback payloads in the Xcode runtime lane.

## Proper beta MVP from here

If the beta promise is limited to audit, review, export, cleanup preview, and a background helper install path, the repo is close.

If the beta promise is true Google-Drive-only prevention while the app is closed, the must-have next step is the real Endpoint Security host lane.

Must-have before that stronger beta claim:

- an Xcode app or system-extension host target that links `EndpointSecurity.framework`
- approved `com.apple.developer.endpoint-security.client` entitlement and signing/provisioning
- live `es_new_client` / `es_subscribe` callback flow verified against real traffic
- confirmation that the installed helper can stay armed through the real closed-app path rather than the current preflight/runtime-placeholder event source

Still important, but secondary to that host-lane work:

- real Apple signing/notary credentials in CI
- clean-machine packaged install/bootstrap/reconnect validation
- screenshots and public beta notes that match the shipped behavior exactly
- helper version/update detection so stale installed helpers can be upgraded explicitly rather than only reinstalled generically
- clearer operator logs/history filtering plus a compact recent-activity summary on the main screen
- a top-level cleanup action that aggregates supported findings once the cleanup UX is finalized

## Testing and toolchain note

The repo includes a Swift test target and a macOS GitHub Actions workflow.

Local testing can be misleading on machines that use only Apple Command Line Tools. For reliable local Swift test behavior, use full Xcode and point `xcode-select` at it.

## Recommended next steps

1. Finish the Xcode host/entitlement lane for real Endpoint Security callback traffic.
2. Validate the packaged app + installed helper path on a clean machine after that live lane is in place.
3. Provision and validate the real Apple signing/notary credentials used by the hardened release lane.
4. Add helper version drift detection and an explicit `Update Helper` path.
5. Tighten history/log UX and add a top-level cleanup action for supported findings.

## Planned next-step execution (handover-ready)

### Phase 1: Endpoint Security host and live path

- create or adopt the Xcode app/system-extension host target
- link `EndpointSecurity.framework` and attach the approved entitlement/profile
- finalize Xcode runtime lane for Endpoint Security callback ingestion
- validate create/rename/unlink path extraction under real ES events
- prove end-to-end callback delivery into the installed helper boundary
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

The repo-side follow-up passes for the Cursor -> Codex review item are complete:

- embedded beta runtime now normalizes `blockKnownArtefacts` to `auditOnly`, preventing unintended auto-enforcement in current beta paths
- embedded status semantics now avoid reporting event source `ready` in dev/test path (uses `bundled`)
- inventory refresh activity logging now records the latest persisted snapshot path directly
- monitor shutdown now prevents post-stop cleanup work
- release artifact verification now passes end-to-end
- ES subscriber runtime entrypoints and docs are aligned
- protected helper boundary now accepts the future live runtime coordinator and surfaces runtime-start failure cleanly
- latest validation rerun is green (`swift test`: 81 passing)

## Key docs

- [Original project handover](./google-drive-icon-guard-handover.md)
- [Milestone 1 scope discovery notes](./milestone-1-scope-inventory.md)
- [Public launch checklist](./public-launch-checklist.md)
- [Protection status transitions](./protection-status-state-transitions.md)
- [Codex handover 2026-04-07](./codex-handover-2026-04-07.md)
- [Session handover 2026-04-08](./session-handover-2026-04-08.md)
- [Next steps roadmap](./next-steps-roadmap.md)
- [Endpoint Security Xcode integration](./endpoint-security-xcode-integration.md)
