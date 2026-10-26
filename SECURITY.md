# Security Policy

## Supported versions

Only the latest release of Inspector is actively supported.

## Reporting a vulnerability

If you discover a security issue, please email **sadiqkhan795@gmail.com**
with details. Do not open a public issue for security problems.

You can expect:

- Acknowledgement within 72 hours.
- A fix or mitigation plan within 7 days for high-severity issues.
- Credit in the release notes if you'd like.

## Scope

Inspector runs entirely locally. Reportable issues include:

- Any case where Inspector removes something it marked `safe` that was not safe.
- Any path traversal or arbitrary file write / delete outside the user's own directories.
- Any undisclosed network traffic (there should be none).
