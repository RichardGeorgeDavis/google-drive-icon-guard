# Session Handover 2026-04-08

This note is the shortest reliable handoff for the next chat.

## Repo state at handoff

- branch: `main`
- worktree: dirty, with substantial uncommitted tracked and untracked changes already in place
- no git cleanup, staging, commit, or branch work was done in this pass

## What is now implemented

- Batch 1 is complete:
  - monitor shutdown no longer allows post-stop cleanup
  - beta artifact verification works end-to-end
  - ES preflight/docs/API mismatches were corrected
- Batch 2 is complete:
  - ES subscriber lifecycle is explicit
  - callback bridge/mapper are the canonical conversion path
  - malformed-event and status-transition coverage exists
- Batch 3 repo-side support is complete:
  - runtime support for a future Xcode host exists under `RuntimeHostSupport/`
  - live ES remains outside SwiftPM-only execution
- Batch 4 repo-side install/boundary work is complete:
  - receipt-backed install-state resolution
  - typed authorization rules
  - local protected endpoint
  - anonymous NSXPC boundary
  - named Mach-service client/host path
  - launch-agent registration/receipt writing
  - `launchctl` bootstrap/kickstart/bootout/status lifecycle support
- Batch 5 repo-side release hardening is complete:
  - checksum, helper-status, and provenance artifacts
  - optional codesign/notarization/stapling hooks
  - CI split into fast unit and slower packaging lanes

## Current product boundary

The shipped claim should still remain:

- audit-only beta for real protection behavior

Do not claim live Endpoint Security-backed blocking yet.

What still remains for a true live lane is outside SwiftPM alone:

- an actual signed Xcode app or system extension target
- the `com.apple.developer.endpoint-security.client` entitlement
- on-device approval

The repo already contains the runtime code that host should consume.

## Verified before handoff

These commands were run successfully on 2026-04-08:

- `swift build --product drive-icon-guard-helper`
- `swift test`
- `./Tools/release/build-beta-app.sh`

Latest full test count at handoff:

- `78` passing tests

## Best next coding target

Move the helper lifecycle from CLI/coordinator-only wiring into app UX.

Concretely:

1. add app-side install/start/stop/status actions around the existing deployment coordinator
2. surface launchd/install errors in operator-facing UI instead of CLI-only output
3. keep the current authorization/install-state checks intact while promoting the flow into the app

After that:

1. provision and validate real Apple signing/notary credentials in CI
2. then build the true live ES host in Xcode and validate real callback traffic

## Files to open first in the next chat

- `App/XPCClient/ProtectionServiceLaunchdManager.swift`
- `App/XPCClient/ProtectionServiceRegistration.swift`
- `App/XPCClient/XPCProtectionServiceClient.swift`
- `App/XPCClient/EmbeddedProtectionServiceClient.swift`
- `Tools/ProtectionHelperCLI/main.swift`
- `App/UI/ScopeInventoryViewModel.swift`
- `docs/current-progress-handover.md`
- `docs/next-steps-roadmap.md`

## Docs that already reflect this state

- `docs/current-progress-handover.md`
- `docs/next-steps-roadmap.md`
- `docs/review-handover-2026-04-08.md`
- `docs/endpoint-security-xcode-integration.md`
