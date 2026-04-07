# Next Steps Roadmap

This roadmap captures immediate engineering priorities and project expansion opportunities.

## 30/60/90 day plan

### 30 days (stabilize + measure)

- complete Xcode live ES runtime wiring and verify callback-path correctness under real traffic
- add performance telemetry for refresh latency, monitor cycle interval, and remediation execution time
- split CI into fast unit lane vs filesystem/integration lane for faster PR feedback
- define release trust gate checklist (checksum, signing, notarization, provenance)

### 60 days (harden + scale)

- ship authenticated app-helper/service boundary with caller verification and method authorization
- move install lifecycle from scaffold to verified runtime states (`installed`, `error`)
- add structured diagnostics pipeline (failure taxonomy + user-safe troubleshooting bundle)
- optimize scope scan and remediation reuse with incremental scanning where possible

### 90 days (expand capability)

- add policy profiles (audit-only, suggested, strict) with per-scope override support
- add operator-facing readiness center (entitlements, install, approval, event health)
- add machine-readable exports for fleet automation and support tooling
- prepare signed public beta lane with rollback + kill-switch controls

## Immediate engineering priorities

1. Complete Endpoint Security runtime bridge
   - wire `es_new_client` callback ingestion in the Xcode-linked runtime lane
   - validate rename/create/unlink conversion semantics against real payloads
   - route mapped events through `HelperProtectionService` in a signed entitlement path
2. Implement helper/system-extension install lifecycle
   - move from `installPlanReady` to verified runtime install states
   - emit `installed` and `error` from real checks
3. Document and enforce authenticated app-helper boundary
   - finalize audit-token and code-signature validation requirements
   - enforce per-method authorization checks at boundary ingress
4. Improve operational diagnostics
   - structured, privacy-safe runtime logs for startup/subscription/conversion failures
5. Sign/notarize beta release lane
   - add codesign/notarization checks as release gates
   - publish signed checksums and release provenance metadata

## Performance optimization track

### Runtime targets

- keep median `refresh()` orchestration time below 150ms for unchanged environments
- maintain adaptive monitor idle intervals with low CPU wakeups and bounded recovery time on change
- reduce repeated disk reads/writes in activity and snapshot paths

### Planned improvements

- introduce explicit background refresh coordinator so report generation/persistence work stays off the UI path
- add scan cache invalidation keyed by scope path + modification timestamps
- batch activity-log persistence on short intervals during event bursts
- add benchmark fixtures for scanner/remediation hot paths

### Success metrics

- 30% reduction in CI median runtime
- 25% reduction in local refresh wall-clock under unchanged scope data
- no deterministic test regressions in monitor cooldown/reentrancy contracts

## Expansion opportunities

### Safety and rollout controls

- add global + per-scope feature flags for protection behavior
- add dry-run-only enforcement mode that records would-block outcomes
- keep an emergency kill switch for live protection paths

### Discovery and classification depth

- deepen DriveFS account-state parsing beyond current root-focused reads
- add confidence scoring to discovered scopes (`confirmed`, `inferred`, `uncertain`)
- improve edge-case handling for custom backup and mixed-volume setups

### UX and operator workflow

- add a Protection Readiness view (entitlements, install, approval blockers)
- add guided permission recovery and one-click troubleshooting exports
- add clearer per-scope risk/recommendation wording for beta users

### Release and operations maturity

- add signing/notarization execution plan and preflight checklist
- publish machine-readable JSON findings export for automation
- add CI artifact verification summaries for every beta packaging run

### Plugin/product expansion

- add extension points for custom artefact rules loaded from signed rule bundles
- support additional cloud-sync providers via provider adapters
- expose a documented automation interface for enterprise policy management
- add optional remediation approval workflows (manual gate, scheduled window, dry-run-to-apply)

## Recommended execution order

1. ES callback extraction and conversion wiring in the Xcode runtime lane
2. Install/registration runtime path with state transitions
3. Authenticated app-helper boundary enforcement
4. Signing/notarization and release-trust pipeline
5. Public beta polish and operator workflows

## Xcode live ES client

SwiftPM builds do not link `EndpointSecurity.framework`. Add an Xcode app or system extension target, link the framework, apply entitlements, and wire `handleLiveEndpointSecurityMessage` as documented in [endpoint-security-xcode-integration.md](./endpoint-security-xcode-integration.md). Example entitlements: `Installer/EndpointSecurity/entitlements.example.plist`.
