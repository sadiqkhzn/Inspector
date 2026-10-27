import XCTest
@testable import Inspector

/// Covers BootScanner's plist parsing by writing deterministic plists to a
/// temp directory and asking the scanner to read it. We never touch the
/// user's real LaunchAgents during tests.
final class BootScannerTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try makeTempDir()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Reading

    func test_read_parsesTypicalLaunchAgent() throws {
        try write(plist: typicalAgentPlist, named: "com.example.helper.plist")

        let items = BootScanner.read(dir: tempDir, source: .userAgent)
        XCTAssertEqual(items.count, 1)

        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.label, "com.example.helper")
        XCTAssertEqual(item.owner, "Example")
        XCTAssertEqual(item.programDisplay, "/Applications/Example.app/Contents/MacOS/ExampleHelper")
        XCTAssertTrue(item.runAtLoad)
        XCTAssertFalse(item.keepAlive)
        XCTAssertFalse(item.disabled)
        XCTAssertEqual(item.source, .userAgent)
    }

    func test_read_fallsBackToFilenameWhenLabelIsMissing() throws {
        try write(plist: noLabelPlist, named: "com.example.noLabel.plist")

        let items = BootScanner.read(dir: tempDir, source: .userAgent)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.label, "com.example.noLabel",
                       "Scanner should fall back to the filename stem when Label is missing.")
    }

    func test_read_detectsDisabledFlag() throws {
        try write(plist: disabledPlist, named: "com.example.disabled.plist")

        let items = BootScanner.read(dir: tempDir, source: .userAgent)
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.first?.disabled == true)
        XCTAssertFalse(items.first?.enabled == true)
    }

    func test_read_treatsKeepAliveDictAsEnabled() throws {
        try write(plist: keepAliveDictPlist, named: "com.example.keepalive-dict.plist")

        let items = BootScanner.read(dir: tempDir, source: .userAgent)
        XCTAssertEqual(items.first?.keepAlive, true,
                       "A KeepAlive dict (e.g. { SuccessfulExit = NO; }) means launchd keeps the job alive.")
    }

    func test_read_usesProgramArgumentsWhenProgramIsMissing() throws {
        try write(plist: programArgumentsOnlyPlist, named: "com.example.args.plist")

        let items = BootScanner.read(dir: tempDir, source: .userAgent)
        XCTAssertEqual(items.first?.programDisplay,
                       "/opt/example/bin/tool --foo bar",
                       "Scanner should fall back to joined ProgramArguments when Program is absent.")
    }

    func test_read_skipsNonPlistFiles() throws {
        try write(plist: typicalAgentPlist, named: "com.example.helper.plist")
        try "junk".data(using: .utf8)?.write(to: tempDir.appendingPathComponent("README.md"))

        let items = BootScanner.read(dir: tempDir, source: .userAgent)
        XCTAssertEqual(items.count, 1, "Non-.plist files should be skipped.")
    }

    func test_read_skipsMalformedPlists() throws {
        let url = tempDir.appendingPathComponent("broken.plist")
        try "not actually a plist".data(using: .utf8)!.write(to: url)

        let items = BootScanner.read(dir: tempDir, source: .userAgent)
        XCTAssertTrue(items.isEmpty, "A corrupted plist should be silently skipped, not crash the scan.")
    }

    func test_read_tagsSourceCorrectly() throws {
        try write(plist: typicalAgentPlist, named: "com.example.helper.plist")

        let asDaemon = BootScanner.read(dir: tempDir, source: .systemDaemon)
        XCTAssertEqual(asDaemon.first?.source, .systemDaemon)
    }

    // MARK: - Suspicious / signature

    func test_item_isSuspiciousOnlyWhenEnabledAndUnsigned() {
        let base = BootItem(
            plistURL: URL(fileURLWithPath: "/tmp/ignored.plist"),
            label: "com.example.anon",
            programDisplay: "/tmp/anon",
            runAtLoad: true,
            keepAlive: false,
            disabled: false,
            owner: "Example",
            source: .userAgent,
            signatureStatus: .unsigned
        )
        XCTAssertTrue(base.isSuspicious, "Enabled + unsigned should flag as suspicious.")

        var disabled = base
        disabled = BootItem(plistURL: base.plistURL, label: base.label,
                            programDisplay: base.programDisplay,
                            runAtLoad: base.runAtLoad, keepAlive: base.keepAlive,
                            disabled: true,
                            owner: base.owner, source: base.source,
                            signatureStatus: .unsigned)
        XCTAssertFalse(disabled.isSuspicious, "A disabled job can't suspiciously run.")

        let valid = BootItem(plistURL: base.plistURL, label: base.label,
                             programDisplay: base.programDisplay,
                             runAtLoad: base.runAtLoad, keepAlive: base.keepAlive,
                             disabled: false,
                             owner: base.owner, source: base.source,
                             signatureStatus: .valid)
        XCTAssertFalse(valid.isSuspicious, "A properly signed job is fine.")
    }

    // MARK: - Schedule

    func test_calendarSummary_inWords() {
        XCTAssertEqual(BootScanner.calendarSummary(["Hour": 3, "Minute": 0]), "Daily at 3:00")
        XCTAssertEqual(BootScanner.calendarSummary(["Weekday": 1, "Hour": 9, "Minute": 30]), "Mondays at 9:30")
        XCTAssertEqual(BootScanner.calendarSummary(["Minute": 15]), "Hourly at :15")
        XCTAssertNil(BootScanner.calendarSummary(nil))
    }

    // MARK: - Fixtures

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BootScannerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(plist xml: String, named name: String) throws {
        let url = tempDir.appendingPathComponent(name)
        try xml.data(using: .utf8)!.write(to: url)
    }

    // MARK: - Plist XML

    private let typicalAgentPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key><string>com.example.helper</string>
        <key>Program</key><string>/Applications/Example.app/Contents/MacOS/ExampleHelper</string>
        <key>RunAtLoad</key><true/>
    </dict>
    </plist>
    """

    private let noLabelPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0">
    <dict>
        <key>Program</key><string>/tmp/x</string>
    </dict>
    </plist>
    """

    private let disabledPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0">
    <dict>
        <key>Label</key><string>com.example.disabled</string>
        <key>Program</key><string>/tmp/x</string>
        <key>Disabled</key><true/>
    </dict>
    </plist>
    """

    private let keepAliveDictPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0">
    <dict>
        <key>Label</key><string>com.example.keepalive</string>
        <key>Program</key><string>/tmp/x</string>
        <key>KeepAlive</key>
        <dict><key>SuccessfulExit</key><false/></dict>
    </dict>
    </plist>
    """

    private let programArgumentsOnlyPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0">
    <dict>
        <key>Label</key><string>com.example.args</string>
        <key>ProgramArguments</key>
        <array>
            <string>/opt/example/bin/tool</string>
            <string>--foo</string>
            <string>bar</string>
        </array>
    </dict>
    </plist>
    """
}
