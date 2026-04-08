# IPC

This module defines shared protection contracts exchanged across app/client/helper boundaries.

## Current contract surface

- protection configuration (`ProtectionServiceConfiguration`)
- status snapshots (`ProtectionServiceStatusSnapshot`)
- typed remediation event payloads (`ProtectionServiceEventPayload`, `ProtectionRemediationStatus`)
- shared baseline status factory (`ProtectionStatusFactory`)
- install receipt model consumed by the client-side install verifier

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

## Current Batch 4 additions

- install lifecycle can now consume a receipt file and report verified `installed` / `error` states
- future helper commands now have a typed authorization model on the client side:
  - command identity
  - caller context
  - explicit authorization result and failure reason
- the repo now includes a local protected service endpoint that consumes these primitives end-to-end before a real XPC listener exists
- the repo now also includes an anonymous NSXPC listener/client path that exercises those same contracts over a real IPC transport

## Remaining boundary work

- promote the anonymous XPC listener into the installed helper/service registration flow
- carry the same authorization + install-state gates into that deployed listener without widening the command surface
- populate caller context from final deployment-time audit-token/code-sign evidence instead of test or in-process defaults

## Related docs

- `App/XPCClient/README.md`
- `docs/protection-status-state-transitions.md`
