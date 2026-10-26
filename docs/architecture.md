# Architecture

Inspector is a small SwiftUI app with one responsibility: show the user
what macOS hides, and let the user decide.

## Layers

- **Models** (`Models.swift`) — plain value types. `SafetyLevel`, `ScanCategory`,
  `CleanupItem`, `DiskSnapshot`. No logic.
- **Catalog** (`KnownItems.swift`) — a static array of `KnownItemSpec`. Each spec
  describes one known location on disk, its safety tier, and plain-English
  explanations. The catalog is the entire "knowledge base" of the app.
- **Scanner** (`Scanner.swift`) — stateless. Iterates the catalog, resolves each
  path, computes directory size, and builds `CleanupItem` values.
- **View model** (`StorageViewModel`) — bridges Scanner to SwiftUI. Owns the
  scanned items and the current disk snapshot.
- **UI** (`ContentView.swift`) — pure SwiftUI. Header, toolbar, item list.

## Non-goals

- No background scanning. The user opens the app and triggers a scan.
- No persistence. Nothing is remembered between launches.
- No network. The app never phones home.
