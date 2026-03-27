# Milestone 1: Scope Discovery And Audit Spike

This repo starts with the handover's first required implementation step: build a scope inventory system and conservative audit path before any enforcement work.

## Goal

Produce a working prototype that can:

- list discovered Google Drive-managed locations
- classify each scope by mode, volume kind, filesystem kind, and support status
- scan those scopes in audit-only mode for hidden icon artefacts
- emit structured output that can later feed a UI and persistent store

## Current scaffold boundary

The current Swift scaffold intentionally implements conservative discovery plus audit-only scanning:

- detect common Google Drive config roots on macOS
- read configured roots from DriveFS `root_preference_sqlite.db`
- confirm configured roots from per-account DriveFS `mirror_sqlite.db`
- detect visible Stream/File Provider locations in `~/Library/CloudStorage` as a fallback
- classify support status using the handover's rollout rules
- scan supported and audit-only scopes for `Icon\r` and `._*` artefacts
- capture per-scope match counts, storage impact, and sample matched paths
- persist the latest inventory snapshot to `cache/scope-inventory/latest.json`
- persist timestamped inventory history under `cache/scope-inventory/history/`
- expose a minimal SwiftUI viewer for the discovered inventory

It now covers mirror and backup roots when they are present in DriveFS root preferences and can confirm configured roots from per-account DriveFS account data. It does **not** yet parse broader non-root account state beyond those current confirmation paths.

## Next implementation steps

1. Parse deeper Google Drive state under `~/Library/Application Support/Google/DriveFS` and related roots.
2. Resolve any remaining account-specific settings not represented in the current root confirmation paths.
3. Confirm custom backup scopes and one-shot states from config/state beyond the current root databases.
4. Expand the viewer so artefact counts, bytes, scan status, and history are easier to review.
5. Add historical comparison views before any remediation or enforcement work.

## Acceptance mapping

Current scaffold status against the handover:

- `detects My Drive mode`: implemented when root preferences or Cloud Storage entries are available
- `detects mirror path if applicable`: implemented via DriveFS root preferences
- `detects external mirror root if present`: implemented via resolved path plus volume classification
- `detects Desktop/Documents/Downloads backup scopes if enabled`: implemented when present in DriveFS root preferences
- `classifies volume kind and filesystem kind`: implemented conservatively
- `marks each scope as supported / auditOnly / unsupported`: implemented
- `scans discovered scopes for hidden icon artefacts in audit-only mode`: implemented
