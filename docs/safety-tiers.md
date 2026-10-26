# Safety tiers

Every catalog entry falls into one of three tiers.

## Safe

The item is a cache or an installer leftover that is **rebuilt automatically**
or **has no effect on the app's behavior** once removed. Removing a Safe item
should never cost the user anything meaningful.

Examples: Chrome browser cache, pip download cache, Homebrew formula cache.

## Review

The item has **real state** — logs, session tokens, project caches with
measurable rebuild time. Removing it is usually fine but the user should know
the trade-off.

Examples: Zoom session data (you sign in again), iOS DeviceSupport (symbols
re-download), Playwright browser binaries (re-install needed).

## Keep

The item holds **user data or working state**. Removing it has a cost the
user may not want to pay. Inspector surfaces it for visibility but recommends
against removal unless the user is sure.

Examples: Docker Desktop data, VS Code workspace storage with unsaved edits.

## Honesty rule

If a safety level is ambiguous, default to `.review`. Inspector is a tool for
clarity, not for aggressive cleanup.
