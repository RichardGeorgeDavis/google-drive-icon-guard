# Roadmap

This is the short contributor-facing roadmap. For the detailed execution log and batch plan, use [next-steps-roadmap.md](./next-steps-roadmap.md).

## Near-term priorities

1. Finish the signed Xcode host and system-extension lane for Endpoint Security.
2. Implement auth-event allow/deny enforcement instead of notify-only observation.
3. Validate the packaged app plus installed helper boundary on a clean machine.
4. Validate packaged helper update/drift detection and improve support exports.
5. Keep release notes, screenshots, and support wording aligned with the shipped beta.

## If the Apple lane is blocked

Treat the real prevention path as blocked, not merely delayed.

The fallback is a background post-write cleanup helper:

- useful for beta testing
- not equivalent to true prevention
- must be described as cleanup/background guard, not blocking

## Where to help

- [Help Wanted](./help-wanted.md)
- [Open issues](https://github.com/RichardGeorgeDavis/google-drive-icon-guard/issues)
- [Detailed roadmap](./next-steps-roadmap.md)
