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
        KnownItemSpec(
            "Slack cache",
            "Library/Application Support/Slack",
            .review, .appData,
            "Slack's cached workspace data, including attachments and local search index.",
            "Slack re-downloads workspace state on next launch. You'll stay signed in."
        ),
        KnownItemSpec(
            "Discord cache",
            "Library/Application Support/discord",
            .review, .appData,
            "Discord's cache: emoji, images, cached messages for faster scroll.",
            "Rebuilds as you use Discord. You'll stay signed in."
        ),
        KnownItemSpec(
            "Figma data",
            "Library/Application Support/Figma",
            .review, .appData,
            "Figma desktop's local cache and project state.",
            "Figma syncs from the cloud on next launch. You'll stay signed in."
        ),
        KnownItemSpec(
            "JetBrains caches",
            "Library/Caches/JetBrains",
            .safe, .devTool,
            "Shared cache for all JetBrains IDEs: indexes, local history, log files.",
            "IDEs re-index on next launch (one-time slower start). Settings and plugins stay."
        ),
        KnownItemSpec(
            "Android Studio caches",
            "Library/Caches/Google/AndroidStudio",
            .safe, .devTool,
            "Android Studio's build cache and project index.",
            "Projects re-index on next open. Builds take longer the first time, then normal."
        ),
        KnownItemSpec(
            "Gradle cache",
            ".gradle/caches",
            .safe, .devTool,
            "Gradle's cache of downloaded dependencies and build state.",
            "Next Gradle build re-downloads dependencies, otherwise identical."
        ),
        KnownItemSpec(
            "Maven local repository",
            ".m2/repository",
            .safe, .devTool,
            "Maven's local repository of downloaded artifacts.",
            "Next Maven build re-downloads artifacts from remote repositories."
        ),
        KnownItemSpec(
            "npm cache",
            ".npm",
            .safe, .devTool,
            "npm's cache of downloaded packages and tarballs.",
            "npm re-downloads packages on next install. Nothing else changes."
        ),
        KnownItemSpec(
            "Yarn cache",
            "Library/Caches/Yarn",
            .safe, .devTool,
            "Yarn's cache of downloaded packages.",
            "Yarn re-downloads packages on next install."
        ),
        KnownItemSpec(
            "pnpm store",
            "Library/pnpm/store",
            .safe, .devTool,
            "pnpm's content-addressable store of downloaded packages.",
            "pnpm re-downloads packages on next install."
        ),
        KnownItemSpec(
            "Bun install cache",
            ".bun/install/cache",
            .safe, .devTool,
            "Bun's cache of downloaded packages.",
            "Bun re-downloads packages on next install."
        ),
        KnownItemSpec(
            "Deno cache",
            "Library/Caches/deno",
            .safe, .devTool,
            "Deno's cache of downloaded modules.",
            "Deno re-downloads modules on next run."
        ),
        KnownItemSpec(
            "Cargo registry cache",
            ".cargo/registry/cache",
            .safe, .devTool,
            "Cargo's cache of downloaded crate archives.",
            "Cargo re-downloads crates on next build. Toolchains are untouched."
        ),
        KnownItemSpec(
            "Go module cache",
            "go/pkg/mod/cache/download",
            .safe, .devTool,
            "Go's cache of downloaded module zips.",
            "Next 'go build' re-downloads modules. Installed binaries are untouched."
        ),
        KnownItemSpec(
            "CocoaPods cache",
            "Library/Caches/CocoaPods",
            .safe, .devTool,
            "CocoaPods' cache of downloaded pod archives and spec repos.",
            "pod install re-downloads pods. Project state untouched."
        ),
        KnownItemSpec(
            "Swift Package Manager cache",
            "Library/Caches/org.swift.swiftpm",
            .safe, .devTool,
            "SwiftPM's shared cache of fetched package repositories.",
            "Xcode re-fetches packages on next resolve. Projects untouched."
        ),
        KnownItemSpec(
            "Composer cache",
            "Library/Caches/composer",
            .safe, .devTool,
            "Composer's cache of downloaded packages.",
            "composer install re-downloads packages."
        ),
        KnownItemSpec(
            "RubyGems cache",
            ".gem/cache",
            .safe, .devTool,
            "RubyGems' cache of downloaded gem files.",
            "gem install re-downloads gems. Installed gems are untouched."
        ),
        KnownItemSpec(
            "QuickLook thumbnails",
            "Library/Caches/com.apple.quicklook.thumbnailcache",
            .safe, .cache,
            "macOS QuickLook preview thumbnails.",
            "Thumbnails regenerate on demand when you preview files."
        ),
        KnownItemSpec(
            "Diagnostic reports",
            "Library/Logs/DiagnosticReports",
            .safe, .cache,
            "macOS crash reports, spin dumps, and hang reports generated when apps misbehave.",
            "Nothing. Only useful for after-the-fact crash analysis."
        ),
        KnownItemSpec(
            "CrashReporter logs",
            "Library/Logs/CrashReporter",
            .safe, .cache,
            "Historical crash logs for apps and background processes.",
            "Nothing. Fresh crash reports continue to be generated as needed."
        ),
        KnownItemSpec(
            "User app logs",
            "Library/Logs",
            .review, .cache,
            "Logs from various apps that write under ~/Library/Logs rather than Console.",
            "Some apps rely on their own logs for debugging — surface only, then clear what you recognize."
        ),
        KnownItemSpec(
            "Xcode Archives",
            "Library/Developer/Xcode/Archives",
            .review, .devTool,
            "Archived builds Xcode keeps after you Archive for distribution. Includes dSYMs.",
            "You lose dSYMs for crash symbolication of past releases. Only clear if you've exported dSYMs elsewhere."
        ),
        KnownItemSpec(
            "Playground devices",
            "Library/Developer/XCPGDevices",
            .safe, .devTool,
            "Simulator-like devices Xcode spins up for Playground execution.",
            "Rebuilt the next time you run a Playground."
        ),
        KnownItemSpec(
            "App Store cache",
            "Library/Caches/com.apple.appstore",
            .safe, .cache,
            "App Store client's download cache and preview assets.",
            "App Store rebuilds the cache on next launch. Downloaded apps are untouched."
        ),
        KnownItemSpec(
            "XDG cache",
            ".cache",
            .safe, .devTool,
            "The ~/.cache folder used by many Linux-origin tools (uv, rustup, pre-commit, etc.) when they run on macOS.",
            "Each tool rebuilds its own cache the next time you use it."
        ),
        KnownItemSpec(
            "Dropbox cache",
            "Library/Application Support/Dropbox/instance1/cache",
            .safe, .cache,
            "Dropbox client's local sync cache.",
            "Dropbox rebuilds the cache as it continues syncing. Files on disk and in the cloud are untouched."
        ),
        KnownItemSpec(
            "Microsoft AutoUpdate cache",
            "Library/Caches/com.microsoft.autoupdate2",
            .safe, .installerLeftover,
            "Downloaded update packages left over from Microsoft AutoUpdate.",
            "Nothing. Office apps continue to update normally."
        ),
        KnownItemSpec(
            "Postman cache",
            "Library/Application Support/Postman/Cache",
            .safe, .cache,
            "Postman's HTTP response cache and local history.",
            "Postman rebuilds the cache. You stay signed in; collections sync from your account."
        ),
        KnownItemSpec(
            "Insomnia cache",
            "Library/Application Support/Insomnia/Cache",
            .safe, .cache,
            "Insomnia's local cache of API responses and assets.",
            "Rebuilds as you continue making requests."
        ),
        KnownItemSpec(
            "Media Analysis daemon",
            "Library/Containers/com.apple.mediaanalysisd",
            .safe, .cache,
            "Container for mediaanalysisd — the background daemon that scans Photos for people, scenes, and text.",
            "The daemon re-scans your library in the background. First few hours after clearing may show higher CPU."
        ),
        KnownItemSpec(
            "Wallpaper agent cache",
            "Library/Containers/com.apple.wallpaper.agent",
            .review, .cache,
            "Cache for the macOS wallpaper rotation agent, including downloaded dynamic wallpapers.",
            "Dynamic wallpapers re-download next time you select them. Static wallpaper setting is kept."
        ),
        KnownItemSpec(
            "geod cache",
            "Library/Containers/com.apple.geod",
            .safe, .cache,
            "Container for geod — Apple's background location daemon that caches geo data.",
            "Nothing user-visible. Daemon rebuilds its cache in the background."
        ),
        KnownItemSpec(
            "Safari container",
            "Library/Containers/com.apple.Safari",
            .keep, .appData,
            "Safari's sandboxed container holding history, favorites, and extensions.",
            "You lose Safari history, favorites, and extensions. Only clear if you don't use Safari."
        ),
        KnownItemSpec(
            "OBS Studio cache",
            "Library/Application Support/obs-studio/plugin_config",
            .safe, .cache,
            "OBS Studio's plugin configuration cache.",
            "OBS rebuilds plugin configs on next launch. Scene collections and profiles are untouched."
        ),
        KnownItemSpec(
            "VLC cache",
            "Library/Caches/org.videolan.vlc",
            .safe, .cache,
            "VLC's media metadata and thumbnail cache.",
            "Metadata and thumbnails rebuild as you open files."
        ),
        KnownItemSpec(
            "iTerm2 cache",
            "Library/Caches/com.googlecode.iterm2",
            .safe, .cache,
            "iTerm2's quicklook and app cache.",
            "Nothing user-visible. Preferences and profiles are untouched."
        ),
        KnownItemSpec(
            "Warp terminal data",
            "Library/Application Support/dev.warp.Warp-Stable",
            .review, .appData,
            "Warp's local AI model cache, shell history mirror, and workflow data.",
            "You'll stay signed in but may lose recent AI command history."
        ),
        KnownItemSpec(
            "uv cache",
            "Library/Caches/uv",
            .safe, .devTool,
            "Astral uv's download cache for Python packages and interpreters.",
            "uv re-downloads what it needs on next run. Installed tools are untouched."
        ),
        KnownItemSpec(
            "Poetry cache",
            "Library/Caches/pypoetry",
            .safe, .devTool,
            "Poetry's cache of downloaded wheels and build artifacts.",
            "Poetry re-downloads packages on next install."
        ),
        KnownItemSpec(
            "Conda packages",
            "miniconda3/pkgs",
            .safe, .devTool,
            "Conda's cache of downloaded package archives before extraction into envs.",
            "conda install re-downloads archives. Existing environments are untouched."
        ),
        KnownItemSpec(
            "Jupyter runtime",
            "Library/Jupyter/runtime",
            .safe, .devTool,
            "Jupyter's temporary runtime data (connection files, kernel IDs).",
            "Nothing. Fresh runtime files are created when you start a kernel."
        ),
        KnownItemSpec(
            "GitHub Desktop logs",
            "Library/Application Support/GitHub Desktop/logs",
            .safe, .cache,
            "GitHub Desktop's log files.",
            "Nothing. New logs continue to be written as needed."
        ),
        KnownItemSpec(
            "GitKraken cache",
            "Library/Application Support/GitKraken/Cache",
            .safe, .cache,
            "GitKraken's HTTP response and avatar cache.",
            "GitKraken rebuilds the cache. Repositories and settings are untouched."
        ),
        KnownItemSpec(
            "SDKMAN archives",
            ".sdkman/archives",
            .safe, .devTool,
            "SDKMAN's downloaded SDK archives (JDKs, Gradle, Kotlin, etc.) kept after extraction.",
            "Nothing. Installed SDKs are untouched; archives are only needed for reinstall."
        ),
        KnownItemSpec(
            "Volta cache",
            ".volta/tmp",
            .safe, .devTool,
            "Volta's temp directory for in-progress downloads and installs.",
            "Nothing. Installed Node, npm, Yarn versions are kept."
        ),
        KnownItemSpec(
            "jenv cache",
            ".jenv/versions",
            .keep, .devTool,
            "jenv's symlinks to installed Java versions.",
            "You lose the ability to switch between Java versions until reconfigured. Only clear if you no longer use jenv."
        ),
        KnownItemSpec(
            "Reeder cache",
            "Library/Containers/com.reederapp.5.macOS/Data/Library/Caches",
            .safe, .cache,
            "Reeder's local article and image cache.",
            "Reeder re-syncs from your feed sources."
        ),
        KnownItemSpec(
            "Craft cache",
            "Library/Application Support/com.lukilabs.lukiapp/Cache",
            .safe, .cache,
            "Craft's local asset cache.",
            "Craft rebuilds the cache as you open documents."
        ),
        KnownItemSpec(
            "Linear cache",
            "Library/Application Support/Linear/Cache",
            .safe, .cache,
            "Linear's HTTP cache for issue and avatar data.",
            "Linear syncs from the server on next launch."
        ),
        KnownItemSpec(
            "Notion cache",
            "Library/Application Support/Notion/Cache",
            .safe, .cache,
            "Notion's local cache of blocks and attachments.",
            "Notion re-fetches content as you navigate. You stay signed in."
        ),
        KnownItemSpec(
            "Obsidian cache",
            "Library/Application Support/obsidian/Cache",
            .safe, .cache,
            "Obsidian's app-level cache, separate from your markdown vault.",
            "Rebuilds on next launch. Your vault files are not touched."
        ),
        KnownItemSpec(
            "Slack GPU cache",
            "Library/Application Support/Slack/GPUCache",
            .safe, .cache,
            "Slack's GPU and shader cache for its Electron shell.",
            "Rebuilds on next launch."
        ),
        KnownItemSpec(
            "Discord GPU cache",
            "Library/Application Support/discord/GPUCache",
            .safe, .cache,
            "Discord's GPU and shader cache for its Electron shell.",
            "Rebuilds on next launch."
        ),
        KnownItemSpec(
            "Zed editor cache",
            "Library/Caches/dev.zed.Zed",
            .safe, .cache,
            "Zed editor's local cache for language servers and highlights.",
            "Zed rebuilds the cache on next launch."
        ),
        KnownItemSpec(
            "Zed editor data",
            "Library/Application Support/Zed",
            .review, .appData,
            "Zed's workspace state, project settings, and local AI history.",
            "You lose recent project state and AI conversation history. Settings resync if signed in."
        ),
        KnownItemSpec(
            "Cursor editor cache",
            "Library/Application Support/Cursor/Cache",
            .safe, .cache,
            "Cursor editor's Electron HTTP cache.",
            "Cursor rebuilds the cache on next launch."
        ),
        KnownItemSpec(
            "Cursor GPU cache",
            "Library/Application Support/Cursor/GPUCache",
            .safe, .cache,
            "Cursor's GPU shader cache.",
            "Rebuilds on next launch."
        ),
        KnownItemSpec(
            "Windsurf editor cache",
            "Library/Application Support/Windsurf/Cache",
            .safe, .cache,
            "Codeium Windsurf's Electron HTTP cache.",
            "Rebuilds on next launch."
        ),
        KnownItemSpec(
            "Sublime Text cache",
            "Library/Caches/com.sublimetext.4",
            .safe, .cache,
            "Sublime Text 4's local index cache.",
            "Sublime rebuilds indexes on next project open."
        ),
        KnownItemSpec(
            "Nova editor cache",
            "Library/Caches/com.panic.Nova",
            .safe, .cache,
            "Panic Nova editor's cache.",
            "Rebuilds on next launch."
        ),
        KnownItemSpec(
            "Rubymine cache",
            "Library/Caches/JetBrains/RubyMine",
            .safe, .devTool,
            "RubyMine project index cache.",
            "RubyMine re-indexes on next project open."
        ),
        KnownItemSpec(
            "PyCharm cache",
            "Library/Caches/JetBrains/PyCharm",
            .safe, .devTool,
            "PyCharm project index cache.",
            "PyCharm re-indexes on next project open."
        ),
        KnownItemSpec(
            "IntelliJ cache",
            "Library/Caches/JetBrains/IntelliJIdea",
            .safe, .devTool,
            "IntelliJ IDEA project index cache.",
            "IntelliJ re-indexes on next project open."
        ),
        KnownItemSpec(
            "WebStorm cache",
            "Library/Caches/JetBrains/WebStorm",
            .safe, .devTool,
            "WebStorm project index cache.",
            "WebStorm re-indexes on next project open."
        ),
        KnownItemSpec(
            "GoLand cache",
            "Library/Caches/JetBrains/GoLand",
            .safe, .devTool,
            "GoLand project index cache.",
            "GoLand re-indexes on next project open."
        ),
        KnownItemSpec(
            "CLion cache",
            "Library/Caches/JetBrains/CLion",
            .safe, .devTool,
            "CLion project index cache.",
            "CLion re-indexes on next project open."
        ),
        KnownItemSpec(
            "PhpStorm cache",
            "Library/Caches/JetBrains/PhpStorm",
            .safe, .devTool,
            "PhpStorm project index cache.",
            "PhpStorm re-indexes on next project open."
        ),
        KnownItemSpec(
            "Rust rustup toolchains",
            ".rustup/toolchains",
            .review, .devTool,
            "Installed Rust toolchains managed by rustup.",
            "You lose installed Rust toolchains; rustup re-downloads them on demand."
        ),
        KnownItemSpec(
            "nvm Node versions",
            ".nvm/versions/node",
            .keep, .devTool,
            "Node versions installed via nvm.",
            "You lose installed Node versions until re-installed via nvm."
        ),
        KnownItemSpec(
            "fnm Node versions",
            ".local/share/fnm/node-versions",
            .keep, .devTool,
            "Node versions installed via fnm.",
            "You lose installed Node versions until re-installed."
        ),
        KnownItemSpec(
            "pyenv versions",
            ".pyenv/versions",
            .keep, .devTool,
            "Python versions installed via pyenv.",
            "You lose installed Python versions until re-built."
        ),
        KnownItemSpec(
            "pipx venvs",
            ".local/pipx/venvs",
            .keep, .devTool,
            "Virtualenvs managed by pipx for CLI tools.",
            "You lose installed CLI tools until re-installed via pipx."
        ),
        KnownItemSpec(
            "asdf installs",
            ".asdf/installs",
            .keep, .devTool,
            "Language versions managed by asdf.",
            "You lose installed language versions until re-built."
        ),
        KnownItemSpec(
            "Vagrant boxes",
            ".vagrant.d/boxes",
            .review, .devTool,
            "Downloaded Vagrant VM box images.",
            "Vagrant re-downloads boxes on next 'vagrant up'."
        ),
        KnownItemSpec(
            "Parallels snapshots",
            "Library/Parallels/Parallels Snapshots",
            .keep, .appData,
            "Parallels Desktop VM snapshots.",
            "You lose all VM snapshots. Only clear if intentional."
        ),
        KnownItemSpec(
            "Opera cache",
            "Library/Caches/com.operasoftware.Opera",
            .safe, .cache,
            "Opera browser cache.",
            "Opera rebuilds the cache as you browse."
        ),
        KnownItemSpec(
            "Vivaldi cache",
            "Library/Caches/com.vivaldi.Vivaldi",
            .safe, .cache,
            "Vivaldi browser cache.",
            "Vivaldi rebuilds the cache as you browse."
        ),
        KnownItemSpec(
            "Tor Browser cache",
            "Library/Caches/org.torproject.torbrowser",
            .safe, .cache,
            "Tor Browser's local cache.",
            "Rebuilds as you browse."
        ),
    ]
}
