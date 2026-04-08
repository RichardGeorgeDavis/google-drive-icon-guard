# Help Wanted

Google Drive Icon Guard is actively looking for outside help. The main blocker is no longer basic app scaffolding. It is the Apple platform lane required for true closed-app blocking on macOS.

## Highest-priority help

- Apple Developer Program access or sponsorship for a team that can ship the app
- help requesting or sponsoring the restricted `com.apple.developer.endpoint-security.client` entitlement
- help creating or validating the signed Xcode host app plus system extension target
- help validating the signed system-extension approval flow on a real Mac

## Why this matters

Without the Apple entitlement lane, the project can keep improving as an audit, cleanup, and background-helper beta, but it cannot truthfully claim real Google-Drive-only closed-app blocking.

## Ways to help

### 30 minutes

- read [README.md](../README.md), [current-state.md](./current-state.md), and [architecture.md](./architecture.md)
- test the packaged app from `/Applications`
- report helper install, update, or startup problems with screenshots and copied diagnostics
- review open [`help wanted`](https://github.com/RichardGeorgeDavis/google-drive-icon-guard/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22) issues

### Half day

- validate packaged helper update detection against stale or mismatched installs
- improve support exports, logs, or cleanup-result reporting
- improve DriveFS parsing coverage with realistic fixtures
- review README and support wording for clarity to outside contributors

### One day or more

- help wire the signed Xcode host and system-extension lane
- help move the runtime from notify-only observation to auth-event allow/deny enforcement
- help validate the signed build, provisioning, and on-device approval path
- help harden release signing and notarization once Apple credentials exist

## Current open areas

- [Create the signed Xcode host and system-extension lane for Endpoint Security](https://github.com/RichardGeorgeDavis/google-drive-icon-guard/issues/24)
- [Track Apple Developer Program and Endpoint Security entitlement blocker](https://github.com/RichardGeorgeDavis/google-drive-icon-guard/issues/27)
- [Implement auth-event Endpoint Security enforcement and real allow/deny responses](https://github.com/RichardGeorgeDavis/google-drive-icon-guard/issues/28)
- [Validate packaged helper update state and drift detection on clean-machine installs](https://github.com/RichardGeorgeDavis/google-drive-icon-guard/issues/26)
- [Extend typed activity export/reporting and retain aggregate cleanup outcomes](https://github.com/RichardGeorgeDavis/google-drive-icon-guard/issues/25)

## If you can help

- open an issue
- comment on the relevant open issue
- use the support links in [SUPPORT.md](../.github/SUPPORT.md)

If you can specifically help with Apple Developer Program sponsorship, Endpoint Security entitlement access, or system-extension validation, say that explicitly in the issue title or first paragraph so it is easy to route.
