import Foundation

enum Scanner {
    static func scan() async -> [CleanupItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var results: [CleanupItem] = []

        for spec in KnownItems.catalog {
            let url = home.appendingPathComponent(spec.relativePath)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let size = directorySize(url: url)
            guard size >= spec.minBytesToShow else { continue }
            results.append(
                CleanupItem(
                    name: spec.name,
                    path: shortPath(url.path, home: home.path),
                    bytes: size,
                    safety: spec.safety,
                    category: spec.category,
                    whatItIs: spec.whatItIs,
                    whatHappensIfRemoved: spec.whatHappensIfRemoved
                )
            )
        }

        return results.sorted { a, b in
            if a.safety.sortOrder != b.safety.sortOrder {
                return a.safety.sortOrder < b.safety.sortOrder
            }
            return a.bytes > b.bytes
        }
    }

    static func diskSnapshot() -> DiskSnapshot {
        let url = URL(fileURLWithPath: "/System/Volumes/Data")
        if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
           let total = values.volumeTotalCapacity,
           let free = values.volumeAvailableCapacityForImportantUsage {
            return DiskSnapshot(totalBytes: Int64(total), freeBytes: Int64(free))
        }
        return DiskSnapshot(totalBytes: 0, freeBytes: 0)
    }

    static func remove(_ item: CleanupItem) throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fullPath = item.path.hasPrefix("~")
            ? home.appendingPathComponent(String(item.path.dropFirst(2))).path
            : item.path
        try FileManager.default.removeItem(atPath: fullPath)
    }

    private static func directorySize(url: URL) -> Int64 {
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles], errorHandler: nil
        ) else { return 0 }
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: Set(keys)),
               values.isDirectory == false,
               let bytes = values.totalFileAllocatedSize {
                total += Int64(bytes)
            }
        }
        return total
    }

    private static func shortPath(_ path: String, home: String) -> String {
        path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
