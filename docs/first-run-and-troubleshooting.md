# First-Run Guidance And Troubleshooting

This guide covers the **current beta/development state** of Google Drive Icon Guard.

Right now the repo provides:

- a scope discovery CLI
- a lightweight SwiftUI app shell with an inventory view
- persisted inventory snapshots under `cache/scope-inventory/latest.json`
- timestamped history snapshots under `cache/scope-inventory/history/`

It does **not** yet install a privileged helper or ship the final downloadable app flow.

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

Run tests:

```bash
swift test
```

## What to expect on first run

- the CLI should print a JSON inventory report
- the CLI should persist the latest snapshot to `cache/scope-inventory/latest.json`
- the CLI should also write a timestamped history snapshot under `cache/scope-inventory/history/`
- the viewer should load discovered scopes, warnings, and the persisted path
- the current implementation should discover configured DriveFS roots when available

## Current permissions

At the current Milestone 1 stage, the repo should not require special macOS privacy permissions just to run the discovery CLI or viewer.

The current code reads Google Drive state from the user account’s DriveFS data and presents the resulting inventory. That is different from the later helper/enforcement work, which is not implemented yet.

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
