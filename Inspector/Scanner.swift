import Foundation

enum Scanner {
    static func directorySize(url: URL) -> Int64 {
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
}
