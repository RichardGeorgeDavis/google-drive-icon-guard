# Public Launch Checklist

Use this checklist before making `google-drive-icon-guard` public or announcing a beta release.

## Repo basics

- confirm the README reflects the current state of the project
- keep the repo positioned as a beta until the app and safety model are proven
- confirm the repo includes contribution, support, conduct, security, and license files
- verify no sensitive data, internal-only notes, or private URLs are committed

## Public beta readiness

- confirm the repo is useful even before the final app is shipped
- make sure the current CLI and scope-inventory work are clearly explained
- state plainly what is implemented today versus what is still planned
- avoid promising enforcement behavior that does not exist yet

## Release and download readiness

- decide how beta releases will be distributed
- add a release section to the README when a real downloadable app artifact exists
- document minimum macOS version for the beta
- document whether the beta is unsigned, signed, or notarized
- publish checksum + provenance files with the downloadable archive
- document what the bundled helper host and install scaffold do today versus what is still not implemented
- add basic install and first-run instructions for the beta app
- test the beta packaging script before announcing the release

## Documentation polish

- add at least one screenshot when the app UI is ready
- add a short demo or GIF if the UI becomes easier to explain visually
- keep the handover and milestone docs current as implementation moves forward
- avoid machine-specific absolute paths in public-facing documentation unless clearly marked as examples

## GitHub setup

- push the repo to GitHub
- enable Discussions if you want Q&A support
- add a `Q&A` category in Discussions
- keep issue templates focused and low-noise
- make sure CI is green on the default branch
- make sure the packaging smoke lane is green on the default branch

## Before asking people to try it

- land a few obvious polish fixes first
- open a few small, legitimate issues for the next milestones
- test the CLI and app flow on a clean machine if possible
- test the packaged helper `--status` output on a clean machine if possible
- verify the repo still builds after switching to full Xcode

## Suggested first public issues

- Improve the viewer presentation for per-scope artefact counts, bytes, and scan status
- Deepen historical snapshot comparison beyond the current top-line delta view
- Replace replay-only helper input with a real Endpoint Security event source
- Turn helper install scaffolding into a real install/registration path
- Add viewer screenshots for the public beta README
- Validate the signed/notarized release lane with real Apple credentials
