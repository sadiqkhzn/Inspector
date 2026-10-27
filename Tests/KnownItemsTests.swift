import XCTest
@testable import Inspector

/// Sanity tests on the catalog itself. The catalog is pure data, so each
/// entry's "did I spell this field right" question can be answered without
/// touching disk. These tests catch:
///
/// - Entries that forgot a non-empty name / path / description.
/// - Paths with leading or trailing slashes (which would double up when the
///   Scanner joins them to the home directory).
/// - Duplicate relative paths — two entries racing to describe the same
///   folder is almost always a bug, and the Scanner would surface the second
///   one as a dead entry.
/// - Entries whose `whatHappensIfRemoved` text is suspiciously short, which
///   historically meant someone copy-pasted a placeholder.
final class KnownItemsTests: XCTestCase {

    func test_allEntries_haveNonEmptyFields() {
        for spec in KnownItems.catalog {
            XCTAssertFalse(spec.name.isEmpty,
                           "A catalog entry has an empty name.")
            XCTAssertFalse(spec.relativePath.isEmpty,
                           "\(spec.name) has an empty relativePath.")
            XCTAssertFalse(spec.whatItIs.isEmpty,
                           "\(spec.name) has no whatItIs description.")
            XCTAssertFalse(spec.whatHappensIfRemoved.isEmpty,
                           "\(spec.name) has no whatHappensIfRemoved description.")
        }
    }

    func test_noPathHasLeadingSlash() {
        for spec in KnownItems.catalog {
            XCTAssertFalse(spec.relativePath.hasPrefix("/"),
                           "\(spec.name) relativePath is absolute: \(spec.relativePath)")
        }
    }

    func test_noPathHasTrailingSlash() {
        for spec in KnownItems.catalog {
            XCTAssertFalse(spec.relativePath.hasSuffix("/"),
                           "\(spec.name) relativePath has a trailing slash: \(spec.relativePath)")
        }
    }

    func test_relativePathsAreUnique() {
        let paths = KnownItems.catalog.map(\.relativePath)
        let unique = Set(paths)
        XCTAssertEqual(paths.count, unique.count,
                       "Duplicate relativePath values in catalog — the second entry will never be reached by the scanner.")
    }

    func test_descriptionsAreSubstantive() {
        for spec in KnownItems.catalog {
            XCTAssertGreaterThanOrEqual(spec.whatItIs.count, 20,
                "\(spec.name) whatItIs is suspiciously short — '\(spec.whatItIs)'. Rewrite in plain English so users understand what they're about to delete.")
            XCTAssertGreaterThanOrEqual(spec.whatHappensIfRemoved.count, 10,
                "\(spec.name) whatHappensIfRemoved is suspiciously short — '\(spec.whatHappensIfRemoved)'.")
        }
    }

    /// Entries flagged `.keep` must give the user a real reason — vague
    /// 'you may lose data' blurbs are worse than nothing because they teach
    /// users to ignore the warning.
    func test_keepEntriesExplainWhyToKeep() {
        for spec in KnownItems.catalog where spec.safety == .keep {
            let text = spec.whatHappensIfRemoved.lowercased()
            let hasHardLanguage = ["only clear", "do not clear", "lose", "cannot", "unrecoverable",
                                   "irrecoverable", "intentional", "irreversible"]
                .contains { text.contains($0) }
            XCTAssertTrue(hasHardLanguage,
                "\(spec.name) is tier .keep but whatHappensIfRemoved doesn't warn clearly: '\(spec.whatHappensIfRemoved)'")
        }
    }

    func test_envVarAndSuffixAreUsedConsistently() {
        for spec in KnownItems.catalog {
            if spec.envVarSuffix != nil {
                XCTAssertNotNil(spec.envVar,
                    "\(spec.name) has an envVarSuffix but no envVar — the suffix will be ignored.")
            }
        }
    }

    func test_verifiedEntriesHaveTheExpectedDistribution() {
        let total = KnownItems.catalog.count
        let verified = KnownItems.catalog.filter(\.verified).count
        XCTAssertGreaterThan(total, 150, "Catalog has shrunk unexpectedly below 150 entries — did something get deleted?")
        XCTAssertGreaterThan(verified, 90, "Fewer than 90 verified entries — the verification pass we did is slipping.")
    }
}
