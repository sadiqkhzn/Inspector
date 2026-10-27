import Foundation
import SQLite3

/// Reads macOS's TCC (Transparency, Consent, and Control) privacy database.
///
/// macOS keeps two TCC databases:
/// - System-wide: `/Library/Application Support/com.apple.TCC/TCC.db` —
///   holds decisions for services like Full Disk Access, Accessibility,
///   Input Monitoring, Screen Recording.
/// - Per-user: `~/Library/Application Support/com.apple.TCC/TCC.db` — holds
///   decisions for services like Camera, Microphone, Contacts, Calendar,
///   Reminders, Photos, Location, Automation.
///
/// Both are protected by System Integrity Protection + Privacy & Security.
/// Inspector needs the user to grant it Full Disk Access in System
/// Settings before either DB can be opened. If FDA isn't granted,
/// `sqlite3_open_v2` returns a permission error and we return an empty
/// result with `hasFullDiskAccess: false`.
///
/// No shell execution — the SQLite reads happen through the system
/// SQLite3 C library linked into every macOS process.
enum PermissionsScanner {

    struct Result {
        let items: [PermissionItem]
        /// True when we successfully opened at least one TCC database.
        /// Used by the UI to show the "grant Full Disk Access" onboarding
        /// state when false.
        let hasFullDiskAccess: Bool
    }

    static func scan() -> Result {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dbs: [URL] = [
            URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db"),
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        ]

        var collected: [PermissionItem] = []
        var openedAny = false

        for db in dbs where FileManager.default.fileExists(atPath: db.path) {
            if let rows = readAccessRows(at: db) {
                openedAny = true
                collected.append(contentsOf: rows)
            }
        }

        // Deduplicate by (bundleID, service); keep the most recently modified.
        var byKey: [String: PermissionItem] = [:]
        for item in collected {
            if let existing = byKey[item.id] {
                let keepNewer = (item.lastModified ?? .distantPast) > (existing.lastModified ?? .distantPast)
                if keepNewer { byKey[item.id] = item }
            } else {
                byKey[item.id] = item
            }
        }

        return Result(
            items: Array(byKey.values),
            hasFullDiskAccess: openedAny
        )
    }

    private static func readAccessRows(at url: URL) -> [PermissionItem]? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            if db != nil { sqlite3_close(db) }
            return nil
        }
        defer { sqlite3_close(db) }

        // The access table has shifted columns across macOS versions. We
        // select the four columns that have been stable for years and
        // tolerate missing-table / missing-column errors by returning nil.
        let sql = "SELECT service, client, auth_value, last_modified FROM access"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            if stmt != nil { sqlite3_finalize(stmt) }
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        var rows: [PermissionItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let serviceC = sqlite3_column_text(stmt, 0),
                  let clientC  = sqlite3_column_text(stmt, 1)
            else { continue }
            let serviceString = String(cString: serviceC)
            let bundleID = String(cString: clientC)
            let authValue = sqlite3_column_int(stmt, 2)
            let lastModifiedEpoch = sqlite3_column_int64(stmt, 3)

            guard let service = PermissionService.from(tccService: serviceString) else {
                continue
            }

            let allowed = authValue >= 2 // 0 = denied, 1 = unknown, 2+ = allowed
            let lastModified = lastModifiedEpoch > 0
                ? Date(timeIntervalSince1970: TimeInterval(lastModifiedEpoch))
                : nil

            rows.append(PermissionItem(
                bundleID: bundleID,
                service: service,
                allowed: allowed,
                lastModified: lastModified,
                appName: resolveAppName(bundleID: bundleID)
            ))
        }
        return rows
    }

    /// Best-effort friendly app name. If NSWorkspace can resolve the bundle ID
    /// to an installed app we use its localized name; otherwise we return a
    /// prettied-up version of the bundle ID.
    private static func resolveAppName(bundleID: String) -> String {
        #if canImport(AppKit)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url),
           let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                   ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) {
            return name
        }
        #endif
        // "com.google.Chrome" → "Chrome"
        return bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }
}

#if canImport(AppKit)
import AppKit
#endif
