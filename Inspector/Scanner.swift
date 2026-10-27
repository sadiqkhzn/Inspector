import Foundation

enum Scanner {
    static func scan() async -> [CleanupItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var results: [CleanupItem] = []

        for spec in KnownItems.catalog {
            let url = resolve(spec: spec, home: home)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let usage = directoryUsage(url: url)
            guard usage.bytes >= spec.minBytesToShow else { continue }
            results.append(
                CleanupItem(
                    name: spec.name,
                    url: url,
                    path: shortPath(url.path, home: home.path),
                    bytes: usage.bytes,
                    safety: spec.safety,
                    category: spec.category,
                    whatItIs: spec.whatItIs,
                    whatHappensIfRemoved: spec.whatHappensIfRemoved,
                    owner: Owners.owner(forRelativePath: spec.relativePath),
                    lastModified: usage.lastModified,
                    verified: spec.verified
                )
            )
        }

        return sorted(results)
    }

    static func sorted(_ items: [CleanupItem]) -> [CleanupItem] {
        items.sorted { a, b in
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

    /// Moves the item to the Trash and returns where it ended up, so it can be put back.
    static func moveToTrash(_ item: CleanupItem) throws -> URL? {
        var resulting: NSURL?
        try FileManager.default.trashItem(at: item.url, resultingItemURL: &resulting)
        return resulting as URL?
    }

    /// Puts a trashed item back. Fails if something has since been created at the original path.
    static func restore(_ item: CleanupItem, from trashedURL: URL) throws {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: item.url.path) else {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: item.url.path])
        }
        try fm.createDirectory(at: item.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: trashedURL, to: item.url)
    }

    private static func directoryUsage(url: URL) -> (bytes: Int64, lastModified: Date?) {
        var total: Int64 = 0
        var latest: Date?
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isDirectoryKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles], errorHandler: nil
        ) else { return (0, nil) }
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isDirectory == false else { continue }
            if let bytes = values.totalFileAllocatedSize {
                total += Int64(bytes)
            }
            if let date = values.contentModificationDate, date > (latest ?? .distantPast) {
                latest = date
            }
        }
        return (total, latest)
    }

    private static func shortPath(_ path: String, home: String) -> String {
        path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    /// Picks the on-disk path for a catalog entry. Honours an env var override
    /// when the spec declares one and the variable is present in the process
    /// environment. Falls back to `relativePath` under the user's home.
    /// Never shells out — only reads `ProcessInfo.processInfo.environment`.
    static func resolve(spec: KnownItemSpec, home: URL) -> URL {
        if let envName = spec.envVar,
           let raw = ProcessInfo.processInfo.environment[envName],
           !raw.isEmpty {
            let expanded = NSString(string: raw).expandingTildeInPath
            var url = URL(fileURLWithPath: expanded)
            if let suffix = spec.envVarSuffix, !suffix.isEmpty {
                url = url.appendingPathComponent(suffix)
            }
            return url
        }
        return home.appendingPathComponent(spec.relativePath)
    }
}
