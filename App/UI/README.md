# UI

This folder now contains a minimal SwiftUI inventory viewer for discovered Google Drive scopes.

Current target:

- `drive-icon-guard-viewer`

Current role:

- load the current scope inventory
- persist fresh snapshots on refresh
- provide a lightweight app shell with:
  - overview
  - inventory
  - logs placeholder
  - settings placeholder
- show scope mode, support status, paths, and warnings

This is still not the final app shell, but it is now a clearer control-plane foundation for the beta app.
