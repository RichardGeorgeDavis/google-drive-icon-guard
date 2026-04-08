# Contributing

Thanks for contributing to Google Drive Icon Guard.

This repository is currently focused on discovery, classification, and safety groundwork for a macOS app that can make Google Drive icon artefacts visible and manageable.

If you are new to the repo, start here before reading the longer implementation ledger:

- [Current state](../docs/current-state.md)
- [Architecture](../docs/architecture.md)
- [Roadmap](../docs/roadmap.md)
- [Help wanted](../docs/help-wanted.md)

## Before you start

Open an issue before starting broad architectural changes, major policy changes, or large UI shifts.

For local setup, use [docs/development-setup.md](../docs/development-setup.md).

Please keep pull requests focused and explain:

- the problem being solved
- the change being made
- how you verified it

## Ways to help

### Normal code contributions

- discovery and classification improvements
- README and docs improvements
- safety model refinements
- CLI and persistence improvements
- app scaffolding and UI groundwork

### High-value testing help

- packaged `/Applications` build validation
- helper install/update/remove lifecycle validation
- release-note and screenshot accuracy checks
- clean-machine reproduction of install or startup failures

### Apple platform help

The project is actively looking for help with:

- Apple Developer Program access or sponsorship
- Endpoint Security entitlement approval
- Xcode host/system-extension setup
- signed-build and on-device approval validation

If you can help with that external platform lane, say so explicitly in the issue or PR description.

## Verification

Use these commands for normal repo verification:

```bash
swift build
swift run drive-icon-guard-scope-inventory
swift test
```

If your machine only has Apple Command Line Tools, install full Xcode and point `xcode-select` at it so `swift test` can run real assertions.

## Pull requests

- avoid unrelated cleanup in the same PR
- update docs when behavior changes
- include exact verification steps in the PR body
- keep changes scoped enough to review cleanly

## Support and issue routing

- feature and product direction: use GitHub issues
- Apple platform or entitlement help: use GitHub issues and mention that clearly in the title/body
- troubleshooting/support: start with [SUPPORT.md](./SUPPORT.md)

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](../LICENSE).
