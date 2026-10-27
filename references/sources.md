# Catalog audit sources

Inspector's safety tiers and path mappings are not pulled out of a hat.
This document lists the sources we cross-reference when adding, auditing,
or removing a catalog entry.

## Primary cross-reference projects

These are maintained open-source Mac cleanup tools whose path lists we
diff against our own. Agreement across sources is a strong signal that a
path is correct and that the "if removed" behaviour is well understood.

| Project | Repository | Why we trust it |
|---------|------------|-----------------|
| mac-cleanup-py | https://github.com/mac-cleanup/mac-cleanup-py | Actively maintained, modular catalog, prompts the user for destructive actions, 5k+ stars. |
| Pearcleaner | https://github.com/alienator88/Pearcleaner | Native Swift app, uses NSWorkspace / bundle identifier mapping — the same approach as our Owners.swift. Development is paused as of late 2025, so treat as a snapshot rather than a live source. |

## Secondary sources

- Each app's own documentation (Chrome user data dir, VS Code storage,
  JetBrains config dirs, Homebrew prefix layout, etc.).
- Apple's `NSSearchPathForDirectoriesInDomains` constants (standard
  Library subdirectory names).
- `launchctl print user/$UID` for sandboxed app containers.

## Sources we deliberately do NOT trust as primary

- Marketing blog posts from commercial cleaners (CleanMyMac, MacPaw).
  They promote aggressive cleanup and often tier things as "safe" to
  make the demo more impressive.
- Random "clean your Mac" blog posts without a maintained repo behind
  them.
- Reddit threads older than a year — macOS paths change between
  releases.

## Audit protocol

When adding a new entry or revisiting a tier call:

1. Find the path in at least one primary source. If none have it, mark
   the entry as unverified until we can test the behaviour on a VM.
2. If primary sources disagree on safety, default to the more conservative
   tier. mac-cleanup-py's prompt-before-delete behaviour is a good proxy:
   anything they prompt before touching gets `review` at a minimum.
3. If the path is a parent folder that also holds user data (saved games,
   recordings, VM images, backups), the entry gets `keep` even if the
   caches inside it would be safe on their own. Prefer narrowing to the
   actual cache subfolder instead.
4. Explain the "if removed" effect in terms the user will actually feel.
   "You'll have to sign in again" is weaker than "You'll be signed out
   and need to re-complete 2FA / SSO."

## Known tier debates

- **Steam** — mac-cleanup-py cleans individual safe subfolders
  (appcache, depotcache, logs, shadercache, steamapps/downloading). The
  parent `~/Library/Application Support/Steam` folder also holds the
  default install location (`SteamApps/common`) for installed games, so
  we only expose the subfolders — never the parent.
- **Dropbox cache** — modern Dropbox stores its sync cache inside the
  Dropbox folder itself (`~/Dropbox/.dropbox.cache`), not under
  `~/Library`.
- **Apple system daemon containers** (`com.apple.mediaanalysisd`,
  `com.apple.geod`, `com.apple.wallpaper.agent`) — safe to clear in
  principle, but can trigger expensive background rescans. We treat
  them as `review` even though the daemons rebuild their state.
