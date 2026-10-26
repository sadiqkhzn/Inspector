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
    let id = UUID()
    let name: String
    let path: String
    let bytes: Int64
    let safety: SafetyLevel
    let category: ScanCategory
    let whatItIs: String
    let whatHappensIfRemoved: String
    var selected: Bool = false

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}
