# Protection Status State Transitions

This document defines the expected transition model for helper event-source and installation readiness in the current beta line.

## Event Source State (`ProtectionEventSourceState`)

### `unavailable`

Use when:

- Endpoint Security framework is not available in the build/runtime environment.
- no helper host is bundled, so event-source setup cannot begin.

### `bundled`

Use when:

- helper/event-source components are present but idle.
- no active live subscription is currently running.

### `needsApproval`

Use when:

- helper/event-source bits are present, but entitlement approval, user authorization, or system-extension lifecycle prerequisites are not yet satisfied.

### `ready`

Use only when:

- runtime preflight can create an Endpoint Security client successfully, and
- the client has an active notify/auth subscription required for live monitoring.

Do not use `ready` for static packaging-only states.

### `error`

Use when:

- runtime attempted to initialize/subscribe and failed with a concrete failure path.
- status detail should include the failing API/result code and likely root-cause bucket.

## Installation State (`ProtectionInstallationState`)

### `unavailable`

Use when:

- no bundled helper host exists, so installation is not possible.

### `bundledOnly`

Use when:

- helper host exists but install/registration resources are not packaged.

### `installPlanReady`

Use when:

- helper host exists and install scaffold resources are packaged.
- actual registration/install workflow is still not complete.

### `installed`

Use only when:

- runtime verification confirms registration/install completed successfully.
- expected helper/system-extension artifacts and runtime checks pass.

### `error`

Use when:

- install/registration was attempted and failed, or
- previously installed state regressed into an invalid/inoperable runtime state.

## Current beta contract

- embedded beta runtime must not escalate to auto-enforcement from configuration alone.
- report truthful readiness based on runtime evidence, not intended future behavior.
- prefer explicit `error` details over generic placeholders when start/install attempts fail.

## Remediation Event Status (`ProtectionRemediationStatus`)

Shared IPC payloads now carry typed remediation status rather than free-form status strings.

### `applied`

Use when cleanup completed without warnings and files were removed as expected.

### `partialFailure`

Use when cleanup removed some files but warnings or failures occurred.

### `noCandidates`

Use when cleanup was valid to run but nothing matched removal criteria.

### `unavailable`

Use when cleanup is blocked by policy or scope eligibility requirements.

### `unreadable`

Use when cleanup/dry-run cannot evaluate the target scope path due to access or path availability errors.
