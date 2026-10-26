import Foundation

struct KnownItemSpec {
    let name: String
    let relativePath: String
    let safety: SafetyLevel
    let category: ScanCategory
    let whatItIs: String
    let whatHappensIfRemoved: String
    let minBytesToShow: Int64

    init(
        _ name: String,
        _ relativePath: String,
        _ safety: SafetyLevel,
        _ category: ScanCategory,
        _ whatItIs: String,
        _ whatHappensIfRemoved: String,
        minBytesToShow: Int64 = 50 * 1024 * 1024
    ) {
        self.name = name
        self.relativePath = relativePath
        self.safety = safety
        self.category = category
        self.whatItIs = whatItIs
        self.whatHappensIfRemoved = whatHappensIfRemoved
        self.minBytesToShow = minBytesToShow
    }
}

enum KnownItems {
    static let catalog: [KnownItemSpec] = [
        KnownItemSpec(
            "Google Chrome cache",
            "Library/Caches/Google",
            .safe, .cache,
            "Chrome's browser cache. Pages, images, scripts kept to speed up repeat visits.",
            "Chrome will rebuild it as you browse. Bookmarks, history, and extensions are untouched."
        ),
        KnownItemSpec(
            "pip cache",
            "Library/Caches/pip",
            .safe, .devTool,
            "Downloaded Python packages kept so repeat installs are instant.",
            "Next pip install re-downloads, otherwise nothing changes."
        ),
        KnownItemSpec(
            "Python Launcher cache",
            "Library/Caches/com.apple.python",
            .safe, .devTool,
            "macOS's Python package install cache.",
            "Rebuilds automatically on next install."
        ),
        KnownItemSpec(
            "Playwright browsers",
            "Library/Caches/ms-playwright",
            .review, .devTool,
            "Chromium, Firefox, and WebKit binaries Playwright downloaded for testing.",
            "If you still run Playwright tests, you'll have to reinstall (~250 MB each)."
        ),
        KnownItemSpec(
            "Homebrew cache",
            "Library/Caches/Homebrew",
            .safe, .devTool,
            "Downloaded formula archives from brew install.",
            "Nothing. Already installed packages are unaffected."
        ),
        KnownItemSpec(
            "Docker installer leftover",
            "Library/Application Support/com.docker.install",
            .safe, .installerLeftover,
            "Files the Docker installer left behind after setup.",
            "Nothing. Docker itself is not touched."
        ),
        KnownItemSpec(
            "Docker Desktop data",
            "Library/Containers/com.docker.docker",
            .keep, .appData,
            "Docker images, volumes, build cache, and VM disk.",
            "You lose all local Docker images and volumes. Only clear if you've stopped using Docker.",
            minBytesToShow: 500 * 1024 * 1024
        ),
        KnownItemSpec(
            "Spotify cache",
            "Library/Caches/com.spotify.client",
            .safe, .cache,
            "Streamed track data kept for offline playback and quick replay.",
            "Rebuilds as you listen. Playlists and library stay."
        ),
        KnownItemSpec(
            "Zoom data",
            "Library/Application Support/zoom.us",
            .review, .appData,
            "Zoom's logs, preferences, and sign-in tokens.",
            "You'll have to sign in again on next launch."
        ),
        KnownItemSpec(
            "Zoom cache",
            "Library/Caches/us.zoom.xos",
            .safe, .cache,
            "Zoom's temp cache.",
            "Rebuilds on next launch."
        ),
        KnownItemSpec(
            "Steam data",
            "Library/Application Support/Steam",
            .review, .appData,
            "Steam client cache and session data.",
            "Any installed games will need to be re-downloaded. If you don't play, free to clear."
        ),
        KnownItemSpec(
            "VS Code cached data",
            "Library/Application Support/Code/CachedData",
            .safe, .cache,
            "VS Code's compiled module cache for extensions.",
            "VS Code rebuilds this on next launch. Extensions and settings stay."
        ),
        KnownItemSpec(
            "VS Code logs",
            "Library/Application Support/Code/logs",
            .safe, .cache,
            "VS Code's diagnostic logs.",
            "Nothing. Only useful for debugging editor crashes."
        ),
        KnownItemSpec(
            "node-gyp cache",
            "Library/Caches/node-gyp",
            .safe, .devTool,
            "Headers for native Node module compilation.",
            "Re-downloads on next native-module install."
        ),
KnownItemSpec(
            "Antigravity updater cache",
            "Library/Caches/com.google.antigravity.ShipIt",
            .safe, .installerLeftover,
            "Leftover updater packages from Google Antigravity.",
            "Nothing. The app itself keeps working."
        ),
        KnownItemSpec(
            "Antigravity cache",
            "Library/Caches/com.google.antigravity",
            .safe, .cache,
            "Google Antigravity's runtime cache.",
            "Rebuilds on next launch."
        ),
        KnownItemSpec(
            "Dr. Sprinto updater cache",
            "Library/Caches/drsprinto-updater",
            .safe, .installerLeftover,
            "Leftover updater packages.",
            "Nothing. The app itself keeps working."
        ),
        KnownItemSpec(
            "GeoServices cache",
            "Library/Caches/GeoServices",
            .safe, .cache,
            "Apple Maps and location services cache.",
            "Rebuilds on next use."
        ),
        KnownItemSpec(
            "Xcode DerivedData",
            "Library/Developer/Xcode/DerivedData",
            .safe, .devTool,
            "Xcode's build intermediates and indexing data.",
            "Next Xcode build takes longer the first time, then normal. Projects are unaffected."
        ),
        KnownItemSpec(
            "iOS DeviceSupport",
            "Library/Developer/Xcode/iOS DeviceSupport",
            .review, .devTool,
            "Debug symbols for each iOS version you've connected a device from.",
            "Debugging on specific iOS versions will re-download symbols on next connect."
        ),
        KnownItemSpec(
            "iOS Simulators",
            "Library/Developer/CoreSimulator/Devices",
            .review, .devTool,
            "iOS Simulator device instances (one per simulator you've booted).",
            "You lose simulator state. Fresh simulators get recreated as needed."
        ),
        KnownItemSpec(
            "Simulator Caches",
            "Library/Developer/CoreSimulator/Caches",
            .safe, .devTool,
            "Caches used by iOS Simulator runtimes.",
            "Rebuilds on next simulator launch."
        ),
        KnownItemSpec(
            "Microsoft Teams data",
            "Library/Containers/com.microsoft.teams2",
            .review, .appData,
            "Teams cache, logs, and session data.",
            "You'll sign in again on next launch."
        )
        KnownItemSpec(
            "Firefox cache",
            "Library/Caches/Firefox",
            .safe, .cache,
            "Firefox's browser cache. Pages and images kept for faster repeat visits.",
            "Firefox will rebuild it as you browse. History, bookmarks, and extensions are untouched."
        ),
        KnownItemSpec(
            "Firefox profile data",
            "Library/Application Support/Firefox",
            .review, .appData,
            "Firefox profiles including history, bookmarks, saved passwords, and extensions.",
            "You lose history, bookmarks, saved passwords, and extensions for every Firefox profile. Only clear if you don't use Firefox."
        ),
        KnownItemSpec(
            "Safari cache",
            "Library/Containers/com.apple.Safari/Data/Library/Caches",
            .safe, .cache,
            "Safari's browser cache. Rebuilt as you browse.",
            "Nothing. Safari rebuilds the cache on next launch."
        ),
        KnownItemSpec(
            "Microsoft Edge cache",
            "Library/Caches/Microsoft Edge",
            .safe, .cache,
            "Edge's browser cache. Pages, images, scripts kept to speed up repeat visits.",
            "Edge will rebuild it as you browse. Bookmarks, history, and extensions are untouched."
        ),
        KnownItemSpec(
            "Brave Browser cache",
            "Library/Caches/BraveSoftware",
            .safe, .cache,
            "Brave's browser cache. Rebuilt as you browse.",
            "Brave will rebuild it as you browse. Profile, bookmarks, and history stay."
        ),
        KnownItemSpec(
            "Arc browser cache",
            "Library/Caches/Arc",
            .safe, .cache,
            "Arc's browser cache.",
            "Arc will rebuild it as you browse."
        ),
    ]
}
