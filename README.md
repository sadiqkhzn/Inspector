# Inspector

**See what macOS hides.**

![platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![status](https://img.shields.io/badge/status-early-orange)

A native Mac app that shows you what's eating your disk, slowing your boot, and watching you — and lets you decide what to do. No scary scanner, no subscription, no cloud, no AI.

Built because the "95GB of System Data" screen in macOS Settings should not be the end of the conversation.

## Status

Early. v0.1 ships the **Storage** view: known cache locations, installer leftovers, and dev tool cruft with a plain-English explanation and a safety tier for each.

Planned:
- v0.2 — **Boot** view: every login item, LaunchAgent, and LaunchDaemon in one list
- v0.3 — **Permissions** view: which apps have mic / camera / screen access and when they used it

## Principles

- **Clarity over cleanup.** Show what's there, in English, with a safety tier.
- **You decide.** Nothing is removed until you check a box and press a button.
- **Local only.** No network, no telemetry, no accounts, no AI.
- **No sudo.** Only touches files in your user library.
- **Honest.** No "URGENT 97% FULL" scare tactics.

## Build

Open the folder in Xcode:

1. `File > New > Project > macOS App`
2. Product name: `Inspector`
3. Interface: SwiftUI, Language: Swift
4. Save it to this directory, overwriting the default `Inspector/` sources with the ones already here
5. Build & run (⌘R)

Minimum target: macOS 14 (Sonoma).

## License

MIT. See `LICENSE`.

## Build

Open `Inspector.xcodeproj` in Xcode 15 or later and run with ⌘R.
Minimum target: macOS 14 (Sonoma).

If you don't yet have an `.xcodeproj`, create one via `File > New > Project > macOS App`,
name it `Inspector`, and drop the files from `Inspector/` into the target.

## Roadmap

- [x] v0.1 — Storage view
- [ ] v0.2 — Boot view (login items + LaunchAgents + LaunchDaemons)
- [ ] v0.3 — Permissions view (TCC database inspection)
- [ ] v0.4 — Menu bar companion for quick scans
- [ ] v1.0 — Signed .dmg release

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for scope, PR conventions, and catalog
entry guidelines. All contributors are expected to follow the
[Code of Conduct](CODE_OF_CONDUCT.md).
