import Foundation

/// Reads the three plist directories macOS uses for launchd jobs:
///
/// - `~/Library/LaunchAgents/` — user-level agents (login-triggered, this user)
/// - `/Library/LaunchAgents/` — system-wide agents (login-triggered, any user)
/// - `/Library/LaunchDaemons/` — system-wide daemons (boot-triggered, root)
///
/// `/System/Library/LaunchAgents/` and `/System/Library/LaunchDaemons/` are
/// Apple's own and deliberately not scanned — users shouldn't touch them,
/// and showing them would drown out the actionable third-party ones.
///
/// Everything is pure plist reading via `PropertyListSerialization`. No shell
/// execution, no modifications, no sudo. Both `/Library/LaunchAgents` and
/// `/Library/LaunchDaemons` are world-readable, so no Full Disk Access is
/// required for the plist listings themselves.
enum BootScanner {

    static func scan() -> [BootItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sources: [(BootSource, URL)] = [
            (.userAgent,    home.appendingPathComponent("Library/LaunchAgents")),
            (.systemAgent,  URL(fileURLWithPath: "/Library/LaunchAgents")),
            (.systemDaemon, URL(fileURLWithPath: "/Library/LaunchDaemons"))
        ]

        var items: [BootItem] = []
        for (source, dir) in sources {
            items.append(contentsOf: read(dir: dir, source: source))
        }

        return items.sorted { lhs, rhs in
            // Enabled first, then by source severity (daemons loudest), then owner, then label.
            if lhs.enabled != rhs.enabled { return lhs.enabled && !rhs.enabled }
            if lhs.source != rhs.source  { return sortOrder(lhs.source) < sortOrder(rhs.source) }
            if lhs.owner.lowercased() != rhs.owner.lowercased() {
                return lhs.owner.localizedCaseInsensitiveCompare(rhs.owner) == .orderedAscending
            }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    private static func sortOrder(_ source: BootSource) -> Int {
        switch source {
        case .systemDaemon: return 0
        case .systemAgent:  return 1
        case .userAgent:    return 2
        }
    }

    private static func read(dir: URL, source: BootSource) -> [BootItem] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url in
            guard url.pathExtension == "plist" else { return nil }
            return parse(plistAt: url, source: source)
        }
    }

    private static func parse(plistAt url: URL, source: BootSource) -> BootItem? {
        guard let data = try? Data(contentsOf: url),
              let any = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = any as? [String: Any]
        else { return nil }

        let label = (dict["Label"] as? String) ?? url.deletingPathExtension().lastPathComponent

        let program = dict["Program"] as? String
        let args = dict["ProgramArguments"] as? [String]
        let display: String = {
            if let program { return program }
            if let args, !args.isEmpty { return args.joined(separator: " ") }
            return "(unspecified)"
        }()

        let runAtLoad = (dict["RunAtLoad"] as? Bool) ?? false
        let keepAlive: Bool = {
            if let flag = dict["KeepAlive"] as? Bool { return flag }
            if dict["KeepAlive"] is [String: Any] { return true }
            return false
        }()
        let disabled = (dict["Disabled"] as? Bool) ?? false

        return BootItem(
            plistURL: url,
            label: label,
            programDisplay: display,
            runAtLoad: runAtLoad,
            keepAlive: keepAlive,
            disabled: disabled,
            owner: inferOwner(label: label, programDisplay: display),
            source: source
        )
    }

    /// Best-effort pretty name for the row. "com.google.keystone.agent" → "Google".
    private static func inferOwner(label: String, programDisplay: String) -> String {
        if label.hasPrefix("com.apple.") { return "Apple" }
        let core = label
            .replacingOccurrences(of: "com.", with: "")
            .replacingOccurrences(of: "org.", with: "")
            .replacingOccurrences(of: "net.", with: "")

        let firstSegment = core.split(separator: ".").first.map(String.init) ?? core

        let friendly: [String: String] = [
            "google": "Google",
            "adobe": "Adobe",
            "microsoft": "Microsoft",
            "docker": "Docker",
            "zoom": "Zoom", "zoomus": "Zoom", "us": "Zoom",
            "spotify": "Spotify",
            "dropbox": "Dropbox",
            "slack": "Slack",
            "discord": "Discord",
            "figma": "Figma",
            "notion": "Notion",
            "obsidian": "Obsidian",
            "raycast": "Raycast",
            "alfred": "Alfred",
            "runningwithcrayons": "Alfred",
            "jetbrains": "JetBrains",
            "mozilla": "Mozilla",
            "homebrew": "Homebrew",
            "github": "GitHub"
        ]

        if let hit = friendly[firstSegment.lowercased()] { return hit }
        return firstSegment.capitalized
    }
}
