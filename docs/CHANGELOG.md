# Changelog

## 2026-03-24

### Added

- standalone Git repository setup for `google-drive-icon-guard`
- public-facing `README.md` describing the beta state and intended downloadable app direction
- repo policy files:
  - Code of Conduct
  - Contributing
  - Security
  - Support
  - MIT License
- GitHub Actions macOS workflow for Swift package CI
- issue templates for bugs, feature requests, and release/setup work
- public launch checklist
- current progress handover

### Implemented

- Swift Package scaffold for the scope inventory work
- shared data models for scopes, process signatures, artefact rules, and events
- scope discovery CLI: `swift run drive-icon-guard-scope-inventory`
- minimal SwiftUI viewer: `swift run drive-icon-guard-viewer`
- expanded SwiftUI app shell with overview, inventory, logs placeholder, and settings placeholder
- DriveFS root preference parsing from `root_preference_sqlite.db`
- fallback discovery of visible `~/Library/CloudStorage/GoogleDrive*` stream roots
- scope classification by mode, scope kind, volume kind, filesystem kind, and support status
- persisted inventory snapshots written to `cache/scope-inventory/latest.json`
- persisted inventory history written to `cache/scope-inventory/history/`

### Documentation

- moved the original product handover into `docs/`
- added Milestone 1 notes describing the current implementation boundary
- clarified the testing caveat around full Xcode versus Command Line Tools
- updated docs to reflect that full Xcode testing now works on the maintainer machine
- aligned docs around public beta positioning

### Cleanup

- removed tracked icon option image assets from Git history going forward
- ignored `icon-options/` and `icon options/`
- kept generated cache output ignored from version control
