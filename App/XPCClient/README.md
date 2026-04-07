# XPC Client

This module hosts client-side protection wiring for the app boundary and is the landing point for the future authenticated XPC/service split.

## Current implemented responsibilities

- expose protection configuration updates from the app to the embedded monitoring path
- report normalized status snapshots for beta-safe protection behavior
- forward enforcement events to UI consumers using shared IPC payload contracts
- provide install-plan readiness/status hints based on bundled helper + installer resources

## Security boundary requirements (next implementation stage)

When moving from embedded flow to a real helper/service boundary, enforce:

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

## Related files

- `Shared/IPC/ProtectionServiceModels.swift`
- `Shared/IPC/README.md`
- `docs/protection-status-state-transitions.md`
