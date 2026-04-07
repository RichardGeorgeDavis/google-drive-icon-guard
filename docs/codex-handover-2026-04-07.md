# Codex Handover 2026-04-07

This note captures the latest Cursor -> Codex follow-up pass and the immediate next implementation target.

## What changed in this pass

- enforced beta runtime audit-only boundary in embedded configuration by normalizing `blockKnownArtefacts` to `auditOnly`
- tightened embedded status semantics so dev/test path does not report event source `ready`
- fixed inventory refresh activity logging to record the latest persisted snapshot path directly
- added regression tests for:
  - embedded beta coercion behavior
  - embedded non-`ready` status contract
  - installer state contract (`unavailable`, `bundledOnly`, `installPlanReady`)
- fixed `ScopeEnforcementMonitor` teardown race by making `stop()` deterministic and queue-safe
- added protection status transition spec:
  - `docs/protection-status-state-transitions.md`

## What remains intentionally stubbed

- live `es_new_client`/`es_subscribe` activation in a target that links `EndpointSecurity.framework`
- production install/registration lifecycle that can emit `installed` and `error` from verified runtime checks
- final helper/system-extension packaging and approval UX flow

## ES slice update in this pass

- callback bridge path is now in place:
  - raw callback event model (`EndpointSecurityRawCallbackEvent`)
  - callback bridge mapping (`EndpointSecurityCallbackBridge`)
  - event mapper to policy payload (`EndpointSecurityEventMapper`)
- subscriber now includes:
  - `es_message_t` extraction helpers for create/rename/unlink (`makeRawCallbackEvent`, `extractProcessMetadata`, `extractTargetPath`)
  - runtime dispatch entrypoints (`handleLiveEndpointSecurityMessage`, `handleRawEventFromRuntime`)
  - explicit status transitions for conversion/dispatch success and failure paths
- this remains a preflight/runtime-readiness slice until ES client/subscription is enabled in an Xcode-linked runtime lane

## Current validation

- `swift test` is green after changes
- added tests increase contract coverage around beta guard and install-state behavior
- beta packaging rebuilt successfully via `./Tools/release/build-beta-app.sh`
- packaged helper status (`--status --json`) currently reports:
  - event source: `needsApproval`
  - installation: `installPlanReady`
- test suite size at handover: `43` passing tests

## Build artefact paths

- app: `dist/Google Drive Icon Guard.app`
- zip: `dist/google-drive-icon-guard-beta-unsigned.zip`
- helper: `dist/Google Drive Icon Guard.app/Contents/Helpers/drive-icon-guard-helper`

## Implementation note for next ES slice

- SwiftPM helper builds in this repo are intentionally not the lane for enabling live `es_new_client`/`es_subscribe`.
- enable live ES in an Xcode app/system-extension target that:
  - links `EndpointSecurity.framework`
  - has approved `com.apple.developer.endpoint-security.client` entitlement
  - calls `handleLiveEndpointSecurityMessage` from the ES callback
- references:
  - `docs/endpoint-security-xcode-integration.md`
  - `Installer/EndpointSecurity/entitlements.example.plist`

## Recommended immediate next target

1. Create or adopt an Xcode app/system-extension runtime lane and link `EndpointSecurity.framework`.
2. Enable approved Endpoint Security entitlement and signing profile.
3. Turn on live client/subscription and route callbacks through `handleLiveEndpointSecurityMessage`.
4. Verify status transition to `.ready` on successful callback dispatch.
5. Keep current beta guard intact until install/approval + process attribution are verified end-to-end.

## Xcode live client (repo additions)

- Added [endpoint-security-xcode-integration.md](./endpoint-security-xcode-integration.md) with steps to link `EndpointSecurity.framework`, entitlements, and wire `handleLiveEndpointSecurityMessage`.
- Added `Installer/EndpointSecurity/entitlements.example.plist` and `Installer/EndpointSecurity/README.md`.

## Open technical risks

- Endpoint Security callback extraction is now implemented, but full end-to-end validation with real `es_message_t` callback traffic is still pending in an Xcode-linked runtime lane.
- `extractTargetPath` now assembles create/rename new-path values using directory + filename; this should be verified against real callback payloads during live testing.
- Subscriber runtime event handler access is now lock-protected; keep this thread-safety guard intact when adding live client lifecycle state.

## Required follow-up before enabling live ES

1. Validate create/rename/unlink target-path extraction against real Endpoint Security callbacks.
2. Enable live `es_new_client`/`es_subscribe` path in the Xcode runtime lane and verify steady-state `.ready` transitions.
3. Add live-path failure tests/telemetry for malformed callback payloads and conversion failures.
4. Keep beta audit-only guard in place until end-to-end live callback behavior is verified.

## TODO: ES runtime bridge implementation map

Use this as the concrete next implementation checklist.

### 1) Callback extraction layer (raw ES -> callback bridge input)

- file: `Helper/EventSubscription/EndpointSecurityProcessAttributedEventSubscriber.swift`
- add helper functions:
  - `private func makeRawCallbackEvent(from message: UnsafePointer<es_message_t>) -> EndpointSecurityRawCallbackEvent?`
  - `private func extractProcessMetadata(from message: UnsafePointer<es_message_t>) -> EndpointSecurityProcessMetadata`
  - `private func extractTargetPath(from message: UnsafePointer<es_message_t>, operation: EndpointSecurityRawOperation) -> String?`
- requirement:
  - support at least create/rename/unlink notify events
  - return nil for unsupported/incomplete messages instead of crashing

### 2) Event conversion layer (callback bridge -> policy event)

- file: `Helper/EventSubscription/EndpointSecurityCallbackBridge.swift`
- keep `map(_:) -> ProcessAttributedFileEvent?` as the canonical conversion entrypoint
- if needed, add:
  - `public func canMap(_ rawEvent: EndpointSecurityRawCallbackEvent) -> Bool`
- requirement:
  - no side effects in mapping
  - deterministic conversion suitable for unit testing

### 3) Subscriber runtime dispatch

- file: `Helper/EventSubscription/EndpointSecurityProcessAttributedEventSubscriber.swift`
- in live callback path:
  - convert `es_message_t` -> `EndpointSecurityRawCallbackEvent`
  - call `callbackBridge.map(...)`
  - forward mapped event into `eventHandler`
- status behavior:
  - set `.ready` only after runtime callback path is attached and receiving subscribed event classes
  - set `.error` with actionable detail for client/subscription/callback conversion failures

### 4) Helper service integration check

- file: `Helper/Audit/HelperProtectionService.swift`
- confirm no API change is required; service already accepts `ProcessAttributedFileEvent`
- add focused tests proving events received from subscriber callback path reach policy evaluation unchanged

### 5) Tests to add in next slice

- file: `Tests/DriveIconGuardHelperTests/EndpointSecurityProcessAttributedEventSubscriberTests.swift`
  - add tests for status transitions: `needsApproval -> ready` (on successful live start) and failure to `.error`
- file: `Tests/DriveIconGuardHelperTests/EndpointSecurityCallbackBridgeTests.swift`
  - add rename edge-case coverage (old/new path handling as implemented)
  - add malformed event coverage (missing path/process metadata)

## Planned next steps (forward plan)

### Short term

- complete live Endpoint Security runtime verification in Xcode-linked lane
- finalize deterministic coverage for status transitions and callback failure paths
- maintain beta-safe guardrails while live path remains in validation

### Medium term

- implement authenticated app-helper boundary with audit-token and code-sign checks
- complete installer/registration lifecycle and verify `installed` + `error` state transitions
- add standardized performance telemetry for refresh/monitor/remediation execution

### Long term expansion

- add policy profiles and configurable enforcement strategies
- add operator workflows for readiness checks and guided troubleshooting exports
- add adapter architecture for additional sync-provider scope discovery
- deliver fully signed/notarized release lane with provenance and rollback controls
