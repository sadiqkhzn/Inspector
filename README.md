<p align="center">
  <img src="docs/assets/icon.png" width="128" height="128" alt="Inspector app icon">
</p>

# Inspector

**See what macOS hides.**

[![download](https://img.shields.io/github/v/release/sadiqkhzn/Inspector?label=download&color=blue)](https://github.com/sadiqkhzn/Inspector/releases/latest/download/Inspector-0.3.1.dmg)
![platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![tests](https://img.shields.io/badge/tests-47%20passing-brightgreen)

A native Mac app that shows you what's eating your disk, slowing your boot, and watching you — and lets you decide what to do. No scary scanner, no subscription, no cloud, no AI.

Built because the "95GB of System Data" screen in macOS Settings should not be the end of the conversation.

## Download

**[Inspector 0.3.1 for macOS (.dmg, 2.5 MB)](https://github.com/sadiqkhzn/Inspector/releases/latest/download/Inspector-0.3.1.dmg)**

### Install

1. Open the `.dmg`. A Finder window opens with `Inspector.app` on the left and an `Applications` shortcut on the right.
2. Drag `Inspector.app` onto the `Applications` shortcut.
3. Eject the mounted disk from Finder's sidebar.
4. Open **Applications** and double-click **Inspector**.

### First launch (the "Apple could not verify" dialog)

Inspector is signed ad-hoc because there isn't a paid Apple Developer certificate on it yet, so macOS 15 Sequoia and newer block the first launch. This is a one-time step — once you've allowed it, every subsequent double-click opens Inspector normally.

1. The first time you open Inspector you'll see **"Inspector" Not Opened** — *"Apple could not verify "Inspector" is free of malware that may harm your Mac or compromise your privacy."* Click **Done**. (Not *Move to Bin*.)
2. Open **System Settings → Privacy & Security**.
3. Scroll all the way to the bottom to the **Security** section. You'll see a line that reads *"Inspector" was blocked to protect your Mac*.
4. Click **Open Anyway** next to it.
5. A second dialog pops up — *"Open 'Inspector'?"* with the same warning text. Click **Open Anyway** again.
6. macOS asks for your password or Touch ID. Confirm.
7. Inspector opens.

macOS remembers this choice. From now on, double-clicking Inspector in Applications opens it directly, no dialogs.

If you'd rather skip the System Settings walk, one Terminal command does the same thing:

```
xattr -dr com.apple.quarantine /Applications/Inspector.app
```

Then just double-click Inspector in Applications.

### Checksum

SHA-256 of `Inspector-0.3.1.dmg`:

```
5c90732e24b9000d975e093e4a1c6ff27670ce1612ac186f1b4d2192d2d7a1f5
```

All releases: [github.com/sadiqkhzn/Inspector/releases](https://github.com/sadiqkhzn/Inspector/releases).

## What's in v0.3.1

- **Storage** — ~185 catalog entries across caches, logs, dev-tool artefacts and installer leftovers. Each entry carries a safety tier (safe / review / keep), a plain-English explanation, and a provenance tag — `Verified` means cross-referenced against a primary source, `First-draft` means it hasn't been. Deletes go to the Trash and can be restored.
- **Boot** — scans `~/Library/LaunchAgents`, `/Library/LaunchAgents` and `/Library/LaunchDaemons`, grouped by developer. Each row shows the signer name taken from the executable's code signature and a plain schedule (`Every hour`, `Daily at 3:00`, `Mondays at 9:30`). Enabled items whose executable is unsigned get an `Unsigned` chip.
- **Permissions** — reads both TCC databases (requires Full Disk Access). One row per app with its real icon and a strip of System Settings glyphs for the permissions it holds. `By App` / `By Permission` toggle, `All / Sensitive / Allowed / Denied` filter, per-service deep-link into the right System Settings pane.
- Icon tabs in the toolbar, `⌘F` focuses search, `⌘R` rescans the active tab.
- 47 unit tests covering the catalog, env-var resolver, Boot plist parsing, Permissions tier logic, and the TCC SQLite parser.

## Principles

- **Clarity over cleanup.** Show what's there, in English, with a safety tier.
- **You decide.** Nothing is removed until you check a box and press a button.
- **Local only.** No network, no telemetry, no accounts, no AI.
- **No shell execution.** Everything happens through system APIs — no `codesign`, no `launchctl`, no `rm`.
- **Honest.** No "URGENT 97% FULL" scare tactics.

## Full Disk Access

The Permissions tab reads macOS's TCC privacy database, which lives under system-protected paths. To use it, grant Inspector **Full Disk Access** in **System Settings → Privacy & Security → Full Disk Access**. The Storage and Boot tabs work without it.

## Build from source

```bash
git clone https://github.com/sadiqkhzn/Inspector
cd Inspector
brew install xcodegen
xcodegen generate
open Inspector.xcodeproj
```

Minimum target: macOS 14 (Sonoma). Run the test suite with `xcodebuild test -scheme Inspector -destination 'platform=macOS'`.

## Roadmap

- [x] v0.1 — Storage view
- [x] v0.2 — Boot view (user agents, system agents, system daemons)
- [x] v0.3 — Permissions view (TCC database inspection)
- [ ] v0.4 — Menu bar companion for quick scans
- [ ] v1.0 — Notarised `.dmg` with a paid Apple Developer certificate

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for scope, PR conventions, and catalog entry guidelines. All contributors are expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

MIT. See [LICENSE](LICENSE).
