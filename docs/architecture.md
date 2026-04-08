# Architecture

This page explains the current project shape in contributor language.

## Main components

### SwiftUI app

The app is the visible control plane.

Responsibilities:

- scope discovery and review
- cleanup preview and apply
- history and activity logs
- helper install/update/remove/status workflow
- support diagnostics and exported reports

Primary areas:

- `App/UI/`
- `App/ScopeInventory/`
- `App/XPCClient/`

### LaunchAgent helper and XPC boundary

The current background path is a LaunchAgent helper plus an NSXPC boundary.

Responsibilities:

- receive persisted configuration
- expose runtime/install status
- support background helper lifecycle testing
- act as the control plane/status bridge for future protection work

Primary areas:

- `Helper/`
- `App/XPCClient/`
- `Tools/ProtectionHelperCLI/`

### Runtime support for future Endpoint Security host

The repo already includes runtime support for a future signed Xcode host or system extension.

Responsibilities:

- consume live Endpoint Security callbacks
- map raw callback data into process-attributed file events
- feed those events into the existing policy engine

Primary areas:

- `RuntimeHostSupport/`
- `Helper/EventSubscription/`
- `Helper/PolicyEngine/`

## What is implemented

- audit-only discovery and artefact scanning
- helper install/bootstrap/status/update/remove workflow
- typed activity logging and recent activity summary
- aggregate cleanup for supported findings
- release packaging and prerelease publication

## What is not implemented

- a signed production system-extension host
- approved Endpoint Security entitlement path
- real auth-event allow/deny enforcement
- truthful closed-app Google-Drive-only blocking

## Current boundary

Today’s product boundary is:

- audit, cleanup, and helper-readiness beta

It is not yet:

- true pre-write prevention while the app is closed

## Read next

- [Current State](./current-state.md)
- [Roadmap](./roadmap.md)
- [Help Wanted](./help-wanted.md)
- [Endpoint Security Xcode integration](./endpoint-security-xcode-integration.md)
