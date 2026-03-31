#if canImport(Testing)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared
import Foundation
import Testing

@Test
func deniesGoogleDriveArtefactEventInProtectedScope() {
    let scope = DriveManagedScope(
        displayName: "Protected Scope",
        path: "/Volumes/Work/Google Drive",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .external,
        fileSystemKind: .apfs,
        supportStatus: .supported,
        enforcementMode: .blockKnownArtefacts
    )
    let event = ProcessAttributedFileEvent(
        processSignature: ProcessSignature(
            bundleID: "com.google.drivefs",
            executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
            displayName: "Google Drive",
            isGoogleDriveRelated: true
        ),
        targetPath: "/Volumes/Work/Google Drive/Folder/Icon\r",
        operation: .create
    )

    let evaluation = HelperProtectionPolicyEngine().evaluate(event: event, scopes: [scope])

    #expect(evaluation.decision == .deny)
    #expect(evaluation.matchedScopeID == scope.id)
    #expect(evaluation.matchedArtefactType == .iconFile)
}

@Test
func allowsUserCreatedIconEventWithoutGoogleDriveAttribution() {
    let scope = DriveManagedScope(
        displayName: "Protected Scope",
        path: "/Volumes/Work/Google Drive",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .external,
        fileSystemKind: .apfs,
        supportStatus: .supported,
        enforcementMode: .blockKnownArtefacts
    )
    let event = ProcessAttributedFileEvent(
        processSignature: ProcessSignature(
            bundleID: "com.apple.finder",
            executablePath: "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder",
            displayName: "Finder",
            isGoogleDriveRelated: false
        ),
        targetPath: "/Volumes/Work/Google Drive/Folder/Icon\r",
        operation: .create
    )

    let evaluation = HelperProtectionPolicyEngine().evaluate(event: event, scopes: [scope])

    #expect(evaluation.decision == .allow)
    #expect(evaluation.reason.contains("not classified as Google Drive"))
}

@Test
func keepsSupportedAuditOnlyScopesOutOfBlocking() {
    let scope = DriveManagedScope(
        displayName: "Supported Scope",
        path: "/Volumes/Work/Google Drive",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .external,
        fileSystemKind: .apfs,
        supportStatus: .supported,
        enforcementMode: .auditOnly
    )
    let event = ProcessAttributedFileEvent(
        processSignature: ProcessSignature(
            bundleID: "com.google.drivefs",
            executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
            displayName: "Google Drive",
            isGoogleDriveRelated: true
        ),
        targetPath: "/Volumes/Work/Google Drive/Folder/Icon\r",
        operation: .create
    )

    let evaluation = HelperProtectionPolicyEngine().evaluate(event: event, scopes: [scope])

    #expect(evaluation.decision == .auditOnly)
}
#elseif canImport(XCTest)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared
import Foundation
import XCTest

final class HelperProtectionPolicyEngineTests: XCTestCase {
    func testDeniesGoogleDriveArtefactEventInProtectedScope() {
        let scope = DriveManagedScope(
            displayName: "Protected Scope",
            path: "/Volumes/Work/Google Drive",
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .external,
            fileSystemKind: .apfs,
            supportStatus: .supported,
            enforcementMode: .blockKnownArtefacts
        )
        let event = ProcessAttributedFileEvent(
            processSignature: ProcessSignature(
                bundleID: "com.google.drivefs",
                executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                displayName: "Google Drive",
                isGoogleDriveRelated: true
            ),
            targetPath: "/Volumes/Work/Google Drive/Folder/Icon\r",
            operation: .create
        )

        let evaluation = HelperProtectionPolicyEngine().evaluate(event: event, scopes: [scope])

        XCTAssertEqual(evaluation.decision, .deny)
        XCTAssertEqual(evaluation.matchedScopeID, scope.id)
        XCTAssertEqual(evaluation.matchedArtefactType, .iconFile)
    }

    func testAllowsUserCreatedIconEventWithoutGoogleDriveAttribution() {
        let scope = DriveManagedScope(
            displayName: "Protected Scope",
            path: "/Volumes/Work/Google Drive",
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .external,
            fileSystemKind: .apfs,
            supportStatus: .supported,
            enforcementMode: .blockKnownArtefacts
        )
        let event = ProcessAttributedFileEvent(
            processSignature: ProcessSignature(
                bundleID: "com.apple.finder",
                executablePath: "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder",
                displayName: "Finder",
                isGoogleDriveRelated: false
            ),
            targetPath: "/Volumes/Work/Google Drive/Folder/Icon\r",
            operation: .create
        )

        let evaluation = HelperProtectionPolicyEngine().evaluate(event: event, scopes: [scope])

        XCTAssertEqual(evaluation.decision, .allow)
        XCTAssertTrue(evaluation.reason.contains("not classified as Google Drive"))
    }

    func testKeepsSupportedAuditOnlyScopesOutOfBlocking() {
        let scope = DriveManagedScope(
            displayName: "Supported Scope",
            path: "/Volumes/Work/Google Drive",
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .external,
            fileSystemKind: .apfs,
            supportStatus: .supported,
            enforcementMode: .auditOnly
        )
        let event = ProcessAttributedFileEvent(
            processSignature: ProcessSignature(
                bundleID: "com.google.drivefs",
                executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                displayName: "Google Drive",
                isGoogleDriveRelated: true
            ),
            targetPath: "/Volumes/Work/Google Drive/Folder/Icon\r",
            operation: .create
        )

        let evaluation = HelperProtectionPolicyEngine().evaluate(event: event, scopes: [scope])

        XCTAssertEqual(evaluation.decision, .auditOnly)
    }
}
#endif
