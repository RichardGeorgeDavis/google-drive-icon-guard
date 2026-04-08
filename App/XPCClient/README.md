# XPC Client

This module hosts client-side protection wiring for the app boundary and is the landing point for the future authenticated XPC/service split.

## Current implemented responsibilities

- expose protection configuration updates from the app to the embedded monitoring path
- report normalized status snapshots for beta-safe protection behavior
- forward enforcement events to UI consumers using shared IPC payload contracts
- provide install-plan readiness/status hints based on bundled helper + installer resources
- load and validate installation receipts so the client can report verified `installed` and `error` states
- define a first-pass authorization policy for future helper-bound commands
- host a local protected service boundary around `HelperProtectionService`
- expose a boundary-backed client that exercises authorization, install-state checks, and configuration validation without requiring a real XPC listener yet
- expose an anonymous NSXPC listener host and XPC client for end-to-end protected command flow inside SwiftPM
- generate launch-agent registration + receipt files for the packaged helper
- expose a Mach-service client/host path intended for the deployed helper lane
- bootstrap, kickstart, bootout, and inspect the helper LaunchAgent through a typed `launchctl` manager and deployment coordinator

## Security boundary requirements (next implementation stage)

When promoting the current anonymous NSXPC path into the installed helper/service boundary, enforce:

1. caller authentication
   - validate caller audit token
   - validate designated code requirement/team identity
2. method-level authorization
   - reject unauthorized configuration or command requests
   - minimize surface area of privileged operations
3. strict payload validation
   - reject malformed/oversized requests
   - validate scope paths before any filesystem side effects
4. failure observability
   - structured logs for rejected clients and denied operations
   - explicit status mapping for authn/authz failures

## Current boundary primitives now in repo

- `ProtectionServiceAuthorizer`
- `ProtectionServiceAuthorizationContext`
- `ProtectionServiceCommand`
- `ProtectionInstallationReceiptLocator`
- `ProtectionInstallationStatusResolver`
- `LocalProtectionServiceEndpoint`
- `BoundaryProtectionServiceClient`
- `ProtectionXPCListenerHost`
- `XPCProtectionServiceClient`

These now define and exercise:

- which helper-bound commands are high risk
- minimum audit-token and trusted-caller requirements
- how receipt-backed install verification maps to `installed` and `error`
- how a protected helper/service host accepts or rejects privileged commands
- how UI/client code can consume that host through the same `ProtectionServiceClient` interface
- how the same host is reached through a real NSXPC request/reply + callback path

Remaining work:

- derive caller context from the final deployed helper/service environment
- keep installer-driven receipt creation aligned with the deployed service path
- move the current helper CLI and coordinator-driven lifecycle into the app's install/start/stop/status UX

## Related files

- `Shared/IPC/ProtectionServiceModels.swift`
- `Shared/IPC/README.md`
- `docs/protection-status-state-transitions.md`
