# Handover: macOS utility to prevent Google Drive folder icon artefacts

## Project summary

Build a macOS product that identifies **all Google Drive-managed locations** on a Mac and applies **narrow, process-aware icon artefact prevention** only where it is safe and supported.

This is **not** a Finder extension project.

The real problem is that Google Drive can create **folder icon artefacts on disk**. A naive detector that immediately removes them will likely create a **sync loop** if Drive recreates them. The design therefore needs:

1. **scope discovery** — identify every Google Drive-managed location
2. **mode awareness** — distinguish Stream vs Mirror vs Backup folders
3. **writer awareness** — distinguish Google Drive-originated writes from normal user activity
4. **narrow policy** — act only on high-confidence artefacts in supported scopes

---

## Problem statement

We need a macOS utility that can stop unwanted **Google Drive-generated folder icons on disk** from being created or persisting, without causing a delete/recreate loop with Drive sync.

The utility must support:

- **My Drive / Mirror**
- **My Drive / Stream**
- **additional user-selected backup folders** such as:
  - Desktop
  - Documents
  - Downloads
- **custom sync/mirror locations**
- **external drive mirror locations**
- identification of **all locations** managed by Google Drive on the machine

---

## Key conclusions from discovery

### 1. This is not a Finder extension problem
Finder extensions deal with Finder UI. They do not stop another app writing files or metadata to disk.

### 2. Blind reactive cleanup is structurally weak
A simple:
- detect artefact
- delete artefact
- Drive recreates artefact
- repeat

…will likely create a **loop**.

### 3. Scope detection from Google Drive config/state is useful, but not sufficient
Reading Google Drive config/state can help identify:
- which locations are managed by Drive
- whether the account is in **Stream** or **Mirror**
- whether extra backup folders are enabled
- whether the mirror path is on an external disk

But config alone does **not** prove who wrote a given file or metadata change.

### 4. Process-aware enforcement is required for true prevention
For a credible prevention product, the system should identify:
- the **scope**
- the **writer process**
- the **artefact type**

Only then should it allow/block/remediate.

---

## Product position

### Product goal
**Discover every Google Drive-managed location on the Mac and apply icon-artefact policy per location according to support level.**

### Honest product promise
Do **not** promise:
> “Stops all Google Drive icons everywhere.”

Promise instead:
> “Identifies Google Drive-managed locations and prevents or neutralises high-confidence Google Drive-originated icon artefacts only in supported scopes.”

---

## Supported location model

The system must inventory all Drive-managed locations, not just a single Drive root.

### Scope types to support or detect
- **My Drive / Mirror**
- **My Drive / Stream**
- **Backup folder: Desktop**
- **Backup folder: Documents**
- **Backup folder: Downloads**
- **Custom mirror location**
- **External mirror location**
- **Removable volume scopes**
- **Network volume scopes**
- **Photos library scope** (detectable, likely audit-only)

### Important note
“Drive location” is not a single value. The app must build a **scope inventory**.

---

## Stream vs Mirror

Google Drive for desktop supports at least these modes conceptually:

### Stream
- cloud-backed / File Provider style on modern macOS
- visible location may be system-managed
- harder to reason about as an actual on-disk backing location
- treat as **audit-only first**

### Mirror
- actual local folder tree
- easier to reason about
- better first target for enforcement
- includes **custom local mirror paths**, including **external drives**

### Backup folders
Drive can also manage user-selected locations like:
- Desktop
- Documents
- Downloads

These must be discovered and listed separately from My Drive.

---

## Recommended v1 product boundary

### In scope
- identify **all Drive-managed locations**
- support **external mirror first**
- support **additional user-selected backup folders**
- classify every location by:
  - scope type
  - mode
  - volume type
  - filesystem type
  - support status
- expose per-location policy:
  - Off
  - Audit only
  - Protect

### Explicitly narrow v1 enforcement
For enforcement, v1 should be strongest in:
- **Mirror mode**
- **external mirror**
- preferably **Mac-formatted volumes first** if enforcement is sensitive to filesystem behaviour

### Audit-only first for:
- Stream / File Provider scopes
- network volumes
- removable/non-native filesystems if unsafe
- Photos library related locations

---

## Scope inventory requirements

The app must identify all locations managed by Drive, including:

1. **My Drive root**
2. **mode of My Drive** (Stream or Mirror)
3. **actual mirror path** if mirrored
4. **whether the mirror path is internal or external**
5. **additional backup folders**
6. **user-selected folder locations**
7. **network/removable scopes if enabled**
8. **effective support status per scope**

### Output requirement
The UI and internal model should always be able to answer:

- What locations is Drive managing on this Mac?
- What mode is each in?
- Which are safe to enforce?
- Which are audit-only?
- Which are unsupported?

---

## Architecture

## High-level architecture

### 1. Main macOS app
Visible control plane.

Responsibilities:
- onboarding
- permissions guidance
- show discovered Drive-managed locations
- allow per-scope protection mode
- show logs/incidents
- pause/resume protection

Suggested stack:
- SwiftUI
- local persistence
- XPC client for talking to the helper/service

### 2. Scope inventory engine
Core discovery layer.

Responsibilities:
- read/derive Google Drive state and config where possible
- identify all managed locations
- detect Stream vs Mirror vs Backup
- detect external mirror paths
- classify volumes/filesystems
- persist discovered scopes

### 3. Privileged/process-aware enforcement helper
Actual policy engine.

Responsibilities:
- inspect file-related events with process attribution
- determine whether the writer is Google Drive or helper process
- evaluate whether the target path belongs to a supported scope
- evaluate whether the target is a high-confidence icon artefact
- allow / deny / remediate based on scope policy

### 4. Optional login/background component
Responsibilities:
- keep the product running as needed
- coordinate UI and helper lifecycle
- status/menu bar presence if needed

---

## Why a reactive cleaner alone is not enough

A naive cleaner based only on file change notifications will likely fail because:

- it cannot reliably distinguish Google Drive activity from user activity
- it may create a sync war
- it may repeatedly delete legitimate artefacts
- it may strip user-created custom icons

Reactive cleanup can still exist as:
- a **one-shot remediation tool**
- a **fallback mode**
- a **manual cleanup action**

But it should not be the core enforcement design.

---

## Enforcement policy design

The policy must only act when **all** of the following are true:

1. target path is inside a discovered Drive-managed scope
2. scope support status is `supported`
3. writer process matches Google Drive or a known helper
4. artefact matches a **high-confidence icon artefact rule**

If any of these fail:
- allow
- optionally log

---

## Scope support model

Each discovered scope must be classified into one of:

- `supported`
- `auditOnly`
- `unsupported`

### Examples
- External mirror on supported local filesystem -> `supported`
- Internal mirror -> `supported` or `auditOnly` depending on rollout
- Desktop/Documents backup -> likely `supported` after validation
- Stream/File Provider -> `auditOnly` first
- Network volume -> `auditOnly`
- Unknown filesystem / unstable scope -> `unsupported`

---

## Data model

```text
DriveManagedScope
- id
- accountId
- path
- scopeKind         // myDrive, backupFolder, removableVolume, networkVolume, photosLibrary
- driveMode         // stream, mirror, backup
- source            // config, inferred, confirmed
- volumeKind        // internal, external, removable, network, systemManaged
- fileSystemKind    // apfs, hfsplus, exfat, smb, other, unknown
- supportStatus     // supported, auditOnly, unsupported
- enforcementMode   // off, auditOnly, blockKnownArtefacts
```

Additional supporting models:

```text
ProcessSignature
- bundleId
- executablePath
- signingIdentity
- displayName
- isGoogleDriveRelated

ArtefactRule
- id
- name
- artefactType
- matchType
- matchValue
- confidence
- action

EventRecord
- id
- timestamp
- processSignature
- scopeId
- targetPath
- artefactType
- decision
- aggregatedCount
- rawEventType
```

---

## Candidate artefacts

Start with **very narrow** rules.

### High-confidence artefacts
- hidden `Icon\r` file
- known icon-related sidecar patterns if validated
- folder metadata writes clearly associated with custom icon state

### Do not remove/block blindly
- all hidden files
- all metadata writes
- all Finder custom icon activity
- anything outside a discovered Drive scope

---

## Anti-loop requirements

This is a core non-functional requirement.

### Rule 1
Do not rely on continuous delete/recreate as the main defence.

### Rule 2
Deduplicate repeated incidents using:
- process signature
- canonical target path
- artefact type
- time window

### Rule 3
Implement a **circuit breaker**
If the same path/artefact is repeatedly triggered:
- stop noisy repeated action
- aggregate logging
- surface one incident
- optionally pause protection for that scope until user/admin review

### Rule 4
Allow exclusions
- per path
- per scope
- per artefact type if needed

---

## Recommended modes

### Off
No logging, no enforcement.

### Audit only
- discover scope
- observe candidate artefacts
- observe process attribution
- record incidents
- no blocking

### Protect
- only in supported scopes
- only for high-confidence artefacts
- only when writer matches Drive/helper

### Remediate once
Optional manual/secondary mode:
- clean existing artefacts once
- do not stay in blind loop mode

---

## MVP build order

## Milestone 1 — Scope discovery spike
### Goal
Prove that the app can discover all Drive-managed locations.

### Tasks
- identify active Google Drive account(s) if possible
- determine whether My Drive is Stream or Mirror
- resolve actual mirror path
- detect external mirror locations
- detect backup folders such as Desktop/Documents/Downloads
- classify volume type and filesystem type
- build a persisted scope inventory

### Definition of done
- app can list every Drive-managed location found on the machine
- each scope has mode, type, path, volume, filesystem, support status
- UI can display the full inventory clearly

---

## Milestone 2 — Audit-only event prototype
### Goal
Prove process-aware event quality.

### Tasks
- observe relevant file-related events
- identify Google Drive and helper processes
- correlate events to discovered scopes
- detect candidate icon artefacts
- log incidents without enforcement

### Definition of done
- event stream correctly shows:
  - writer process
  - target path
  - matched scope
  - matched artefact rule
- false positives are acceptably low in test runs

---

## Milestone 3 — Narrow enforcement MVP
### Goal
Safely protect the highest-confidence scope/artefact combination.

### Suggested initial enforcement target
- external mirror
- known supported filesystem(s)
- exact `Icon\r` artefact rule only

### Tasks
- add protect mode to supported scopes
- block or neutralise only the narrow artefact rule
- add deduping and circuit breaker
- add user-visible incident summary

### Definition of done
- protection works in selected supported scopes
- no infinite delete/recreate loop
- user-created custom icons outside protected scopes remain untouched

---

## Milestone 4 — Backup folder protection
### Goal
Expand from mirror root to additional backup folders.

### Tasks
- enable policy evaluation for Desktop/Documents/Downloads if discovered
- validate that artefact behaviour matches expectations
- keep backup folders configurable per scope

### Definition of done
- backup folders are separately listed and separately controllable
- protection works only where explicitly enabled and supported

---

## Milestone 5 — Stream/File Provider handling
### Goal
Add support for Stream mode only after audit confidence is high.

### Tasks
- treat stream scopes separately
- resolve visible vs effective path model
- determine whether prevention is feasible or audit-only
- avoid assuming mirror-like behaviour

### Definition of done
- Stream scopes are at least discoverable and visible in UI
- enforcement is only enabled if proven safe

---

## UI requirements

The app should present a full scope inventory table.

### Example UI table

| Location | Type | Mode | Volume | Filesystem | Status | Protection |
|---|---|---|---|---|---|---|
| /Volumes/WorkSSD/Google Drive | My Drive | Mirror | External | APFS | Supported | Protect |
| ~/Desktop | Backup folder | Backup | Internal | APFS | Supported | Audit |
| ~/Documents | Backup folder | Backup | Internal | APFS | Supported | Off |
| System-managed Drive root | My Drive | Stream | System managed | Unknown | Audit only | Off |

### UX requirements
- per-scope toggle
- clear status badges
- show “why unsupported”
- show “why audit only”
- show recent incidents
- allow pause/resume globally
- allow manual one-shot cleanup per scope

---

## Repo structure suggestion

```text
DriveIconGuard/
├── App/
│   ├── UI/
│   ├── ScopeInventory/
│   ├── Logs/
│   ├── Settings/
│   └── XPCClient/
├── Helper/
│   ├── EventSubscription/
│   ├── ProcessClassifier/
│   ├── ArtefactClassifier/
│   ├── PolicyEngine/
│   ├── CircuitBreaker/
│   └── Audit/
├── Shared/
│   ├── Models/
│   ├── IPC/
│   └── Utilities/
└── Installer/
    └── ServiceRegistration/
```

---

## Core pseudocode

```swift
func handleEvent(_ event: FileEvent) {
    guard protectionEnabled else {
        allow(event)
        return
    }

    let process = processClassifier.classify(event.process)
    guard process.isGoogleDriveRelated else {
        allow(event)
        return
    }

    guard let scope = scopeInventory.matchScope(for: event.targetPath) else {
        allow(event)
        return
    }

    guard scope.supportStatus == .supported else {
        log(event, scope: scope, decision: .auditOnlyUnsupportedScope)
        allow(event)
        return
    }

    let artefact = artefactClassifier.classify(event)
    guard artefact.confidence == .high else {
        log(event, scope: scope, decision: .auditOnlyLowConfidence)
        allow(event)
        return
    }

    switch scope.enforcementMode {
    case .off:
        allow(event)

    case .auditOnly:
        log(event, scope: scope, decision: .auditOnly)
        allow(event)

    case .blockKnownArtefacts:
        let key = dedupeKey(process: process, path: event.targetPath, artefact: artefact.type)

        if circuitBreaker.isStorm(for: key) {
            log(event, scope: scope, decision: .stormSuppressed)
            denyOrPause(event, scope: scope)
            return
        }

        log(event, scope: scope, decision: .deny)
        deny(event)
    }
}
```

---

## Non-functional requirements

- Must not create an uncontrolled sync loop
- Must not act outside discovered Drive-managed scopes
- Must not remove/block generic custom icon behaviour system-wide
- Must be resilient to disconnected external drives
- Must degrade gracefully when Drive config/state cannot be fully resolved
- Must surface uncertainty honestly in UI/logs

---

## Risks

### 1. Drive config/state may vary by version
The discovery engine must tolerate partial or evolving config layouts.

### 2. Process mapping may not be stable
Helper processes may differ by release/version.

### 3. Filesystem differences matter
External storage and non-native filesystems may behave differently.

### 4. Stream/File Provider complexity
Stream mode likely needs a distinct model and should not be treated like mirror.

### 5. User-created icon conflicts
Over-broad policy will break valid custom icon use.

---

## Recommended engineering stance

### Build now
- full scope inventory
- audit-only prototype
- narrow external mirror protection
- backup folder discovery

### Do not overpromise
- universal prevention
- stream-mode enforcement parity on day one
- support for every filesystem or volume type in v1

---

## Definition of done for the handover recipient

Codex should treat the next implementation step as:

1. Build the **scope inventory system first**
2. Prove **audit-quality process + artefact correlation**
3. Add **narrow protection** only after the first two are working
4. Keep protection **per-scope**, not global
5. Treat **backup folders and external mirror locations as first-class discovered scopes**
6. Treat **Stream/File Provider as separate and higher risk**

---

## Immediate next task for implementation

### Next task
Implement **Milestone 1: Scope discovery spike**

### Output expected
- a working prototype that lists all Google Drive-managed locations found on the machine
- classification for each scope
- a simple UI or CLI output showing inventory
- persisted internal model for later enforcement work

### Minimum acceptance criteria
- detects My Drive mode
- detects mirror path if applicable
- detects external mirror root if present
- detects Desktop/Documents/Downloads backup scopes if enabled
- classifies volume kind and filesystem kind
- marks each scope as supported / auditOnly / unsupported

---

## Final instruction to Codex

Do not start with enforcement.

Start with:
- **scope inventory**
- **classification**
- **audit visibility**

Only after those are solid should enforcement be attempted.
