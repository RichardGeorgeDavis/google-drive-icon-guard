# Changelog

## 2026-04-08

### Implemented

- added receipt-backed install verification for `installed` and `error` helper state reporting
- added typed caller/command authorization primitives for future helper-bound control surfaces
- added a SwiftPM runtime-support lane for live Endpoint Security session wiring in an Xcode host
- added release packaging provenance output plus optional codesign/notarization/stapling hooks
- split CI into fast unit coverage and slower packaging-smoke/release lanes
- added anonymous and Mach-service NSXPC helper boundary paths plus launch-agent/receipt installation support
- added launchctl bootstrap/kickstart/bootout/status lifecycle support plus helper CLI deployment commands for the packaged LaunchAgent path

### Testing

- added regression coverage for monitor stop behavior, ES callback mapping, runtime-lane session flow, install receipt handling, authorization rules, and launchd lifecycle handling

### Documentation

- refreshed handover, roadmap, release packaging, and launch-checklist docs to match the new runtime/install/release boundaries, including helper launchd lifecycle support

## 2026-04-01

### Implemented

- surfaced helper install/runtime readiness in the app alongside Endpoint Security readiness
- added installer scaffold detection and bundled those resources into the packaged beta app
- extended the packaged helper `--status` output to report both event-source and install-plan state

### Documentation

- refreshed public-facing docs to remove stale app-only and Milestone 1 wording
- updated first-run guidance and launch checklist for the bundled helper plus install scaffold state

## 2026-03-31

### Implemented

- packaged a standalone `drive-icon-guard-helper` executable with the beta app bundle
- added replay/test helper event loading for process-attributed event evaluation
- surfaced helper host availability and Endpoint Security readiness more explicitly in the app UI
- added an `EndpointSecurityProcessAttributedEventSubscriber` skeleton and helper/runtime status reporting for the next enforcement phase
- packaged installer scaffold resources so the app and helper can report `installPlanReady` without claiming real registration support

### Documentation

- updated beta packaging and current-progress docs to reflect the bundled helper host and remaining Endpoint Security blocker

## 2026-03-27

### Implemented

- audit-only hidden artefact scanning across supported and audit-only scopes
- per-scope artefact summaries with match counts, storage impact, and sample paths
- viewer updates to surface scan status and artefact impact alongside discovered scopes
- recent snapshot history browsing and current-versus-previous delta summaries in the viewer

### Testing

- added scanner coverage for hidden artefact detection, unsupported-scope skips, and missing-scope warnings
- added persistence coverage for history loading and snapshot comparison deltas

## 2026-03-24

### Added

- standalone Git repository setup for `google-drive-icon-guard`
- public-facing `README.md` describing the beta state and intended downloadable app direction
- repo policy files:
  - Code of Conduct
  - Contributing
  - Security
  - Support
  - MIT License
- GitHub Actions macOS workflow for Swift package CI
- issue templates for bugs, feature requests, and release/setup work
- public launch checklist
- current progress handover

### Implemented

- Swift Package scaffold for the scope inventory work
- shared data models for scopes, process signatures, artefact rules, and events
- scope discovery CLI: `swift run drive-icon-guard-scope-inventory`
- minimal SwiftUI viewer: `swift run drive-icon-guard-viewer`
- expanded SwiftUI app shell with overview, inventory, logs placeholder, and settings placeholder
- DriveFS root preference parsing from `root_preference_sqlite.db`
- per-account DriveFS root confirmation from `mirror_sqlite.db`
- beta packaging script for an unsigned downloadable `.app`
- manual GitHub Actions workflow for beta app archive builds
- fallback discovery of visible `~/Library/CloudStorage/GoogleDrive*` stream roots
- scope classification by mode, scope kind, volume kind, filesystem kind, and support status
- persisted inventory snapshots written to `cache/scope-inventory/latest.json`
- persisted inventory history written to `cache/scope-inventory/history/`

### Documentation

- moved the original product handover into `docs/`
- added Milestone 1 notes describing the current implementation boundary
- clarified the testing caveat around full Xcode versus Command Line Tools
- updated docs to reflect that full Xcode testing now works on the maintainer machine
- aligned docs around public beta positioning

### Cleanup

- removed tracked icon option image assets from Git history going forward
- ignored `icon-options/` and `icon options/`
- kept generated cache output ignored from version control
