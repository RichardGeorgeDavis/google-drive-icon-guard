# Next Steps Roadmap

This roadmap captures immediate engineering priorities and project expansion opportunities.

## Current execution plan

The project should be executed in end-to-end batches. Do not broaden product claims beyond audit-only beta behavior until Batch 3 is complete and validated under real Endpoint Security traffic.

### Batch 1: correctness and baseline stabilization

Goal: remove known correctness gaps in the current beta lane.

- fix `ScopeEnforcementMonitor.stop()` so shutdown disables enforcement, not just callbacks
- add regression coverage proving no cleanup occurs after shutdown
- fix beta artifact verification so helper JSON validation works in the release script
- keep Endpoint Security preflight in a non-failure bundled state instead of reporting `.error`
- align the Xcode integration doc with the actual public subscriber API

Definition of done:

- `swift test` passes
- `./Tools/release/build-beta-app.sh` completes successfully
- docs no longer imply a broken or inaccessible ES entrypoint

### Batch 2: ES embedding contract

Goal: make the live Endpoint Security integration surface concrete and handoff-ready.

- finalize the public subscriber API used by the Xcode/runtime target
- keep callback bridge and mapper as the canonical conversion path
- document exact lifecycle: `start`, callback attachment, subscription, `ready`, `stop`, `error`
- add focused tests for malformed callback conversion and status transitions

Definition of done:

- a consuming Xcode target can follow the in-repo guide without guessing
- non-ready, ready, and failure states are distinct and credible

### Batch 3: Xcode runtime lane and live callbacks

Goal: run real Endpoint Security callbacks through the policy pipeline.

- add or adopt an Xcode app/system-extension target that links `EndpointSecurity.framework`
- wire entitlement, signing placeholders, `es_new_client`, `es_subscribe`, and teardown
- route live callbacks through `handleLiveEndpointSecurityMessage(_:)`
- validate create/rename/unlink extraction against real traffic
- confirm events reach `HelperProtectionService` and move status to `.ready`

Definition of done:

- real ES events are observed and mapped end-to-end
- the product can truthfully claim live callback ingestion exists

### Batch 4: install lifecycle and boundary hardening

Goal: move from bundled/install-plan signals to real operational readiness.

- implement helper/system-extension registration flow
- emit verified `installed` and `error` installation states
- add authenticated app-helper boundary checks
- add diagnostics for install, approval, and subscription failures

Definition of done:

- install state comes from real runtime checks
- boundary trust assumptions are enforced, not implied

Current implementation progress:

- added receipt-backed install verification for `installed` and `error` state reporting
- added typed command authorization primitives for future helper-bound requests
- added a local protected service endpoint and boundary-backed client that enforce these checks end-to-end in-process
- added an anonymous NSXPC listener/client path that exercises the same boundary over real IPC inside SwiftPM
- added launch-agent registration, receipt writing, helper CLI install commands, named Mach-service client/host path, and launchctl bootstrap/bootout/status lifecycle support
- added app-side install/start/remove/status actions for the LaunchAgent helper path
- added persisted helper configuration so the installed helper can restore the last-known scope set
- added a shared runtime-controller seam so the protected helper boundary can switch from `HelperProtectionService` to `EndpointSecurityRuntimeCoordinator` without rewriting the XPC/install surface
- remaining work is signed deployed-helper packaging, clean-machine packaged validation, final deployed caller-identity validation, and the real Endpoint Security host lane

### Batch 5: release hardening

Goal: make beta distribution trustworthy and repeatable.

- add signing and notarization to the release lane
- publish signed checksums and provenance
- split CI into fast unit and slower integration/release lanes
- update launch and handover docs to match shipped behavior exactly

Definition of done:

- tagged beta builds are reproducible, verifiable, and accurately documented

Current implementation progress:

- release packaging now emits helper-status plus provenance JSON artifacts
- release packaging now supports optional codesign, notarization, stapling, and CMS provenance signing when identities/profiles are supplied
- CI is now split between fast unit tests and a slower packaging smoke lane
- release publication can now create or update alpha/beta GitHub prereleases and attach the packaged assets directly to Releases
- README/support/release-note surfaces now use real app screenshots and copied support diagnostics
- remaining work is operational: provision real Apple signing credentials, validate notarization in CI, and keep public prerelease notes aligned with the shipped UI/support surface

## 30/60/90 day plan

### 30 days (stabilize + measure)

- complete the Xcode host/entitlement lane and verify callback-path correctness under real traffic
- add performance telemetry for refresh latency, monitor cycle interval, and remediation execution time
- split CI into fast unit lane vs filesystem/integration lane for faster PR feedback
- define release trust gate checklist (checksum, signing, notarization, provenance)

## MVP beta from here

For a proper MVP beta that can truthfully claim prevention while the app is closed, the next step order is:

1. finish the Xcode Endpoint Security host target and entitlement path
2. validate real callback delivery into the installed helper boundary
3. test the packaged app + background helper flow on a clean machine
4. provision real signing/notarization and verify the published prerelease assets on a clean machine

If that first item is not complete, keep the public beta claim at audit/review/helper-readiness rather than true prevention.

If Apple Developer Program membership, entitlement approval, or signing budget is not available, do not keep describing Batch 3 as merely delayed. Treat it as blocked, and treat the fallback as a separate compromise lane:

- installed helper runs in background while the app is closed
- watcher/polling detects artefacts after write
- helper performs narrow automatic cleanup in confirmed Drive-managed roots

That fallback can support a "background cleanup" beta, but it is not a substitute for Endpoint Security auth-path enforcement.

### 60 days (harden + scale)

- ship authenticated app-helper/service boundary with caller verification and method authorization
- move install lifecycle from scaffold to verified runtime states (`installed`, `error`)
- add structured diagnostics pipeline (failure taxonomy + user-safe troubleshooting bundle)
- optimize scope scan and remediation reuse with incremental scanning where possible

### 90 days (expand capability)

- add policy profiles (audit-only, suggested, strict) with per-scope override support
- add operator-facing readiness center (entitlements, install, approval, event health)
- add machine-readable exports for fleet automation and support tooling
- prepare signed public beta lane with rollback + kill-switch controls

## Immediate engineering priorities

1. Finish the Xcode Endpoint Security host target, entitlement, and live callback validation
2. Validate the packaged app + installed helper boundary on a clean machine once that live lane exists
3. Validate Batch 5 with real Apple signing/notary credentials in CI
4. Validate the published prerelease entry, attached assets, and release notes on the next tester build
5. Validate the new helper drift/update state against stale, mismatched, and moved packaged installs
6. Extend typed activity export/reporting and refine retained aggregate cleanup outcome visibility
7. Then move to policy-profile expansion

Fallback priority order if entitlement/signing work is blocked:

1. implement a background watcher/post-write cleanup helper lane
2. validate strict scope narrowing and artefact matching to reduce false positives
3. keep public wording at cleanup/neutralization/background guard
4. resume Batch 3 only when the Apple/Xcode entitlement lane is actually available

## Performance optimization track

### Runtime targets

- keep median `refresh()` orchestration time below 150ms for unchanged environments
- maintain adaptive monitor idle intervals with low CPU wakeups and bounded recovery time on change
- reduce repeated disk reads/writes in activity and snapshot paths

### Planned improvements

- introduce explicit background refresh coordinator so report generation/persistence work stays off the UI path
- add scan cache invalidation keyed by scope path + modification timestamps
- batch activity-log persistence on short intervals during event bursts
- add benchmark fixtures for scanner/remediation hot paths

### Success metrics

- 30% reduction in CI median runtime
- 25% reduction in local refresh wall-clock under unchanged scope data
- no deterministic test regressions in monitor cooldown/reentrancy contracts

## Expansion opportunities

### Safety and rollout controls

- add global + per-scope feature flags for protection behavior
- add dry-run-only enforcement mode that records would-block outcomes
- keep an emergency kill switch for live protection paths

### Discovery and classification depth

- deepen DriveFS account-state parsing beyond current root-focused reads
- add confidence scoring to discovered scopes (`confirmed`, `inferred`, `uncertain`)
- improve edge-case handling for custom backup and mixed-volume setups

### UX and operator workflow

- add a Protection Readiness view (entitlements, install, approval blockers)
- add guided permission recovery and one-click troubleshooting exports
- add clearer per-scope risk/recommendation wording for beta users
- validate packaged-build helper drift detection and `Update Helper` behavior against reused, stale, and mismatched installed helpers
- extend typed activity-log export/report surfaces now that helper, cleanup, protection, warning, and inventory categories are persisted
- refine the aggregate `Run Cleanup` journey after tester feedback, especially around post-refresh result visibility and skipped-scope explanation

### Release and operations maturity

- add signing/notarization execution plan and preflight checklist
- publish machine-readable JSON findings export for automation
- add CI artifact verification summaries for every beta packaging run

### Plugin/product expansion

- add extension points for custom artefact rules loaded from signed rule bundles
- support additional cloud-sync providers via provider adapters
- expose a documented automation interface for enterprise policy management
- add optional remediation approval workflows (manual gate, scheduled window, dry-run-to-apply)

## Recommended execution order

1. Batch 1: correctness and baseline stabilization
2. Batch 2: ES embedding contract
3. Batch 3: Xcode runtime lane and live callbacks
4. Batch 4: install lifecycle and boundary hardening
5. Batch 5: release hardening

## Xcode live ES client

SwiftPM builds do not link `EndpointSecurity.framework`. Add an Xcode app or system extension target, link the framework, apply entitlements, and wire `handleLiveEndpointSecurityMessage` as documented in [endpoint-security-xcode-integration.md](./endpoint-security-xcode-integration.md). Example entitlements: `Installer/EndpointSecurity/entitlements.example.plist`.

What remains for a true live lane is outside SwiftPM alone: an actual signed Xcode app or system extension target, the `com.apple.developer.endpoint-security.client` entitlement, and on-device approval. The repo now has the runtime code that host should consume.
