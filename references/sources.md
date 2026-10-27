# Catalog audit sources

Inspector's safety tiers and path mappings are cross-referenced against
these sources before an entry is marked `verified: true`.

## Primary sources we actively cross-reference

| Source | Why we trust it | What it verifies |
|--------|-----------------|------------------|
| [mac-cleanup-py](https://github.com/mac-cleanup/mac-cleanup-py) | Actively maintained Python cleaner that **performs** the deletions in its catalog. 5k+ stars, no outstanding issues for paths it clears. | Specific cache subpaths across browsers, dev tools, and app data. |
| [Homebrew casks `zap trash:` stanzas](https://docs.brew.sh/Cask-Cookbook) | 4,700+ community-maintained casks declare the exact paths each app leaves behind. Validated per PR by the cask author who actually uses the app. | App-owned paths — `Library/Caches/<bundle>`, `Library/Application Support/<app>`, `Library/Containers/<bundle>`, etc. Covers 60+ of our entries directly. |
| [Chromium User Data Directory](https://chromium.googlesource.com/chromium/src/+/refs/heads/master/docs/user_data_dir.md) | Official Google / Chromium project documentation. | Chrome, Chrome Canary, Chrome Beta, Chrome Dev, Chromium — all variants and the User Data layout under them. |
| [JetBrains IDE directories](https://www.jetbrains.com/help/idea/directories-used-by-the-ide-to-store-settings-caches-plugins-and-logs.html) | Official JetBrains support article. Documents exact per-product paths for caches / plugins / config / logs. | IntelliJ, PyCharm, GoLand, WebStorm, CLion, PhpStorm, RubyMine caches and logs. |

## Secondary sources

- [Pearcleaner](https://github.com/alienator88/Pearcleaner) — Swift Mac app uninstaller.
  Not used as a tier source because Pearcleaner's `Locations.swift` is a
  search roster for finding app files during uninstall, not a tiered
  safe-to-delete catalog. Useful for cross-checking that a path exists
  in the standard macOS Library hierarchy.
- [TidyMyMac](https://pkg.go.dev/github.com/viniciussouzao/tidymymac),
  [mac-cleanup-go](https://gittrend.io/repo/2ykwang/mac-cleanup-go) — Go
  cleaners. Potential tertiary cross-reference for anything still
  unverified; not currently mined.
- Each app's own documentation (Chrome / Chromium — see above; VS Code;
  Spotify; Slack; Discord; Figma; Notion). Used case-by-case.
- `NSSearchPathForDirectoriesInDomains` constants for standard Library
  subdirectory names.
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
   the entry `verified: false` until we can test the behaviour on a VM
   or find a second corroborating source.
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

## Audit methodology (how a Homebrew cask verifies an entry)

- **Exact path match.** Our entry's `relativePath` appears verbatim in
  the `zap trash:` list of at least one cask. Highest confidence.
- **Our path lives inside a cask-verified area.** The cask zaps a parent
  folder of our path (e.g. cask zaps `Library/Application Support/Code`,
  we target `Library/Application Support/Code/CachedData`). Our path is
  more conservative than the cask's.
- **Cask zaps a sub-path of ours.** The cask targets a specific child of
  our path, confirming the parent is a cleanup-relevant area.

We filter the extracted cask paths to depth ≥ 3 (or depth ≥ 2 for
dotfiles) so that broad wildcard-stripped entries like "Library" cannot
produce false matches.

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
  them as `review` even though the daemons rebuild their state. Not yet
  verified by any primary source; stay `first-draft` until spot-checked.
