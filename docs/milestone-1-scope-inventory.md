# Milestone 1: Scope Discovery Spike

This repo starts with the handover's first required implementation step: build a scope inventory system before any enforcement work.

## Goal

Produce a working prototype that can:

- list discovered Google Drive-managed locations
- classify each scope by mode, volume kind, filesystem kind, and support status
- emit structured output that can later feed a UI and persistent store

## Current scaffold boundary

The current Swift scaffold intentionally implements only conservative discovery:

- detect common Google Drive config roots on macOS
- read configured roots from DriveFS `root_preference_sqlite.db`
- confirm configured roots from per-account DriveFS `mirror_sqlite.db`
- detect visible Stream/File Provider locations in `~/Library/CloudStorage` as a fallback
- classify support status using the handover's rollout rules
- persist the latest inventory snapshot to `cache/scope-inventory/latest.json`
- persist timestamped inventory history under `cache/scope-inventory/history/`
- expose a minimal SwiftUI viewer for the discovered inventory

It now covers mirror and backup roots when they are present in DriveFS root preferences and can confirm configured roots from per-account DriveFS account data. It does **not** yet parse broader non-root account state beyond those current confirmation paths.

## Next implementation steps

1. Parse deeper Google Drive state under `~/Library/Application Support/Google/DriveFS` and related roots.
2. Resolve any remaining account-specific settings not represented in the current root confirmation paths.
3. Confirm custom backup scopes and one-shot states from config/state beyond the current root databases.
4. Feed the persisted inventory into later UI and helper consumption paths.
5. Expand the current SwiftUI viewer into a richer operator-facing presentation layer.

## Acceptance mapping

Current scaffold status against the handover:

- `detects My Drive mode`: implemented when root preferences or Cloud Storage entries are available
- `detects mirror path if applicable`: implemented via DriveFS root preferences
- `detects external mirror root if present`: implemented via resolved path plus volume classification
- `detects Desktop/Documents/Downloads backup scopes if enabled`: implemented when present in DriveFS root preferences
- `classifies volume kind and filesystem kind`: implemented conservatively
- `marks each scope as supported / auditOnly / unsupported`: implemented
