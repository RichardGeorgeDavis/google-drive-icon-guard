# Current State

This is the fastest contributor-facing summary of where the project stands right now.

## What works today

- discovers Google Drive-managed locations on macOS
- scans supported and audit-only scopes for `Icon\r` and `._*` artefacts
- shows scope details, history, recent activity, and cleanup readiness in the SwiftUI app
- installs, refreshes, updates, and removes the background LaunchAgent helper path
- persists helper configuration and reconnects to the installed Mach-service helper when available
- exports reports and support diagnostics for testers
- publishes alpha/beta prereleases through GitHub Releases

## What is still blocked

True closed-app blocking is still blocked by the Apple Endpoint Security lane:

- signed Xcode host app plus system extension target
- approved `com.apple.developer.endpoint-security.client` entitlement
- provisioning, signing, and on-device approval
- auth-event allow/deny responses under real traffic

Without that lane, the project remains an audit, cleanup, and helper-readiness beta rather than a true prevention release.

## Current asks

- Apple Developer Program / entitlement sponsorship
- Xcode system-extension and Endpoint Security help
- real-Mac validation of signed builds when that lane exists
- packaged-build validation of helper update state and support/reporting UX

## Best next docs

- [Help Wanted](./help-wanted.md)
- [Architecture](./architecture.md)
- [Roadmap](./roadmap.md)
- [Endpoint Security Xcode integration](./endpoint-security-xcode-integration.md)
- [Development setup](./development-setup.md)

## Detailed internal handoff

For the detailed implementation ledger and session-level context, use [current-progress-handover.md](./current-progress-handover.md).
