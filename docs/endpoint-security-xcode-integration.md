# Endpoint Security: Xcode integration

The Swift package builds the helper and libraries without linking `EndpointSecurity.framework` at link time. Live `es_new_client` / `es_subscribe` must run in a target that links the framework and carries the correct entitlement. Use this guide when you add an Xcode app or system extension that consumes `DriveIconGuardHelper`.

## Prerequisites

- Apple Developer Program membership for the Endpoint Security entitlement.
- A macOS app or (recommended for production) a **system extension** target that is approved for Endpoint Security.
- This repository checked out; `swift build` succeeds.

## 1. Create an Xcode workspace

1. In Xcode: **File → New → Project → macOS App** (or add a **System Extension** target to an existing app).
2. **Add the Swift package**: **File → Add Package Dependencies** → add the local path to this repo, or add the remote URL if published.
3. Add the **`DriveIconGuardHelper`** (and **`DriveIconGuardIPC`** if needed) product to the app/extension target’s **Frameworks, Libraries, and Embedded Content**.

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

`EndpointSecurityProcessAttributedEventSubscriber` exposes:

- `start(eventHandler:)` — sets the runtime handler used for mapped events.
- `handleLiveEndpointSecurityMessage(_:)` — call this from the **`es_new_client`** callback with each `es_message_t` pointer.

Copy the commented integration block from `Helper/EventSubscription/EndpointSecurityProcessAttributedEventSubscriber.swift` (search for `Live ES client integration`) into your app/extension code, then:

1. Call `start { event in … }` (e.g. forward `event` into `HelperProtectionService` or your coordinator).
2. In `es_new_client`’s handler, call `subscriber.handleLiveEndpointSecurityMessage(message)`.
3. On shutdown, unsubscribe and delete the client as in the comment (`es_unsubscribe_all`, `es_delete_client`).

## 5. Order of operations

1. Instantiate `EndpointSecurityProcessAttributedEventSubscriber`.
2. Call `start(eventHandler:)` so `runtimeEventHandler` is set **before** the first ES callback.
3. Create the client and subscribe.
4. On tear down, call `stop()` on the subscriber and tear down the ES client.

## 6. SwiftPM-only beta builds

The command-line helper built with `swift build` continues to use preflight / status-only behavior until this Xcode-linked path is used. That is expected; do not remove the beta guard in the app until policy and install flows are verified end-to-end.

## References

- In-repo state transition notes: [protection-status-state-transitions.md](./protection-status-state-transitions.md)
- Codex handover: [codex-handover-2026-04-07.md](./codex-handover-2026-04-07.md)
- App/helper boundary notes: `App/XPCClient/README.md` and `Shared/IPC/README.md`
