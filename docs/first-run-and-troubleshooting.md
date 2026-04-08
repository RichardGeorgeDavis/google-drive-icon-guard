# First-Run Guidance And Troubleshooting

This guide covers the **current beta/development state** of Google Drive Icon Guard.

Right now the repo provides:

- a scope discovery CLI
- a SwiftUI review app with dashboard, history, logs, and settings
- persisted inventory snapshots under `cache/scope-inventory/latest.json`
- timestamped history snapshots under `cache/scope-inventory/history/`
- a standalone helper host binary
- installer scaffold resources for the future helper/system-extension registration flow
- app-side controls for installing and removing the current LaunchAgent-based helper path
- a beta packaging script for local `.app` and zip creation

It does **not** yet install the final entitlement-backed Endpoint Security host, register a production system extension, or ship the final helper-backed downloadable app flow.

## First run

Use full Xcode rather than Apple Command Line Tools only.

Verify the active toolchain:

```bash
xcode-select -p
swift --version
```

Expected `xcode-select -p` output:

```bash
/Applications/Xcode.app/Contents/Developer
```

Build the project:

```bash
swift build
```

Run the scope discovery CLI:

```bash
swift run drive-icon-guard-scope-inventory
```

Run the minimal viewer:

```bash
swift run drive-icon-guard-viewer
```

Check helper readiness:

```bash
swift run drive-icon-guard-helper --status
```

Run tests:

```bash
swift test
```

## What to expect on first run

- the CLI should print a JSON inventory report
- the CLI should persist the latest snapshot to `cache/scope-inventory/latest.json`
- the CLI should also write a timestamped history snapshot under `cache/scope-inventory/history/`
- the viewer should load discovered scopes, warnings, persisted history, and helper readiness state
- the current implementation should discover configured DriveFS roots when available
- the helper status should report `needsApproval` or `unavailable`, not active blocking

## Current permissions

At the current beta stage, the repo should not require special macOS privacy permissions just to run the discovery CLI, viewer, or helper `--status` check.

The current code reads Google Drive state from the user account’s DriveFS data and presents the resulting inventory. The app can now manage the current LaunchAgent helper lifecycle for beta evaluation, but real live Endpoint Security monitoring still requires the separate Xcode host target, entitlement, signing, and user-approval path.

## Troubleshooting

### `swift test` only seems to build and does not run real tests

Cause:
- the machine is using Apple Command Line Tools instead of full Xcode

Fix:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
swift test
```

### `swift test` fails because the Xcode license is not accepted

Fix:

```bash
sudo xcodebuild -license accept
```

Then rerun:

```bash
swift test
```

### No Google Drive scopes are discovered

Check:

- Google Drive for desktop is installed
- you are signed in
- DriveFS data exists under `~/Library/Application Support/Google/DriveFS`
- there are configured roots or visible `~/Library/CloudStorage/GoogleDrive*` locations

Useful command:

```bash
swift run drive-icon-guard-scope-inventory
```

If the report is empty, include that output when opening an issue.

### The viewer opens but shows no scopes

Check:

- the CLI output first
- whether Google Drive is currently configured on the machine
- whether the report includes warnings that explain reduced discovery coverage

The viewer reflects the same underlying discovery service used by the CLI.

### Live protection still says `audit only`

That is expected in the current build.

The helper host and install scaffold are packaged, but live Google-Drive-only blocking still needs:

- a real Endpoint Security event source
- Apple-granted entitlements
- a working helper/system-extension registration flow

Useful command:

```bash
swift run drive-icon-guard-helper --status
```

### The persisted snapshot looks stale

Press `Refresh` in the viewer or rerun:

```bash
swift run drive-icon-guard-scope-inventory
```

The latest snapshot is written atomically to:

```text
cache/scope-inventory/latest.json
```

History snapshots are written to:

```text
cache/scope-inventory/history/
```

### Discovery output includes machine-specific absolute paths

That is expected for local inventory output. Public-facing docs should avoid copying those paths directly unless they are clearly marked as local examples.

## When opening an issue

Include:

- macOS version
- `xcode-select -p`
- `swift --version`
- whether you used the CLI, the viewer, or both
- the relevant warning codes or output excerpt

For setup help or usage questions, prefer the repo `Q&A` Discussions category.
