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
            "Library/Caches/Google/Chrome",
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
            "Zoom's logs, preferences, and the sign-in token for your account.",
            "You are signed out and must sign in again, including any 2FA or SSO challenge. If you host meetings, re-registration and permission prompts may be required too."
        ),
        KnownItemSpec(
            "Zoom cache",
            "Library/Caches/us.zoom.xos",
            .safe, .cache,
            "Zoom's temp cache.",
            "Rebuilds on next launch."
        ),
        KnownItemSpec(
            "Steam app cache",
            "Library/Application Support/Steam/appcache",
            .safe, .cache,
            "Steam client's HTTP response and asset cache (not game files).",
            "Steam rebuilds the cache on next launch. Installed games are untouched."
        ),
        KnownItemSpec(
            "Steam depot cache",
            "Library/Application Support/Steam/depotcache",
            .safe, .cache,
            "Cached depot manifests used during game installs and updates.",
            "Next install or update rebuilds the manifests. Installed games are untouched."
        ),
        KnownItemSpec(
            "Steam logs",
            "Library/Application Support/Steam/logs",
            .safe, .cache,
            "Steam client's diagnostic logs.",
            "Nothing. New logs are written as needed."
        ),
        KnownItemSpec(
            "Steam shader cache",
            "Library/Application Support/Steam/steamapps/shadercache",
            .safe, .cache,
            "Pre-compiled shaders Steam cached for installed games.",
            "First launch of each affected game recompiles shaders (one-off slower start). Game files are untouched."
        ),
        KnownItemSpec(
            "Steam partial downloads",
            "Library/Application Support/Steam/steamapps/downloading",
            .safe, .cache,
            "Partially downloaded game files from interrupted installs or updates.",
            "Any in-progress Steam downloads restart from scratch. Completed installs are untouched."
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
            "Teams' sandboxed cache, logs, and session tokens tied to your organization sign-in.",
            "You are signed out and must sign in again through SSO, including any 2FA / conditional-access prompts your workplace enforces. Local chat drafts and queued messages are lost."
        ),
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
            "Every Firefox profile — history, bookmarks, open tabs, installed extensions, and the password store. Saved logins live here and are only recoverable if you also use Firefox Sync.",
            "You lose every saved password that was not also synced to a Firefox account. You also lose bookmarks, history, open tabs, extensions, and cookies. This locks you out of sites you were signed into."
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
            "Slack's full Application Support folder — cached workspace data, local search index, attachments, and session storage.",
            "Draft messages and unsent threads are lost. Depending on your workspace's auth setup you may be signed out and need to re-authenticate through SSO. Workspace content re-downloads from the server."
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
            "Dropbox/.dropbox.cache",
            .safe, .cache,
            "Dropbox client's local sync cache — kept inside your Dropbox folder, not in ~/Library.",
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
            .review, .cache,
            "Container for mediaanalysisd — the Apple background daemon that scans Photos for people, scenes, and text.",
            "The daemon re-scans your entire Photos library in the background, which can run for hours and keep CPU and fans high. Photos features like people and search degrade until the scan completes."
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
            .review, .cache,
            "Container for geod — Apple's background location daemon that caches geo and map tile data.",
            "Location-based features may be sluggish or inaccurate until geod rebuilds its cache. Rare but possible interference with Find My, Maps, and location-aware apps."
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
            .keep, .devTool,
            "Installed Rust toolchains managed by rustup. Each toolchain is a full compiler install, often 500 MB to 1.5 GB.",
            "You lose every installed Rust toolchain. rustup can reinstall them, but each is a sizeable download. Only clear if you no longer use Rust."
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
            .keep, .devTool,
            "Downloaded Vagrant VM box images. Each box is often 500 MB to 5 GB.",
            "Vagrant re-downloads each box the next time you 'vagrant up'. Can be a very large download if you have multiple boxes."
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
        KnownItemSpec(
            "Signal cache",
            "Library/Application Support/Signal/Cache",
            .safe, .cache,
            "Signal desktop's local cache for attachments and avatars.",
            "Signal re-downloads as needed."
        ),
        KnownItemSpec(
            "Telegram cache",
            "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/account-xxxxxxxxxxxxxxxxxxxx/postbox/media",
            .safe, .cache,
            "Telegram's cached media files.",
            "Telegram re-downloads media as you view it."
        ),
        KnownItemSpec(
            "WhatsApp cache",
            "Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Media",
            .safe, .cache,
            "WhatsApp downloaded media files.",
            "WhatsApp re-downloads media when you reopen conversations."
        ),
        KnownItemSpec(
            "Microsoft Outlook cache",
            "Library/Containers/com.microsoft.Outlook/Data/Library/Caches",
            .safe, .cache,
            "Outlook's local cache of attachments and app assets.",
            "Outlook rebuilds the cache. Mail account state is kept."
        ),
        KnownItemSpec(
            "Spark Mail cache",
            "Library/Group Containers/3L68KQB4HG.com.readdle.smartemail/Caches",
            .safe, .cache,
            "Spark Mail's local cache.",
            "Spark re-downloads as needed."
        ),
        KnownItemSpec(
            "Chrome Canary cache",
            "Library/Caches/Google/Chrome Canary",
            .safe, .cache,
            "Chrome Canary browser cache.",
            "Rebuilds as you browse. Profile is untouched."
        ),
        KnownItemSpec(
            "Chrome Beta cache",
            "Library/Caches/Google/Chrome Beta",
            .safe, .cache,
            "Chrome Beta browser cache.",
            "Rebuilds as you browse."
        ),
        KnownItemSpec(
            "Chrome Dev cache",
            "Library/Caches/Google/Chrome Dev",
            .safe, .cache,
            "Chrome Dev channel browser cache.",
            "Rebuilds as you browse."
        ),
        KnownItemSpec(
            "Chromium cache",
            "Library/Caches/Chromium",
            .safe, .cache,
            "Open-source Chromium browser cache.",
            "Rebuilds as you browse."
        ),
        KnownItemSpec(
            "gcloud SDK cache",
            ".config/gcloud/logs",
            .safe, .devTool,
            "Google Cloud SDK diagnostic logs.",
            "New logs are written as needed."
        ),
        KnownItemSpec(
            "AWS CLI cache",
            ".aws/cli/cache",
            .review, .devTool,
            "AWS CLI's SSO/STS token cache. Holds temporary credentials from recent sign-ins.",
            "Any in-flight CLI script using these cached credentials fails until you re-authenticate (often via SSO browser flow). Clear when idle; avoid during long-running scripts."
        ),
        KnownItemSpec(
            "Terraform plugin cache",
            ".terraform.d/plugin-cache",
            .safe, .devTool,
            "Terraform's shared provider plugin cache.",
            "Terraform re-downloads providers on next init."
        ),
        KnownItemSpec(
            "kubectl cache",
            ".kube/cache",
            .safe, .devTool,
            "kubectl's HTTP discovery cache for Kubernetes API resources.",
            "kubectl rebuilds discovery on next command."
        ),
        KnownItemSpec(
            "Minikube data",
            ".minikube/cache",
            .keep, .devTool,
            "Minikube's downloaded ISO, preloaded images, and cluster bootstrap state.",
            "You lose cluster bootstrap state and will need to re-pull preloaded images on next 'minikube start' (potentially GBs)."
        ),
        KnownItemSpec(
            "Colima data",
            ".colima",
            .keep, .devTool,
            "Colima's virtual machine disk image, config, and cluster state. This is the entire Colima installation.",
            "You lose the Colima VM including any images, volumes, and local state. Treat this like deleting a VM."
        ),
        KnownItemSpec(
            "Podman machines",
            ".local/share/containers/podman/machine",
            .keep, .devTool,
            "Podman's local virtual machine images and state.",
            "You lose every Podman machine including any built images and volumes. Treat this like deleting a VM."
        ),
        KnownItemSpec(
            "UTM VM data",
            "Library/Containers/com.utmapp.UTM/Data/Documents",
            .keep, .appData,
            "UTM virtual machine images.",
            "You lose all VMs. Do not clear unless exported elsewhere."
        ),
        KnownItemSpec(
            "VirtualBox VMs",
            "VirtualBox VMs",
            .keep, .appData,
            "VirtualBox virtual machine files.",
            "You lose all VirtualBox VMs. Do not clear unless intentional."
        ),
        KnownItemSpec(
            "OneDrive cache",
            "Library/Caches/OneDrive",
            .safe, .cache,
            "Microsoft OneDrive client cache.",
            "OneDrive rebuilds the cache. Synced files are untouched."
        ),
        KnownItemSpec(
            "Google Drive logs",
            "Library/Application Support/Google/DriveFS/Logs",
            .safe, .cache,
            "Google Drive File Stream's diagnostic log directory.",
            "New logs are written as needed."
        ),
        KnownItemSpec(
            "Box cache",
            "Library/Application Support/Box/Box/cache",
            .safe, .cache,
            "Box Drive client cache.",
            "Box rebuilds the cache. Synced files are untouched."
        ),
        KnownItemSpec(
            "Backblaze data",
            "Library/Backblaze.bzpkg/bzdata",
            .keep, .appData,
            "Backblaze backup client's working data including its index of what has already been backed up.",
            "Backblaze loses its memory of what has been backed up and must re-scan and re-upload large portions of your drive. Do not clear while a backup is active or in-progress."
        ),
        KnownItemSpec(
            "Audacity data",
            "Library/Application Support/audacity",
            .keep, .appData,
            "Audacity's full Application Support folder — preferences, plugins, and temp session data including unsaved projects.",
            "You lose any unsaved recordings, custom preferences, and installed plugins. Only clear if you have no in-progress work."
        ),
        KnownItemSpec(
            "Blender temp",
            "Library/Caches/Blender",
            .safe, .cache,
            "Blender temp and render cache.",
            "Rebuilds on next render."
        ),
        KnownItemSpec(
            "DaVinci Resolve cache",
            "Movies/DaVinci Resolve/CacheClip",
            .safe, .cache,
            "DaVinci Resolve's render cache for clips.",
            "Resolve rebuilds render caches on timeline playback."
        ),
        KnownItemSpec(
            "ScreenFlow sandbox",
            "Library/Containers/net.telestream.screenflow10",
            .keep, .appData,
            "ScreenFlow's full sandboxed container, including unexported screen recordings.",
            "You lose any unexported recordings — screen captures that are often the whole point of using ScreenFlow. Export first."
        ),
        KnownItemSpec(
            "QuickTime autosave",
            "Library/Containers/com.apple.QuickTimePlayerX",
            .keep, .appData,
            "QuickTime Player X's full container, including autosaved screen and screen-with-audio recordings.",
            "You lose every autosaved recording that was never explicitly saved to a file. These are usually one-off clips that are easy to forget about."
        ),
        KnownItemSpec(
            "Final Cut Pro Backups",
            "Movies/Final Cut Backups",
            .keep, .appData,
            "Final Cut Pro's automatic library backup copies — the only easy recovery path if a working library gets corrupted.",
            "You lose Final Cut's safety net for recovering a damaged library. Current libraries themselves are untouched, but if one goes bad later you have no automatic rollback."
        ),
        KnownItemSpec(
            "Logic Pro sound library",
            "Library/Application Support/Logic/Sampler Instruments",
            .review, .appData,
            "Logic Pro sampler instruments (part of sound library).",
            "You lose instruments; Logic prompts to re-download. ~GB-scale download."
        ),
        KnownItemSpec(
            "Garageband loops",
            "Library/Audio/Apple Loops",
            .review, .appData,
            "Shared Apple Loops library used by GarageBand and Logic.",
            "Loops re-download from inside the app when needed."
        ),
        KnownItemSpec(
            "Instruments traces",
            "Library/Developer/Instruments",
            .review, .devTool,
            "Saved Instruments trace documents.",
            "You lose saved performance traces."
        ),
        KnownItemSpec(
            "Microsoft AutoUpdate cache var",
            "Library/Application Support/Microsoft/MERP2.0",
            .safe, .installerLeftover,
            "Microsoft Error Reporting Protocol cache.",
            "Nothing. Only used for after-the-fact crash reports."
        ),
        KnownItemSpec(
            "Element cache",
            "Library/Application Support/Element/Cache",
            .safe, .cache,
            "Element (Matrix client) local cache.",
            "Element re-downloads as you scroll conversations."
        ),
        KnownItemSpec(
            "Zulip cache",
            "Library/Application Support/Zulip/Cache",
            .safe, .cache,
            "Zulip desktop app Electron cache.",
            "Rebuilds on next launch."
        ),
        KnownItemSpec(
            "Google Chrome Service Worker cache",
            "Library/Application Support/Google/Chrome/Default/Service Worker",
            .review, .cache,
            "Chrome's registered service worker storage for PWAs.",
            "PWAs may re-download assets on next open; some offline-only data lost."
        ),
        KnownItemSpec(
            "iPhone / iPad backups",
            "Library/Application Support/MobileSync/Backup",
            .keep, .appData,
            "Local Finder / iTunes device backups for connected iPhones and iPads.",
            "You lose every local device backup. If a device is lost or wiped, there is no recovery from this Mac. Keep unless you have an iCloud backup you trust."
        ),
        KnownItemSpec(
            "CoreSimulator logs",
            "Library/Logs/CoreSimulator",
            .safe, .devTool,
            "Diagnostic logs from the iOS Simulator runtime.",
            "Nothing. New logs are written on next simulator run."
        ),
        KnownItemSpec(
            "JetBrains logs",
            "Library/Logs/JetBrains",
            .safe, .devTool,
            "Per-product diagnostic logs from JetBrains IDEs.",
            "Nothing. New logs are written as needed."
        ),
        KnownItemSpec(
            "Mail diagnostic logs",
            "Library/Containers/com.apple.mail/Data/Library/Logs/Mail",
            .safe, .cache,
            "Apple Mail's diagnostic logs inside its container.",
            "Nothing. Only useful for debugging Mail problems."
        ),
        KnownItemSpec(
            "Conan 2 package cache",
            ".conan2/p",
            .safe, .devTool,
            "Conan 2 package manager's cache of downloaded binaries and recipes.",
            "conan install re-downloads packages on next use. Nothing else changes."
        ),
        KnownItemSpec(
            "NuGet packages cache",
            ".nuget/packages",
            .safe, .devTool,
            "NuGet's cache of downloaded .NET packages.",
            "dotnet restore re-downloads packages on next build."
        ),
        KnownItemSpec(
            "Adobe media cache",
            "Library/Application Support/Adobe/Common/Media Cache Files",
            .safe, .cache,
            "Shared media cache files generated by Premiere Pro, After Effects, Audition, and other Adobe apps.",
            "Adobe apps regenerate the cache as you open projects. Project files themselves are untouched."
        ),
        KnownItemSpec(
            "Adobe peak files",
            "Library/Application Support/Adobe/Common/Peak Files",
            .safe, .cache,
            "Audio peak files Adobe apps generate for waveform rendering.",
            "Adobe apps regenerate peak files when audio clips are reopened."
        ),
    ]
}
