import Foundation

enum SafetyLevel: String, CaseIterable {
    case safe
    case review
    case keep

    var label: String {
        switch self {
        case .safe:   return "Safe"
        case .review: return "Review"
        case .keep:   return "Keep"
        }
    }

    var sortOrder: Int {
        switch self {
        case .safe:   return 0
        case .review: return 1
        case .keep:   return 2
        }
    }
}

enum ScanCategory: String {
    case cache = "Cache"
    case installerLeftover = "Installer leftover"
    case appData = "App data"
    case devTool = "Dev tool"
}

struct CleanupItem: Identifiable, Hashable {
    let name: String
    let url: URL
    let path: String
    let bytes: Int64
    let safety: SafetyLevel
    let category: ScanCategory
    let whatItIs: String
    let whatHappensIfRemoved: String
    let owner: ItemOwner
    let lastModified: Date?
    var selected: Bool = false

    var id: String { url.path }

    var formattedSize: String {
        ByteFormatter.string(bytes)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (a: CleanupItem, b: CleanupItem) -> Bool { a.id == b.id }
}

struct DiskSnapshot {
    let totalBytes: Int64
    let freeBytes: Int64
    var usedBytes: Int64 { totalBytes - freeBytes }
    var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
    var formattedFree: String {
        ByteFormatter.string(freeBytes)
    }
    var formattedUsed: String {
        ByteFormatter.string(usedBytes)
    }
    var formattedTotal: String {
        ByteFormatter.string(totalBytes)
    }
}
