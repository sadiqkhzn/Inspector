import XCTest
@testable import Inspector

/// Covers the pure-value-type logic in the Permissions domain:
///
/// - `PermissionItem.tier` is a derived property driving the UI chip. The cut-off
///   between "fresh" and "stale" is 30 days, and sensitive services override to
///   `.risky` regardless of recency.
/// - `PermissionService.settingsURL` must map every service to a valid System
///   Settings deep-link.
/// - `PermissionService.from(tccService:)` must round-trip every raw TCC string.
final class PermissionsTests: XCTestCase {

    // MARK: - PermissionItem.tier

    func test_tier_isDeniedWhenNotAllowed() {
        let item = makeItem(service: .camera, allowed: false, lastModified: .now)
        XCTAssertEqual(item.tier, .denied)
    }

    func test_tier_isGrantedForNormalServiceTouchedRecently() {
        let item = makeItem(service: .camera, allowed: true, lastModified: Date().addingTimeInterval(-60))
        XCTAssertEqual(item.tier, .granted)
    }

    func test_tier_isRiskyWhenServiceIsSensitive_regardlessOfRecency() {
        // Full Disk Access granted a year ago → still Risky, not Stale.
        let item = makeItem(service: .fullDiskAccess,
                            allowed: true,
                            lastModified: Date().addingTimeInterval(-365 * 24 * 60 * 60))
        XCTAssertEqual(item.tier, .risky)
    }

    func test_tier_isStaleForNormalServiceNotTouchedIn30Days() {
        let item = makeItem(service: .camera,
                            allowed: true,
                            lastModified: Date().addingTimeInterval(-45 * 24 * 60 * 60))
        XCTAssertEqual(item.tier, .stale)
    }

    func test_tier_isGrantedExactlyAtTheCutoffBoundary() {
        // < 30 days = granted. 29 days back should be granted.
        let item = makeItem(service: .camera,
                            allowed: true,
                            lastModified: Date().addingTimeInterval(-29 * 24 * 60 * 60))
        XCTAssertEqual(item.tier, .granted)
    }

    func test_tier_isGrantedWhenLastModifiedIsMissing() {
        // Absence of a last-modified means we don't know. Default to granted
        // rather than guessing "stale" — showing a yellow chip based on
        // missing data would be a worse UX.
        let item = makeItem(service: .camera, allowed: true, lastModified: nil)
        XCTAssertEqual(item.tier, .granted)
    }

    // MARK: - PermissionService.settingsURL

    func test_everyService_producesASettingsURL() {
        for service in PermissionService.allCases {
            let url = service.settingsURL
            XCTAssertNotNil(url, "\(service.displayName) must have a settingsURL.")
            XCTAssertEqual(url?.scheme, "x-apple.systempreferences",
                           "\(service.displayName) settingsURL should use the x-apple.systempreferences scheme.")
        }
    }

    func test_settingsURL_mapsEachServiceToADistinctAnchor() {
        let urls = PermissionService.allCases.compactMap { $0.settingsURL?.absoluteString }
        XCTAssertEqual(urls.count, PermissionService.allCases.count,
                       "Every service should produce a URL.")
        XCTAssertEqual(Set(urls).count, urls.count,
                       "Each service should deep-link to its own anchor; duplicates would mean two services share a Settings pane.")
    }

    // MARK: - PermissionService.from

    func test_from_roundTripsAllCases() {
        for service in PermissionService.allCases {
            XCTAssertEqual(PermissionService.from(tccService: service.rawValue), service)
        }
    }

    func test_from_returnsNilForUnknownStrings() {
        XCTAssertNil(PermissionService.from(tccService: "kTCCServiceSomethingWeDoNotMap"))
    }

    // MARK: - Fixture

    private func makeItem(service: PermissionService,
                          allowed: Bool,
                          lastModified: Date?) -> PermissionItem {
        PermissionItem(
            bundleID: "com.example.app",
            service: service,
            allowed: allowed,
            lastModified: lastModified,
            appName: "Example"
        )
    }
}
