import Foundation

/// Where a plist lives on disk — determines when it runs and whose user
/// account it runs under.
///
/// - `userAgent`:   `~/Library/LaunchAgents/`, runs when THIS user logs in.
/// - `systemAgent`: `/Library/LaunchAgents/`, runs when any user logs in.
/// - `systemDaemon`: `/Library/LaunchDaemons/`, runs at system boot as root
///   regardless of login. Highest-impact category.
enum BootSource: String, CaseIterable, Hashable {
    case userAgent
    case systemAgent
    case systemDaemon

    var label: String {
        switch self {
        case .userAgent:    return "User agent"
        case .systemAgent:  return "System agent"
        case .systemDaemon: return "System daemon"
        }
    }

    var directory: String {
        switch self {
        case .userAgent:    return "~/Library/LaunchAgents"
        case .systemAgent:  return "/Library/LaunchAgents"
        case .systemDaemon: return "/Library/LaunchDaemons"
        }
    }
}

struct BootItem: Identifiable, Hashable {
    let plistURL: URL
    let label: String
    let programDisplay: String      // best-effort "what runs" string
    let runAtLoad: Bool
    let keepAlive: Bool
    let disabled: Bool
    let owner: String               // app name inferred from the plist contents
    let source: BootSource
    let signatureStatus: BootSignatureStatus
    /// The executable launchd starts: `Program`, else `ProgramArguments[0]`.
    var executablePath: String? = nil
    /// Who signed that executable, from its certificate ("Google LLC"). Nil when unsigned or ad hoc.
    var signer: String? = nil
    /// `StartInterval`, in seconds.
    var startInterval: Int? = nil
    /// `StartCalendarInterval`, already in words ("Daily at 3:00").
    var calendarSummary: String? = nil

    var id: String { plistURL.path }

    var enabled: Bool { !disabled }

    /// True when the UI should flag this item: enabled + unsigned. The
    /// signature-is-missing-or-broken state is the one that lets
    /// surreptitiously-planted agents slip past.
    var isSuspicious: Bool {
        enabled && signatureStatus == .unsigned
    }

    /// Everything the search field matches against: label, inferred app and the program it runs.
    var searchableText: String { "\(label) \(owner) \(programDisplay) \(source.label)" }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (a: BootItem, b: BootItem) -> Bool { a.id == b.id }
}
