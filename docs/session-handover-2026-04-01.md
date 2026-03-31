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

1. Replace the Endpoint Security subscriber skeleton with a real event subscription implementation.
2. Feed those live process-attributed events into `HelperProtectionService`.
3. Turn the current install scaffold into a real helper/system-extension registration flow.
4. Only after that, allow supported scopes to move from `auditOnly` to `blockKnownArtefacts`.
