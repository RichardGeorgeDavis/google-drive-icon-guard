# Session Handover 2026-04-01

This note captures the current repo state at the end of the latest helper/runtime scaffolding pass.

## Current branch state

- branch: `main`
- latest commit at handoff time: `435c0cb`

## What is now true

- the beta app bundles:
  - the SwiftUI viewer app
  - the standalone `drive-icon-guard-helper` executable
  - installer scaffold resources under `Installer/ServiceRegistration`
- the app now reports:
  - helper/event-source readiness
  - install/runtime readiness
- the packaged helper supports:
  - `--help`
  - `--status`
  - replay/test event evaluation through `--events`

## Important product boundary

The app is still correctly **audit-only** for live protection.

That is intentional and should not be treated as a regression.

The missing step is still:

- a real macOS Endpoint Security event subscription path
- a real helper/system-extension install and registration path

Until those exist, supported scopes should remain `auditOnly`.

## Current status model

The app and helper now distinguish:

- event source state:
  - `unavailable`
  - `bundled`
  - `needsApproval`
  - `ready`
  - `error`
- installation state:
  - `unavailable`
  - `bundledOnly`
  - `installPlanReady`
  - `installed`
  - `error`

Right now the expected packaged helper status is effectively:

- event source: `needsApproval`
- install state: `installPlanReady`

## Files most relevant for the next step

- `Helper/EventSubscription/EndpointSecurityProcessAttributedEventSubscriber.swift`
- `Helper/Audit/HelperProtectionService.swift`
- `Shared/IPC/ProtectionServiceModels.swift`
- `App/XPCClient/EmbeddedProtectionServiceClient.swift`
- `App/XPCClient/ProtectionInstallerResourceLocator.swift`
- `App/UI/ScopeInventoryWindow.swift`
- `Tools/ProtectionHelperCLI/main.swift`
- `Installer/ServiceRegistration/README.md`

## Verified recently

The following were run successfully before handoff:

- `swift build`
- `swift test`
- `./Tools/release/build-beta-app.sh`
- packaged helper `--status`

## Best next coding step

1. Enable the live Endpoint Security client/subscription path in an Xcode app/system-extension lane (not SwiftPM-only path), using `handleLiveEndpointSecurityMessage`.
2. Feed those live process-attributed events into `HelperProtectionService`.
3. Turn the current install scaffold into a real helper/system-extension registration flow.
4. Only after that, allow supported scopes to move from `auditOnly` to `blockKnownArtefacts`.

## Review findings to carry forward

The latest plan/implementation review found the following gaps that should be addressed before broadening beta claims.

Review source:

- Cursor -> Codex review handoff item (plan/implementation gap review)

### High priority

- resolved in follow-up:
  - beta runtime now normalizes incoming `blockKnownArtefacts` to `auditOnly` in embedded configuration
  - this prevents unintended auto-enforcement in current beta runtime paths

### Medium priority

- resolved in follow-up:
  - embedded/dev path no longer reports event source `ready`
  - status now keeps this path in non-ready semantics (`bundled`)

### Low priority

- resolved in follow-up:
  - refresh activity log now writes the latest persisted snapshot path directly

### Validation note

- full test run is green, and regression coverage now includes beta coercion and embedded non-ready status assertions.

## Review follow-up status (Cursor -> Codex)

The first round of follow-up from the Cursor -> Codex review item has now been implemented:

- audit-only beta boundary is now runtime-enforced in embedded protection configuration by normalizing `blockKnownArtefacts` to `auditOnly`
- embedded event source status no longer reports `ready` in the dev/test path (now `bundled`)
- refresh activity log entries now use the latest persisted snapshot path directly
- validation rerun is green (`swift test`: 45 passing)

## Live ES blocker note

- the callback bridge and extraction scaffolding are now implemented in repo, but live ES activation still requires:
  - linking `EndpointSecurity.framework` in an Xcode runtime target
  - approved Endpoint Security entitlement and signing profile
  - runtime approval/activation flow on-device
- see:
  - `docs/endpoint-security-xcode-integration.md`
  - `Installer/EndpointSecurity/entitlements.example.plist`
