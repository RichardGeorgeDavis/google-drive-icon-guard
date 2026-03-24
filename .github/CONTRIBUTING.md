# Contributing

Thanks for contributing to Google Drive Icon Guard.

This repository is currently focused on discovery, classification, and safety groundwork for a macOS app that can make Google Drive icon artefacts visible and manageable.

## Before you start

Open an issue before starting broad architectural changes, major policy changes, or large UI shifts.

Please keep pull requests focused and explain:

- the problem being solved
- the change being made
- how you verified it

## Good contribution targets

- discovery and classification improvements
- README and docs improvements
- safety model refinements
- CLI and persistence improvements
- app scaffolding and UI groundwork

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

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](../LICENSE).
