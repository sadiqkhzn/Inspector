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

    /// Best-effort friendly app name for a TCC client, which is either a bundle ID or,
    /// for command-line tools and relocated apps, an absolute path.
    ///
    /// - An installed app's own display name wins.
    /// - A path is named after the `.app` it sits in, else its last component.
    /// - Otherwise the bundle ID is prettied up, skipping platform suffixes so
    ///   `ai.perplexity.mac` reads "Perplexity", `us.zoom.xos` "Zoom" and
    ///   `com.microsoft.teams2` "Teams".
    static func resolveAppName(bundleID client: String) -> String {
        if client.hasPrefix("/") {
            let url = URL(fileURLWithPath: client)
            if let app = url.pathComponents.lastIndex(where: { $0.hasSuffix(".app") }) {
                let appURL = URL(fileURLWithPath: NSString.path(withComponents: Array(url.pathComponents[...app])))
                return bundleName(at: appURL) ?? appURL.deletingPathExtension().lastPathComponent
            }
            return url.lastPathComponent
        }
        #if canImport(AppKit)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: client),
           let name = bundleName(at: url) {
            return name
        }
        #endif
        return prettyName(fromBundleID: client)
    }

    static func prettyName(fromBundleID bundleID: String) -> String {
        let platformSuffixes: Set<String> = ["mac", "macos", "osx", "xos", "app", "desktop", "client", "helper"]
        let parts = bundleID.split(separator: ".").map(String.init)
        guard parts.count > 1 else { return bundleID }
        var pick = parts[parts.count - 1]
        if platformSuffixes.contains(pick.lowercased()) { pick = parts[parts.count - 2] }
        while let last = pick.last, last.isNumber { pick.removeLast() }
        guard let first = pick.first else { return bundleID }
        return first.uppercased() + pick.dropFirst()
    }

    private static func bundleName(at url: URL) -> String? {
        guard let bundle = Bundle(url: url) else { return nil }
        return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
    }
}

#if canImport(AppKit)
import AppKit
#endif
