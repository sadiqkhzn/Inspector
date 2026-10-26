import AppKit

/// The app or tool a catalog item belongs to. `bundleIDs` are tried in order to find an
/// installed app whose icon represents the item; `symbol` is the SF Symbol used otherwise.
struct ItemOwner: Hashable {
    let name: String
    let bundleIDs: [String]
    let symbol: String

    static let macOS = ItemOwner(name: "macOS", bundleIDs: [], symbol: "macwindow")
    static let unknown = ItemOwner(name: "Other", bundleIDs: [], symbol: "folder")
}

enum Owners {
    /// The owner whose path prefix is the longest match for `relativePath`.
    static func owner(forRelativePath relativePath: String) -> ItemOwner {
        rules
            .filter { relativePath.hasPrefix($0.prefix) }
            .max { $0.prefix.count < $1.prefix.count }?
            .owner ?? .unknown
    }

    private static func app(_ name: String, _ bundleIDs: String..., symbol: String = "app") -> ItemOwner {
        ItemOwner(name: name, bundleIDs: bundleIDs, symbol: symbol)
    }

    private static func tool(_ name: String, symbol: String = "terminal") -> ItemOwner {
        ItemOwner(name: name, bundleIDs: [], symbol: symbol)
    }

    private static let chrome = app("Google Chrome", "com.google.Chrome", symbol: "globe")
    private static let docker = app("Docker", "com.docker.docker", symbol: "shippingbox")
    private static let xcode = app("Xcode", "com.apple.dt.Xcode", symbol: "hammer")
    private static let safari = app("Safari", "com.apple.Safari", symbol: "safari")
    private static let slack = app("Slack", "com.tinyspeck.slackmacgap", symbol: "bubble.left.and.bubble.right")
    private static let discord = app("Discord", "com.hnc.Discord", symbol: "bubble.left.and.bubble.right")
    private static let zoom = app("Zoom", "us.zoom.xos", symbol: "video")
    private static let vscode = app("Visual Studio Code", "com.microsoft.VSCode", symbol: "chevron.left.forwardslash.chevron.right")
    private static let cursor = app("Cursor", "com.todesktop.230313mzl4w4u92", symbol: "chevron.left.forwardslash.chevron.right")
    private static let zed = app("Zed", "dev.zed.Zed", symbol: "chevron.left.forwardslash.chevron.right")
    private static let msAutoUpdate = app("Microsoft AutoUpdate", "com.microsoft.autoupdate2", symbol: "arrow.down.circle")
    private static let jetbrains = tool("JetBrains IDEs", symbol: "hammer")
    private static let node = tool("Node.js tools", symbol: "shippingbox")
    private static let python = tool("Python tools", symbol: "shippingbox")
    private static let rust = tool("Rust toolchain", symbol: "shippingbox")
    private static let java = tool("Java tools", symbol: "shippingbox")
    private static let antigravity = app("Antigravity", "com.google.antigravity")

    private static let rules: [(prefix: String, owner: ItemOwner)] = [
        ("Library/Caches/Google", chrome),
        ("Library/Application Support/Google/Chrome", chrome),
        ("Library/Caches/Google/Chrome Canary", app("Chrome Canary", "com.google.Chrome.canary", symbol: "globe")),
        ("Library/Caches/Google/Chrome Beta", app("Chrome Beta", "com.google.Chrome.beta", symbol: "globe")),
        ("Library/Caches/Google/Chrome Dev", app("Chrome Dev", "com.google.Chrome.dev", symbol: "globe")),
        ("Library/Caches/Google/AndroidStudio", app("Android Studio", "com.google.android.studio", symbol: "hammer")),
        ("Library/Application Support/Google/DriveFS", app("Google Drive", "com.google.drivefs", symbol: "externaldrive")),
        ("Library/Caches/Chromium", app("Chromium", "org.chromium.Chromium", symbol: "globe")),
        ("Library/Caches/Firefox", app("Firefox", "org.mozilla.firefox", symbol: "globe")),
        ("Library/Application Support/Firefox", app("Firefox", "org.mozilla.firefox", symbol: "globe")),
        ("Library/Containers/com.apple.Safari", safari),
        ("Library/Caches/Microsoft Edge", app("Microsoft Edge", "com.microsoft.edgemac", symbol: "globe")),
        ("Library/Caches/BraveSoftware", app("Brave Browser", "com.brave.Browser", symbol: "globe")),
        ("Library/Caches/Arc", app("Arc", "company.thebrowser.Browser", symbol: "globe")),
        ("Library/Caches/com.operasoftware.Opera", app("Opera", "com.operasoftware.Opera", symbol: "globe")),
        ("Library/Caches/com.vivaldi.Vivaldi", app("Vivaldi", "com.vivaldi.Vivaldi", symbol: "globe")),
        ("Library/Caches/org.torproject.torbrowser", app("Tor Browser", "org.torproject.torbrowser", symbol: "globe")),

        ("Library/Application Support/com.docker.install", docker),
        ("Library/Containers/com.docker.docker", docker),
        ("Library/Developer", xcode),
        ("Library/Caches/com.spotify.client", app("Spotify", "com.spotify.client", symbol: "music.note")),
        ("Library/Application Support/zoom.us", zoom),
        ("Library/Caches/us.zoom.xos", zoom),
        ("Library/Application Support/Steam", app("Steam", "com.valvesoftware.steam", symbol: "gamecontroller")),
        ("Library/Application Support/Code", vscode),
        ("Library/Application Support/Cursor", cursor),
        ("Library/Application Support/Windsurf", app("Windsurf", "com.exafunction.windsurf", symbol: "chevron.left.forwardslash.chevron.right")),
        ("Library/Caches/dev.zed.Zed", zed),
        ("Library/Application Support/Zed", zed),
        ("Library/Caches/com.sublimetext.4", app("Sublime Text", "com.sublimetext.4", symbol: "chevron.left.forwardslash.chevron.right")),
        ("Library/Caches/com.panic.Nova", app("Nova", "com.panic.Nova", symbol: "chevron.left.forwardslash.chevron.right")),
        ("Library/Caches/com.google.antigravity", antigravity),
        ("Library/Caches/drsprinto-updater", tool("Dr. Sprinto", symbol: "app")),
        ("Library/Containers/com.microsoft.teams2", app("Microsoft Teams", "com.microsoft.teams2", symbol: "person.2")),
        ("Library/Containers/com.microsoft.Outlook", app("Microsoft Outlook", "com.microsoft.Outlook", symbol: "envelope")),
        ("Library/Caches/com.microsoft.autoupdate2", msAutoUpdate),
        ("Library/Application Support/Microsoft/MERP2.0", msAutoUpdate),
        ("Library/Caches/OneDrive", app("OneDrive", "com.microsoft.OneDrive", symbol: "externaldrive")),
        ("Library/Application Support/Slack", slack),
        ("Library/Application Support/discord", discord),
        ("Library/Application Support/Figma", app("Figma", "com.figma.Desktop", symbol: "paintbrush")),
        ("Library/Application Support/Dropbox", app("Dropbox", "com.getdropbox.dropbox", symbol: "externaldrive")),
        ("Library/Application Support/Box", app("Box", "com.box.desktop", symbol: "externaldrive")),
        ("Library/Backblaze.bzpkg", app("Backblaze", "com.backblaze.bzbmenu", symbol: "externaldrive")),
        ("Library/Application Support/Postman", app("Postman", "com.postmanlabs.mac", symbol: "paperplane")),
        ("Library/Application Support/Insomnia", app("Insomnia", "com.insomnia.app", symbol: "paperplane")),
        ("Library/Application Support/obs-studio", app("OBS Studio", "com.obsproject.obs-studio", symbol: "record.circle")),
        ("Library/Caches/org.videolan.vlc", app("VLC", "org.videolan.vlc", symbol: "play.rectangle")),
        ("Library/Caches/com.googlecode.iterm2", app("iTerm2", "com.googlecode.iterm2", symbol: "terminal")),
        ("Library/Application Support/dev.warp.Warp-Stable", app("Warp", "dev.warp.Warp-Stable", symbol: "terminal")),
        ("Library/Application Support/GitHub Desktop", app("GitHub Desktop", "com.github.GitHubClient", symbol: "arrow.triangle.branch")),
        ("Library/Application Support/GitKraken", app("GitKraken", "com.axosoft.gitkraken", symbol: "arrow.triangle.branch")),
        ("Library/Containers/com.reederapp.5.macOS", app("Reeder", "com.reederapp.5.macOS", symbol: "newspaper")),
        ("Library/Application Support/com.lukilabs.lukiapp", app("Craft", "com.lukilabs.lukiapp", symbol: "doc.text")),
        ("Library/Application Support/Linear", app("Linear", "com.linear", symbol: "checklist")),
        ("Library/Application Support/Notion", app("Notion", "notion.id", symbol: "doc.text")),
        ("Library/Application Support/obsidian", app("Obsidian", "md.obsidian", symbol: "doc.text")),
        ("Library/Application Support/Signal", app("Signal", "org.whispersystems.signal-desktop", symbol: "bubble.left")),
        ("Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram", app("Telegram", "ru.keepcoder.Telegram", symbol: "paperplane")),
        ("Library/Group Containers/group.net.whatsapp.WhatsApp.shared", app("WhatsApp", "net.whatsapp.WhatsApp", symbol: "bubble.left")),
        ("Library/Group Containers/3L68KQB4HG.com.readdle.smartemail", app("Spark", "com.readdle.SparkDesktop", symbol: "envelope")),
        ("Library/Application Support/Element", app("Element", "im.riot.app", symbol: "bubble.left")),
        ("Library/Application Support/Zulip", app("Zulip", "org.zulip.zulip-electron", symbol: "bubble.left")),
        ("Library/Parallels", app("Parallels Desktop", "com.parallels.desktop.console", symbol: "pc")),
        ("Library/Containers/com.utmapp.UTM", app("UTM", "com.utmapp.UTM", symbol: "pc")),
        ("VirtualBox VMs", app("VirtualBox", "org.virtualbox.app.VirtualBox", symbol: "pc")),
        ("Library/Application Support/audacity", app("Audacity", "org.audacityteam.audacity", symbol: "waveform")),
        ("Library/Caches/Blender", app("Blender", "org.blenderfoundation.blender", symbol: "cube")),
        ("Movies/DaVinci Resolve", app("DaVinci Resolve", "com.blackmagic-design.DaVinciResolve", symbol: "film")),
        ("Library/Containers/net.telestream.screenflow10", app("ScreenFlow", "net.telestream.screenflow10", symbol: "film")),
        ("Library/Containers/com.apple.QuickTimePlayerX", app("QuickTime Player", "com.apple.QuickTimePlayerX", symbol: "play.rectangle")),
        ("Movies/Final Cut Backups", app("Final Cut Pro", "com.apple.FinalCut", symbol: "film")),
        ("Library/Application Support/Logic", app("Logic Pro", "com.apple.logic10", symbol: "pianokeys")),
        ("Library/Audio/Apple Loops", app("GarageBand", "com.apple.garageband10", "com.apple.logic10", symbol: "pianokeys")),
        ("Library/Caches/com.apple.appstore", app("App Store", "com.apple.AppStore", symbol: "bag")),

        ("Library/Caches/GeoServices", .macOS),
        ("Library/Caches/com.apple.quicklook.thumbnailcache", .macOS),
        ("Library/Logs", .macOS),
        ("Library/Containers/com.apple.mediaanalysisd", .macOS),
        ("Library/Containers/com.apple.wallpaper.agent", .macOS),
        ("Library/Containers/com.apple.geod", .macOS),

        ("Library/Caches/JetBrains", jetbrains),
        ("Library/Caches/JetBrains/RubyMine", app("RubyMine", "com.jetbrains.rubymine", symbol: "hammer")),
        ("Library/Caches/JetBrains/PyCharm", app("PyCharm", "com.jetbrains.pycharm", "com.jetbrains.pycharm.ce", symbol: "hammer")),
        ("Library/Caches/JetBrains/IntelliJIdea", app("IntelliJ IDEA", "com.jetbrains.intellij", "com.jetbrains.intellij.ce", symbol: "hammer")),
        ("Library/Caches/JetBrains/WebStorm", app("WebStorm", "com.jetbrains.WebStorm", symbol: "hammer")),
        ("Library/Caches/JetBrains/GoLand", app("GoLand", "com.jetbrains.goland", symbol: "hammer")),
        ("Library/Caches/JetBrains/CLion", app("CLion", "com.jetbrains.CLion", symbol: "hammer")),
        ("Library/Caches/JetBrains/PhpStorm", app("PhpStorm", "com.jetbrains.PhpStorm", symbol: "hammer")),

        ("Library/Caches/Homebrew", tool("Homebrew", symbol: "mug")),
        ("Library/Caches/ms-playwright", tool("Playwright", symbol: "theatermasks")),
        ("Library/Caches/pip", python),
        ("Library/Caches/com.apple.python", python),
        ("Library/Caches/uv", python),
        ("Library/Caches/pypoetry", python),
        ("miniconda3", python),
        ("Library/Jupyter", python),
        (".pyenv", python),
        (".local/pipx", python),
        (".npm", node),
        ("Library/Caches/Yarn", node),
        ("Library/pnpm", node),
        ("Library/Caches/node-gyp", node),
        (".nvm", node),
        (".local/share/fnm", node),
        (".volta", node),
        (".bun", tool("Bun", symbol: "shippingbox")),
        ("Library/Caches/deno", tool("Deno", symbol: "shippingbox")),
        (".cargo", rust),
        (".rustup", rust),
        ("go/pkg", tool("Go", symbol: "shippingbox")),
        (".gradle", java),
        (".m2", java),
        (".sdkman", java),
        (".jenv", java),
        ("Library/Caches/CocoaPods", tool("CocoaPods", symbol: "shippingbox")),
        ("Library/Caches/org.swift.swiftpm", tool("Swift Package Manager", symbol: "swift")),
        ("Library/Caches/composer", tool("Composer", symbol: "shippingbox")),
        (".gem", tool("RubyGems", symbol: "shippingbox")),
        (".asdf", tool("asdf", symbol: "shippingbox")),
        (".config/gcloud", tool("Google Cloud SDK", symbol: "cloud")),
        (".aws", tool("AWS CLI", symbol: "cloud")),
        (".terraform.d", tool("Terraform", symbol: "cloud")),
        (".kube", tool("Kubernetes tools", symbol: "cloud")),
        (".minikube", tool("Minikube", symbol: "cloud")),
        (".colima", tool("Colima", symbol: "shippingbox")),
        (".local/share/containers", tool("Podman", symbol: "shippingbox")),
        (".vagrant.d", tool("Vagrant", symbol: "pc")),
        (".cache", tool("Command-line tools")),
    ]
}

/// Icons for owners, resolved once per bundle ID from the apps installed on this Mac.
@MainActor
enum AppIcons {
    private static var cache: [String: NSImage?] = [:]

    static func icon(for owner: ItemOwner) -> NSImage? {
        for bundleID in owner.bundleIDs {
            if let cached = cache[bundleID] {
                if let image = cached { return image }
                continue
            }
            let image = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
            cache[bundleID] = image
            if let image { return image }
        }
        return nil
    }
}
