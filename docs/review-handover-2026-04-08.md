# Review Handover 2026-04-08

This note reviews the current uncommitted Cursor worktree on top of `main` and turns it into a concrete next-step plan.

## Follow-up status from later 2026-04-08 work

The issues called out in findings 1 through 5 were addressed in subsequent repo work:

- monitor shutdown behavior was fixed and regression-covered
- beta artifact verification was repaired and exercised by the packaging lane
- the documented live Endpoint Security integration entrypoint was made callable from the embedding target
- preflight status semantics were moved away from misleading hard-failure reporting
- app-side LaunchAgent helper lifecycle controls were added
- persisted helper configuration restore for the installed helper path was added

That means this review should now be read mainly as background context for how the repo reached its current state. The immediate next product step is no longer helper UX hardening. It is the signed Xcode Endpoint Security host and entitlement lane required for true Google-Drive-only live blocking while the app is closed.

## Repo state at review time

- branch: `main`
- local branch is ahead of `origin/main` by 1 commit
- working tree includes modified tracked files plus new helper/tests/release files
- package validation at review time: `swift test` passes with `49` tests

## What Cursor changed

### Endpoint Security scaffolding

- added callback bridge and mapper layers:
  - `Helper/EventSubscription/EndpointSecurityCallbackBridge.swift`
  - `Helper/EventSubscription/EndpointSecurityEventMapper.swift`
- expanded `EndpointSecurityProcessAttributedEventSubscriber` with:
  - raw callback event conversion
  - create/rename/unlink target-path extraction
  - runtime dispatch helpers
  - preflight-oriented status transitions
- added installer guidance/example material:
  - `Installer/EndpointSecurity/README.md`
  - `Installer/EndpointSecurity/entitlements.example.plist`
- added Xcode integration guidance in `docs/endpoint-security-xcode-integration.md`

### Embedded protection and inventory/runtime behavior

- centralized default status creation in `ProtectionStatusFactory`
- introduced typed remediation status in shared IPC models
- changed embedded protection payloads to use typed status values
- normalized embedded beta configuration away from live blocking
- changed embedded event-source reporting away from `.ready`
- added refresh coalescing in `ScopeInventoryViewModel`
- added adaptive backoff/jitter and scope-change-triggered reevaluation in `ScopeEnforcementMonitor`
- hardened remediation path validation in `ScopeRemediationPlanner`
- improved Google Drive process classification using signing identity and bundle identifier heuristics

### CI, packaging, and release checks

- added workflow concurrency, timeout, and cache configuration
- changed package CI to run `swift test --parallel`
- expanded beta build packaging to emit checksum files
- added `Tools/release/verify-beta-artifacts.sh`
- updated `Tools/release/build-beta-app.sh` to run artifact verification

### Test additions

- added coverage for callback bridge and mapper behavior
- added coverage for embedded client installation-state/status behavior
- added monitor cooldown/stop regression coverage

## Review findings

### 1. `stop()` does not actually stop enforcement

File: `App/ScopeInventory/ScopeEnforcementMonitor.swift`

`stopNow()` clears the timer and callback, but it leaves `trackedScopes` intact and `evaluate()` still calls `engine.enforce(...)` even when no handler is present. A later `updateScopes(...)` or `evaluateNow()` after `stop()` can still delete artefacts on disk. The new test only checks callback suppression, not that cleanup stops.

Impact:

- hidden filesystem mutation after shutdown
- misleading test coverage
- unsafe behavior if the client is stopped and later receives stale scope updates

### 2. Beta artifact verification script is broken

File: `Tools/release/verify-beta-artifacts.sh`

The JSON validation block uses:

```sh
echo "${STATUS_JSON}" | python3 - <<'PY'
```

The heredoc provides Python's stdin, so the piped JSON never reaches `json.load(sys.stdin)`. The parser reads EOF and fails. I reproduced this pattern directly during review and it throws `JSONDecodeError`.

Impact:

- `Tools/release/build-beta-app.sh` now invokes a verification step that can fail even when artifacts are valid
- release automation claims in the docs overstate current readiness

### 3. The documented ES integration entrypoint is not actually exposed

Files:

- `Helper/EventSubscription/EndpointSecurityProcessAttributedEventSubscriber.swift`
- `docs/endpoint-security-xcode-integration.md`

The doc says downstream Xcode code should call `subscriber.handleLiveEndpointSecurityMessage(message)`, but that method is `private`. A consuming app/system-extension target cannot call it as documented.

Impact:

- the current handover instructions are not directly executable
- the next ES runtime slice is blocked until visibility/API shape is corrected

### 4. ES start status semantics are currently misleading

File: `Helper/EventSubscription/EndpointSecurityProcessAttributedEventSubscriber.swift`

On macOS builds with Endpoint Security available, `start(eventHandler:)` sets status to `.error` even when the preflight bridge dispatch succeeds. That makes "not wired yet" look like a runtime failure and the new tests were adjusted to accept that state.

Impact:

- confusing operator/UI state
- weakens the value of runtime status as a handover/debugging signal

## Validation notes

- `swift test` is currently green with `49` passing tests
- the passing suite does not cover the post-`stop()` no-mutation guarantee
- the release verification shell bug was reproduced directly outside the package tests

## Recommended next steps

1. Build the signed Xcode host or system-extension target that links `EndpointSecurity.framework`.
2. Attach the approved `com.apple.developer.endpoint-security.client` entitlement and signing profile.
3. Validate real `es_new_client` / `es_subscribe` callback delivery into the existing runtime coordinator.
4. Prove the installed helper boundary stays armed through that live path while the app is closed.
5. Then rerun packaged clean-machine validation and signing/notarization checks against the real live lane.

## Suggested execution plan

### Phase 1: complete the live Endpoint Security host lane

- create or adopt the signed Xcode host target
- attach the approved entitlement and provisioning profile
- validate live create/rename/unlink callback delivery under real traffic

### Phase 2: prove closed-app helper continuity

- keep the installed helper armed through the named Mach-service boundary
- confirm the app can exit while protection state remains available through the host lane
- keep the shipped product claim at audit-first until this path is proven

### Phase 3: release hardening against the real live path

- rerun packaged install/bootstrap/reconnect validation on a clean machine
- validate signing/notarization and release asset attachment
- only then consider broadening the public beta promise toward true prevention
