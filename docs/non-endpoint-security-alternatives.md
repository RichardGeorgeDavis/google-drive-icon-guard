# Non-Endpoint-Security alternatives (and why they are not equivalent)

This page captures common “think outside the box” ideas for stopping Google Drive from creating or propagating invisible macOS icon artefacts such as `Icon\r` and `._*`.

It also explains why these approaches are **not equivalent** to the Endpoint Security lane when the product goal is:

- pre-write prevention (deny before the file hits disk)
- process-aware enforcement (only target Google Drive / DriveFS, not Finder or everything)
- closed-app operation (still active when the UI app is not running)

Endpoint Security (ES) is the Apple-supported mechanism for that combination on modern macOS. Anything below is either reactive, indirect, or relies on Drive behaviour that cannot be assumed across machines.

## What Endpoint Security uniquely provides

With a signed ES-capable host (ideally a system extension) and the restricted entitlement `com.apple.developer.endpoint-security.client`, a host can:

- observe file activity with process attribution
- evaluate auth events before completion
- respond allow/deny (true prevention)

Without ES, this repo can still be valuable as an audit and cleanup tool, but it cannot truthfully claim “Google-Drive-only closed-app blocking”.

## Alternatives people commonly suggest

### 1. “Just watch the filesystem and delete the files”

**Idea**

- Use FSEvents / DispatchSource / polling to detect `Icon\r` and `._*` after they appear, then delete them.

**Why it’s not equivalent**

- it is **post-write cleanup**, not prevention
- there is an unavoidable race: the file exists long enough to be noticed and potentially synced
- deletes can trigger additional sync churn and repeated retries

**Where it can still help**

- background cleanup for narrow, confirmed Drive-managed roots
- inventory and reporting (which roots are producing artefacts, at what rate)

### 2. “Run a periodic sweep instead of live watching”

**Idea**

- Run a LaunchAgent helper that scans on a schedule and removes artefacts.

**Why it’s not equivalent**

- artefacts exist between sweeps
- if Drive reintroduces them quickly, this becomes an endless churn loop
- sweeps can be expensive on large trees and may harm perceived performance

### 3. “Ask for Full Disk Access / more permissions”

**Idea**

- Request Full Disk Access (FDA) or other permissions so the app can see/modify more files.

**Why it’s not equivalent**

- permissions improve visibility and ability to delete, but **do not grant** the ability to deny another process’s file operation before it completes
- process-aware allow/deny remains unavailable

### 4. “Make the artefacts immutable / unwritable so Drive can’t create them”

**Idea**

- Use `chflags uchg`, ownership/permission tricks, ACLs, or “lock” files to prevent writes.

**Why it’s not viable**

- it is not reliably scoped to “only Google Drive”; it can break Finder and normal apps too
- Drive may treat this as a sync error and retry indefinitely, increasing churn
- it is easy to create a local machine state that other Macs cannot replicate safely

### 5. “Precreate `Icon\r` everywhere so Drive thinks icons already exist”

**Idea**

- Seed placeholder `Icon\r` files (or `._*`) to “satisfy” Drive.

**Why it’s not viable**

- it explodes the number of artefacts by design (the opposite of the objective)
- `Icon\r` is not a general “presence marker”; it is part of a Finder custom-icon representation and can be rewritten/duplicated unpredictably
- Drive’s behaviour varies by version and context; you cannot depend on a stable “already exists, therefore don’t touch it” rule

### 6. “Strip custom icon metadata so `Icon\r` never appears”

**Idea**

- Remove the Finder custom-icon bit and related metadata (xattrs/resource fork) in Drive-managed roots so there is nothing to preserve.

**Why it’s not universally acceptable**

- this prevents the churn by removing the cause, but it also removes legitimate custom icons
- some folders or vendor-provided content intentionally ships with custom icons and users may want to keep them

**Safer framing**

- this can be offered as an **opt-in** “sanitise icons in Drive roots” action, possibly with per-folder allowlisting

### 7. “Allowlist custom icons, and auto-restore them if Drive overwrites”

**Idea**

- Keep a canonical icon source (e.g. `.icns` stored alongside or in an app-managed cache) and reapply icon metadata when it drifts.

**Why it’s not equivalent**

- still reactive: Drive can overwrite, then the helper restores later
- it can create a constant tug-of-war and additional filesystem churn
- it is hard to make strong guarantees across volumes, Drive versions, and multi-Mac setups

**Where it can still help**

- “icons usually look right” UX for a small curated set of folders

### 8. “Use Drive settings / ignore rules / exclude patterns”

**Idea**

- Configure Drive to not sync hidden files, or exclude certain patterns/paths.

**Why it’s limited**

- availability and behaviour varies; there is no reliable cross-user mechanism that this project can assume exists
- it doesn’t help if the artefacts are created inside content that must remain synced

## Summary: what’s shippable without ES

Without the Endpoint Security lane, the honest, valuable product surface is:

- audit and inventory of Drive-managed roots
- support diagnostics and reproducible reporting
- narrow cleanup/remediation in confirmed Drive-managed scopes
- optional “metadata sanitise” tools with clear trade-offs

Anything described as “blocking” must be framed as **post-write cleanup** unless and until the ES-capable host + entitlement lane is real and validated on device.

