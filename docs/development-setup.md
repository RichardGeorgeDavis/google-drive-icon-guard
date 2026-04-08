# Development Setup

This is the shortest path from clone to a working local run.

## Prerequisites

- macOS `13.0` or newer
- full Xcode installed
- the active developer directory pointed at Xcode, not Apple Command Line Tools only

Verify the toolchain first:

```bash
xcode-select -p
swift --version
```

Expected developer directory:

```text
/Applications/Xcode.app/Contents/Developer
```

If needed:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Clone

```bash
git clone https://github.com/RichardGeorgeDavis/google-drive-icon-guard.git
cd google-drive-icon-guard
```

## First local verification

Build:

```bash
swift build
```

Run the scope inventory CLI:

```bash
swift run drive-icon-guard-scope-inventory
```

Run the viewer:

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

## What a successful first run looks like

- the CLI prints a JSON inventory report
- the repo writes `cache/scope-inventory/latest.json`
- the repo writes timestamped history files under `cache/scope-inventory/history/`
- the viewer shows discovered scopes, warnings, history, and helper readiness
- the helper status reports readiness scaffolding, not final live blocking

## Common gotcha

If `swift test` only builds and does not execute real tests, the machine is usually using Apple Command Line Tools instead of full Xcode.

Fix:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
swift test
```

If Xcode is installed but not yet accepted:

```bash
sudo xcodebuild -license accept
```

## Where to go next

- for troubleshooting: [First-run guidance and troubleshooting](./first-run-and-troubleshooting.md)
- for contribution expectations: [Contributing](../.github/CONTRIBUTING.md)
- for current repo scope and boundaries: [Milestone 1 scope discovery notes](./milestone-1-scope-inventory.md)
- for deeper architecture context: [Architecture](./architecture.md)
