#if canImport(Testing)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Testing

@Test
func marksConfiguredScopeAsConfirmedWhenAccountRootMatches() {
    let record = DriveFSRootPreferenceRecord(
        rootID: 60,
        title: "G Drive",
        rootPath: "G Drive",
        accountToken: "acct-1",
        syncType: 1,
        destination: 1,
        medium: 1,
        state: 2,
        oneShot: false,
        isMyDrive: true,
        documentID: "doc",
        lastSeenAbsolutePath: "/Volumes/Sync/G Drive"
    )

    let store = DriveFSRootPreferenceStore(
        confirmedRootIDsByAccount: ["acct-1": [60]]
    )

    let scopes = store.discoverScopes(from: [record])

    #expect(scopes.count == 1)
    #expect(scopes.first?.source == .confirmed)
}
#elseif canImport(XCTest)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import XCTest

final class DriveFSRootPreferenceStoreTests: XCTestCase {
    func testMarksConfiguredScopeAsConfirmedWhenAccountRootMatches() {
        let record = DriveFSRootPreferenceRecord(
            rootID: 60,
            title: "G Drive",
            rootPath: "G Drive",
            accountToken: "acct-1",
            syncType: 1,
            destination: 1,
            medium: 1,
            state: 2,
            oneShot: false,
            isMyDrive: true,
            documentID: "doc",
            lastSeenAbsolutePath: "/Volumes/Sync/G Drive"
        )

        let store = DriveFSRootPreferenceStore(
            confirmedRootIDsByAccount: ["acct-1": [60]]
        )

        let scopes = store.discoverScopes(from: [record])

        XCTAssertEqual(scopes.count, 1)
        XCTAssertEqual(scopes.first?.source, .confirmed)
    }
}
#endif
