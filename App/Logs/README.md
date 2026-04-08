# Logs

Contains the app-side activity and operational log presentation layer.

Current log coverage includes:

- helper install, bootstrap, reuse, fallback, and removal outcomes
- cleanup preview and apply outcomes
- protection/runtime status events
- warnings emitted during discovery and remediation
- inventory refresh activity persisted alongside snapshot history

The SwiftUI viewer now exposes:

- a dedicated Logs view with category filters
- a Recent Activity summary on the main dashboard
- backward-compatible loading of older persisted activity events that predate typed category/severity fields
