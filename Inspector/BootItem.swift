import Foundation

struct BootItem: Identifiable, Hashable {
    let plistURL: URL
    let label: String
    let programDisplay: String      // best-effort "what runs" string
    let runAtLoad: Bool
    let keepAlive: Bool
    let disabled: Bool
    let owner: String               // app name inferred from the plist contents

    var id: String { plistURL.path }

    var enabled: Bool { !disabled }

    /// Everything the search field matches against: label, inferred app and the program it runs.
    var searchableText: String { "\(label) \(owner) \(programDisplay)" }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (a: BootItem, b: BootItem) -> Bool { a.id == b.id }
}
