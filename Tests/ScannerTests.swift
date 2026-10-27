import XCTest
@testable import Inspector

/// Covers Scanner's resolver and disk-snapshot behaviour. The full scan
/// walks real file system paths and is covered by the main app at runtime —
/// what matters for the test suite is that the logic that decides WHICH
/// path to look at is right.
final class ScannerTests: XCTestCase {
    private let fakeHome = URL(fileURLWithPath: "/Users/testuser")

    func test_resolve_withoutEnvVar_fallsBackToHomePlusRelativePath() {
        let spec = KnownItemSpec(
            "test", "Library/Caches/Example",
            .safe, .cache,
            "A cache that only exists in test to exercise the fallback path.",
            "Nothing happens; this is only used in tests."
        )
        let resolved = Scanner.resolve(spec: spec, home: fakeHome)
        XCTAssertEqual(resolved.path, "/Users/testuser/Library/Caches/Example")
    }

    func test_resolve_withEnvVarAbsent_fallsBackToHomePlusRelativePath() {
        // Spec declares an env var that isn't in ProcessInfo — should fall back.
        let spec = KnownItemSpec(
            "test", "Library/Caches/Example",
            .safe, .cache,
            "A cache referencing an env var that isn't exported in the test runner.",
            "Nothing happens; this is only used in tests.",
            envVar: "INSPECTOR_TEST_ENV_THAT_IS_NEVER_SET",
            envVarSuffix: "subdir"
        )
        let resolved = Scanner.resolve(spec: spec, home: fakeHome)
        XCTAssertEqual(resolved.path, "/Users/testuser/Library/Caches/Example",
                       "Resolve should fall back to home+relativePath when the env var is unset.")
    }

    func test_resolve_tildeExpansionInEnvVar() {
        // Simulate the env var being `~/foo` — the resolver should expand `~`
        // against the real user's home even though we pass a mock home URL.
        // (expandingTildeInPath is HOME-based regardless of our fakeHome arg.)
        let realHome = NSString(string: "~").expandingTildeInPath
        // Set the var via setenv so ProcessInfo picks it up for the duration
        // of this test, then unset so neighbouring tests don't inherit it.
        setenv("INSPECTOR_TEST_TILDE_CARGO", "~/some/cargo", 1)
        defer { unsetenv("INSPECTOR_TEST_TILDE_CARGO") }

        let spec = KnownItemSpec(
            "test", "fallback-ignored",
            .safe, .cache,
            "A cache that uses the custom env var we set in this test only.",
            "Nothing happens; this is only used in tests.",
            envVar: "INSPECTOR_TEST_TILDE_CARGO",
            envVarSuffix: "registry/cache"
        )
        let resolved = Scanner.resolve(spec: spec, home: fakeHome)
        XCTAssertEqual(resolved.path, "\(realHome)/some/cargo/registry/cache")
    }

    func test_resolve_absolutePathInEnvVar() {
        setenv("INSPECTOR_TEST_ABS_CARGO", "/opt/cargo", 1)
        defer { unsetenv("INSPECTOR_TEST_ABS_CARGO") }

        let spec = KnownItemSpec(
            "test", "fallback-ignored",
            .safe, .cache,
            "A cache that uses an absolute env var we set in this test only.",
            "Nothing happens; this is only used in tests.",
            envVar: "INSPECTOR_TEST_ABS_CARGO",
            envVarSuffix: "registry/cache"
        )
        let resolved = Scanner.resolve(spec: spec, home: fakeHome)
        XCTAssertEqual(resolved.path, "/opt/cargo/registry/cache")
    }

    func test_resolve_envVarWithoutSuffix_usesTheEnvVarAsTheFullPath() {
        setenv("INSPECTOR_TEST_WHOLE_PATH", "/var/cache/thing", 1)
        defer { unsetenv("INSPECTOR_TEST_WHOLE_PATH") }

        let spec = KnownItemSpec(
            "test", "fallback-ignored",
            .safe, .cache,
            "A cache whose env var provides the entire path with no suffix.",
            "Nothing happens; this is only used in tests.",
            envVar: "INSPECTOR_TEST_WHOLE_PATH"
        )
        let resolved = Scanner.resolve(spec: spec, home: fakeHome)
        XCTAssertEqual(resolved.path, "/var/cache/thing")
    }

    func test_resolve_emptyEnvVar_fallsBack() {
        setenv("INSPECTOR_TEST_EMPTY", "", 1)
        defer { unsetenv("INSPECTOR_TEST_EMPTY") }

        let spec = KnownItemSpec(
            "test", "Library/Caches/Example",
            .safe, .cache,
            "A cache with an env var exported but empty — treat as unset.",
            "Nothing happens; this is only used in tests.",
            envVar: "INSPECTOR_TEST_EMPTY",
            envVarSuffix: "sub"
        )
        let resolved = Scanner.resolve(spec: spec, home: fakeHome)
        XCTAssertEqual(resolved.path, "/Users/testuser/Library/Caches/Example",
                       "An exported-but-empty env var should be treated as unset.")
    }

    func test_diskSnapshot_returnsPlausibleValues() {
        let snap = Scanner.diskSnapshot()
        XCTAssertGreaterThan(snap.totalBytes, 0, "Disk total should be positive on a real Mac.")
        XCTAssertLessThanOrEqual(snap.freeBytes, snap.totalBytes,
                                 "Free bytes can't exceed total bytes.")
        XCTAssertGreaterThanOrEqual(snap.freeBytes, 0, "Free bytes should never be negative.")
    }
}
