# Endpoint Security: Xcode integration

The Swift package builds the helper and libraries without linking `EndpointSecurity.framework` at link time. Live `es_new_client` / `es_subscribe` must run in a target that links the framework and carries the correct entitlement. Use this guide when you add an Xcode app or system extension that consumes `DriveIconGuardHelper`.

## Why this is the next critical step

The repo already has:

- app-side background helper install/remove/status controls
- a named Mach-service helper boundary
- persisted helper configuration for the installed helper path
- runtime-support code that can consume live Endpoint Security callbacks
- a protected helper boundary that can now accept `EndpointSecurityRuntimeCoordinator` directly through the shared runtime-controller contract

What it does **not** yet have is the real signed Xcode host target and entitlement path that can supply live Endpoint Security traffic. Until this guide is carried through in a real target, the product must stay positioned as audit-first beta behavior rather than true closed-app prevention.

If you do not have Apple Developer Program membership or Apple has not approved the Endpoint Security entitlement for your team, this guide is blocked at the provisioning stage. In that situation, the only practical alternative is a background post-write cleanup helper, which is useful but not equivalent to true live blocking.

## Prerequisites

- Apple Developer Program membership for the Endpoint Security entitlement.
- A macOS app or (recommended for production) a **system extension** target that is approved for Endpoint Security.
- This repository checked out; `swift build` succeeds.

Without those prerequisites, you can still prototype host structure and runtime seams, but you cannot complete a real signed Endpoint Security enforcement lane.

## 1. Create an Xcode workspace

1. In Xcode: **File → New → Project → macOS App** (or add a **System Extension** target to an existing app).
2. **Add the Swift package**: **File → Add Package Dependencies** → add the local path to this repo, or add the remote URL if published.
3. Add the **`DriveIconGuardRuntimeSupport`** product to the app/extension target’s **Frameworks, Libraries, and Embedded Content**.
4. Add **`DriveIconGuardHelper`** or **`DriveIconGuardIPC`** only if you need lower-level types directly in the host target.

## 2. Link Endpoint Security

1. Select the app or extension target → **Build Phases** → **Link Binary With Libraries**.
2. Click **+** → add **`EndpointSecurity.framework`** (system framework on macOS).

Without this step, symbols such as `es_new_client` will fail at link time.

## 3. Entitlements

1. Create an entitlements file for the target that will host the ES client (e.g. `YourApp/YourApp.entitlements`).
2. Enable the client entitlement (example below). Request the capability in the Apple Developer portal for your App ID / provisioning profile.

Example (adjust Team ID and bundle id as needed):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.endpoint-security.client</key>
	<true/>
</dict>
</plist>
```

3. In the target **Signing & Capabilities**, assign this entitlements file and ensure **Code Signing** uses a profile that includes the entitlement.

See also: `Installer/EndpointSecurity/entitlements.example.plist` in this repo.

## 4. Wire the live client to the subscriber

For the Xcode runtime lane, prefer `DriveIconGuardRuntimeSupport.EndpointSecurityRuntimeCoordinator`.

It owns:

- `HelperProtectionService`
- `EndpointSecurityProcessAttributedEventSubscriber`
- the live `es_new_client` / `es_subscribe` session via `SystemEndpointSecurityLiveMonitoringSession`

Lower-level subscriber APIs remain available when needed. `EndpointSecurityProcessAttributedEventSubscriber` exposes:

- `start(eventHandler:)` — sets the runtime handler used for mapped events.
- `handleLiveEndpointSecurityMessage(_:)` — public live-callback entrypoint; call this from the **`es_new_client`** callback with each `es_message_t` pointer.
- `handleLiveRawEvent(_:)` — optional raw-event entrypoint for tests or adapters that already converted callback payloads into `EndpointSecurityRawCallbackEvent`.

Recommended runtime-host flow:

1. Instantiate `EndpointSecurityRuntimeCoordinator`.
2. Inject that coordinator into the protected helper boundary (`LocalProtectionServiceEndpoint` directly, or `ProtectionXPCListenerHost` for the NSXPC host path).
3. Call `updateScopes(...)` with the currently protected scopes before starting live monitoring.
4. Call `start { evaluation in … }` to begin live monitoring and receive policy evaluations.
5. On shutdown, call `stop()`.

Minimal example:

```swift
import DriveIconGuardRuntimeSupport
import DriveIconGuardShared

let coordinator = EndpointSecurityRuntimeCoordinator()
coordinator.updateScopes(scopes)
try coordinator.start { evaluation in
    print("decision:", evaluation.decision.rawValue, "path:", evaluation.event.targetPath)
}
```

Protected-boundary host example:

```swift
import DriveIconGuardRuntimeSupport
import DriveIconGuardXPCClient

let coordinator = EndpointSecurityRuntimeCoordinator()
let endpoint = LocalProtectionServiceEndpoint(service: coordinator)
let host = ProtectionXPCListenerHost(
    machServiceName: "com.richardgeorgedavis.google-drive-icon-guard.beta.helper",
    serviceEndpoint: endpoint
)

_ = host
```

Notes:

- `start(eventHandler:)` should not itself emit a synthetic policy event. It only arms the runtime handler and leaves the subscriber in a bundled/non-ready state until real live callbacks are dispatched.
- use `handleLiveRawEvent(_:)` only outside the direct ES callback path, such as unit tests or intermediate adapters.
- `EndpointSecurityRuntimeCoordinator` marks the subscriber `ready` once the live ES client is successfully subscribed.
- `LocalProtectionServiceEndpoint` now reports runtime-start failure as a protected-boundary command/status failure instead of silently falling back to idle behavior.

## 5. Order of operations

1. Instantiate `EndpointSecurityRuntimeCoordinator`.
2. Update scopes before starting live monitoring.
3. Call `start(...)` after entitlements/signing are in place.
4. On tear down, call `stop()`.

## 6. SwiftPM-only beta builds

The command-line helper built with `swift build` continues to use preflight / status-only behavior until this Xcode-linked path is used. During this phase the subscriber may report a bundled/non-ready state after `start(eventHandler:)`; that is expected. The runtime-support library compiles the real ES client/session wiring, but entitlement approval and an Xcode-hosted signed target are still required before live monitoring can run successfully.

## Immediate acceptance criteria for this host lane

Treat this work as done only when all of the following are true:

1. a signed Xcode app or system-extension target links `EndpointSecurity.framework`
2. that target has a provisioning profile carrying `com.apple.developer.endpoint-security.client`
3. `EndpointSecurityRuntimeCoordinator.start(...)` succeeds on-device
4. real create/rename/unlink callbacks reach `handleLiveEndpointSecurityMessage(_:)`
5. the subscriber transitions to `.ready` under real traffic
6. the installed helper boundary can stay armed through the closed-app path rather than only the embedded/test path

Until then, keep the shipped product claim at audit/review/helper-readiness and not true prevention.

## Non-ES fallback boundary

If the team cannot yet carry the Apple entitlement lane, the fallback option is:

- LaunchAgent helper stays installed and active while the app is closed
- file-system watcher or polling detects artefacts after they are written
- the helper runs narrow cleanup/remediation against exact known artefact patterns in confirmed Drive-managed roots

That path can support a useful "background cleanup" beta, but it does not satisfy the acceptance criteria above and should not be described as true blocking or process-aware prevention.

For a broader survey of “creative” non-ES approaches (and why they are not equivalent), see:

- [Non-Endpoint-Security alternatives](./non-endpoint-security-alternatives.md)

## References

- In-repo state transition notes: [protection-status-state-transitions.md](./protection-status-state-transitions.md)
- Historical Codex handover: [archive/codex-handover-2026-04-07.md](./archive/codex-handover-2026-04-07.md)
- App/helper boundary notes: `App/XPCClient/README.md` and `Shared/IPC/README.md`
