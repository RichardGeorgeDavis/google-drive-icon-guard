# IPC

This module defines shared protection contracts exchanged across app/client/helper boundaries.

## Current contract surface

- protection configuration (`ProtectionServiceConfiguration`)
- status snapshots (`ProtectionServiceStatusSnapshot`)
- typed remediation event payloads (`ProtectionServiceEventPayload`, `ProtectionRemediationStatus`)
- shared baseline status factory (`ProtectionStatusFactory`)

## Contract design rules

- prefer typed enums over stringly status fields
- keep payloads additive/backward-compatible for beta clients
- avoid embedding privileged assumptions in shared models
- keep status values descriptive and tied to runtime evidence

## Boundary hardening expectations

Before introducing a privileged service endpoint, ensure:

1. request provenance is verified (audit token + code-sign checks)
2. all incoming payloads are schema-validated and bounds-checked
3. high-risk operations require explicit authorization gates
4. denied requests map to explicit error/status signals

## Related docs

- `App/XPCClient/README.md`
- `docs/protection-status-state-transitions.md`
