import XCTest
import SQLite3
@testable import Inspector

/// Covers `PermissionsScanner.readAccessRows(at:)` by writing deterministic
/// SQLite files to a temp directory and feeding them in. The system TCC
/// databases are never touched: both are SIP-protected and require Full
/// Disk Access to open, which the test runner doesn't have.
///
/// The `access` table shape is the four columns Inspector has always
/// consumed: `service` TEXT, `client` TEXT, `auth_value` INTEGER,
/// `last_modified` INTEGER (unix epoch).
final class PermissionsScannerTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try makeTempDir()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Happy path

    func test_readAccessRows_parsesCameraRow() throws {
        let db = try makeTCC(at: "camera.db") { conn in
            try insert(conn,
                       service: "kTCCServiceCamera",
                       client: "com.example.camera",
                       authValue: 2,
                       lastModified: 1_730_000_000)
        }

        let rows = try XCTUnwrap(PermissionsScanner.readAccessRows(at: db))
        XCTAssertEqual(rows.count, 1)

        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.bundleID, "com.example.camera")
        XCTAssertEqual(row.service, .camera)
        XCTAssertTrue(row.allowed)
        XCTAssertEqual(row.lastModified, Date(timeIntervalSince1970: 1_730_000_000))
    }

    func test_readAccessRows_returnsAllRowsForMultipleServices() throws {
        let db = try makeTCC(at: "many.db") { conn in
            try insert(conn, service: "kTCCServiceCamera",         client: "a", authValue: 2, lastModified: 1)
            try insert(conn, service: "kTCCServiceMicrophone",     client: "b", authValue: 2, lastModified: 2)
            try insert(conn, service: "kTCCServiceScreenCapture",  client: "c", authValue: 2, lastModified: 3)
        }

        let rows = try XCTUnwrap(PermissionsScanner.readAccessRows(at: db))
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(Set(rows.map(\.service)),
                       Set([.camera, .microphone, .screenRecording]))
    }

    // MARK: - auth_value semantics

    func test_allowed_isFalseForAuthValuesBelowTwo() throws {
        let db = try makeTCC(at: "deny.db") { conn in
            try insert(conn, service: "kTCCServiceCamera", client: "denied", authValue: 0, lastModified: 1)
            try insert(conn, service: "kTCCServiceCamera", client: "unknown", authValue: 1, lastModified: 1)
        }

        let rows = try XCTUnwrap(PermissionsScanner.readAccessRows(at: db))
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy { $0.allowed == false },
                      "auth_value 0 (denied) and 1 (unknown) both mean 'not allowed' in the UI.")
    }

    func test_allowed_isTrueForAuthValueTwoOrGreater() throws {
        // macOS uses 2 for most "allowed" states and 3 for "limited allowed".
        // Both must register as allowed.
        let db = try makeTCC(at: "allow.db") { conn in
            try insert(conn, service: "kTCCServiceCamera", client: "allowed", authValue: 2, lastModified: 1)
            try insert(conn, service: "kTCCServiceCamera", client: "limited", authValue: 3, lastModified: 1)
        }

        let rows = try XCTUnwrap(PermissionsScanner.readAccessRows(at: db))
        XCTAssertTrue(rows.allSatisfy(\.allowed))
    }

    // MARK: - last_modified semantics

    func test_lastModified_isNilWhenEpochIsZero() throws {
        let db = try makeTCC(at: "no-ts.db") { conn in
            try insert(conn, service: "kTCCServiceCamera", client: "x", authValue: 2, lastModified: 0)
        }

        let rows = try XCTUnwrap(PermissionsScanner.readAccessRows(at: db))
        XCTAssertNil(rows.first?.lastModified,
                     "A zero epoch is TCC's absent-timestamp sentinel; we store nil so the UI can hide the age chip.")
    }

    // MARK: - Service filter

    func test_readAccessRows_skipsUnknownServices() throws {
        let db = try makeTCC(at: "unknown.db") { conn in
            try insert(conn, service: "kTCCServiceSomethingAppleAddedLastWeek",
                       client: "com.example", authValue: 2, lastModified: 1)
            try insert(conn, service: "kTCCServiceCamera",
                       client: "com.example", authValue: 2, lastModified: 1)
        }

        let rows = try XCTUnwrap(PermissionsScanner.readAccessRows(at: db))
        XCTAssertEqual(rows.count, 1,
                       "Rows with services Inspector doesn't model should be silently dropped, not shown as 'Unknown'.")
        XCTAssertEqual(rows.first?.service, .camera)
    }

    func test_readAccessRows_skipsRowsWithNullServiceOrClient() throws {
        let db = try makeTCC(at: "nulls.db") { conn in
            // NULL service — scanner should drop this row.
            try run(conn, "INSERT INTO access (service, client, auth_value, last_modified) VALUES (NULL, 'x', 2, 1)")
            // NULL client — scanner should drop this row too.
            try run(conn, "INSERT INTO access (service, client, auth_value, last_modified) VALUES ('kTCCServiceCamera', NULL, 2, 1)")
            try insert(conn, service: "kTCCServiceCamera", client: "ok", authValue: 2, lastModified: 1)
        }

        let rows = try XCTUnwrap(PermissionsScanner.readAccessRows(at: db))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.bundleID, "ok")
    }

    // MARK: - Malformed inputs

    func test_readAccessRows_returnsNilWhenTableIsMissing() throws {
        let path = tempDir.appendingPathComponent("no-table.db").path
        var conn: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(path, &conn, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil), SQLITE_OK)
        sqlite3_close(conn)

        let result = PermissionsScanner.readAccessRows(at: URL(fileURLWithPath: path))
        XCTAssertNil(result,
                     "A valid SQLite file without an `access` table should return nil, not an empty array — nil tells scan() the DB was unreadable.")
    }

    func test_readAccessRows_returnsNilWhenFileIsNotSqlite() throws {
        let url = tempDir.appendingPathComponent("junk.db")
        try "this is not a sqlite file".data(using: .utf8)!.write(to: url)

        XCTAssertNil(PermissionsScanner.readAccessRows(at: url))
    }

    func test_readAccessRows_returnsNilForMissingFile() {
        let url = tempDir.appendingPathComponent("does-not-exist.db")
        XCTAssertNil(PermissionsScanner.readAccessRows(at: url))
    }

    // MARK: - Fixtures

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PermissionsScannerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Builds a SQLite file with the `access` table and whatever rows the
    /// caller inserts. Returns the file URL.
    private func makeTCC(at name: String, insert: (OpaquePointer) throws -> Void) throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        var conn: OpaquePointer?
        guard sqlite3_open_v2(url.path, &conn, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let conn
        else {
            XCTFail("sqlite3_open_v2 failed for \(url.path)")
            throw NSError(domain: "PermissionsScannerTests", code: 1)
        }
        defer { sqlite3_close(conn) }

        try run(conn, """
        CREATE TABLE access (
            service TEXT,
            client TEXT,
            auth_value INTEGER,
            last_modified INTEGER
        )
        """)
        try insert(conn)
        return url
    }

    private func insert(_ conn: OpaquePointer,
                        service: String,
                        client: String,
                        authValue: Int,
                        lastModified: Int) throws {
        let sql = """
        INSERT INTO access (service, client, auth_value, last_modified)
        VALUES ('\(service)', '\(client)', \(authValue), \(lastModified))
        """
        try run(conn, sql)
    }

    private func run(_ conn: OpaquePointer, _ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(conn, sql, nil, nil, &err) == SQLITE_OK else {
            let message = err.map { String(cString: $0) } ?? "unknown sqlite error"
            sqlite3_free(err)
            XCTFail("SQL failed: \(message)\n\(sql)")
            throw NSError(domain: "PermissionsScannerTests", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
