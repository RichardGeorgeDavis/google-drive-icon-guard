#if canImport(Testing)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Testing

@Test
func supportsNativeMirrorScopeOnExternalVolume() {
    let classifier = ScopeSupportClassifier()
    let scope = DriveManagedScope(
        displayName: "External Mirror",
        path: "/Volumes/Work/Google Drive",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .external,
        fileSystemKind: .apfs,
        supportStatus: .auditOnly
    )

    #expect(classifier.assess(scope: scope).supportStatus == .supported)
}

@Test
func keepsStreamScopesAuditOnly() {
    let classifier = ScopeSupportClassifier()
    let scope = DriveManagedScope(
        displayName: "GoogleDrive",
        path: "/Users/test/Library/CloudStorage/GoogleDrive-test",
        scopeKind: .myDrive,
        driveMode: .stream,
        source: .inferred,
        volumeKind: .systemManaged,
        fileSystemKind: .apfs,
        supportStatus: .auditOnly
    )

    #expect(classifier.assess(scope: scope).supportStatus == .auditOnly)
}

@Test
func keepsExfatBackupScopesAuditOnly() {
    let classifier = ScopeSupportClassifier()
    let scope = DriveManagedScope(
        displayName: "Desktop Backup",
        path: "/Volumes/Shared/Desktop",
        scopeKind: .backupFolder,
        driveMode: .backup,
        source: .config,
        volumeKind: .external,
        fileSystemKind: .exfat,
        supportStatus: .auditOnly
    )

    #expect(classifier.assess(scope: scope).supportStatus == .auditOnly)
}

@Test
func rejectsUnknownFilesystemScopes() {
    let classifier = ScopeSupportClassifier()
    let scope = DriveManagedScope(
        displayName: "Unknown Scope",
        path: "/tmp/Unknown",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .inferred,
        volumeKind: .internalVolume,
        fileSystemKind: .unknown,
        supportStatus: .auditOnly
    )

    #expect(classifier.assess(scope: scope).supportStatus == .unsupported)
}

@Test
func keepsSupportedScopesAuditOnlyUntilProcessAwareProtectionExists() {
    let classifier = ScopeSupportClassifier()
    let scope = DriveManagedScope(
        displayName: "Protected Mirror",
        path: "/Volumes/Work/Google Drive",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .external,
        fileSystemKind: .apfs,
        supportStatus: .auditOnly
    )

    let updated = classifier.applyingAssessment(to: scope)

    #expect(updated.supportStatus == .supported)
    #expect(updated.enforcementMode == .auditOnly)
}
#elseif canImport(XCTest)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import XCTest

final class ScopeSupportClassifierTests: XCTestCase {
    func testSupportsNativeMirrorScopeOnExternalVolume() {
        let classifier = ScopeSupportClassifier()
        let scope = DriveManagedScope(
            displayName: "External Mirror",
            path: "/Volumes/Work/Google Drive",
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .external,
            fileSystemKind: .apfs,
            supportStatus: .auditOnly
        )

        XCTAssertEqual(classifier.assess(scope: scope).supportStatus, .supported)
    }

    func testKeepsStreamScopesAuditOnly() {
        let classifier = ScopeSupportClassifier()
        let scope = DriveManagedScope(
            displayName: "GoogleDrive",
            path: "/Users/test/Library/CloudStorage/GoogleDrive-test",
            scopeKind: .myDrive,
            driveMode: .stream,
            source: .inferred,
            volumeKind: .systemManaged,
            fileSystemKind: .apfs,
            supportStatus: .auditOnly
        )

        XCTAssertEqual(classifier.assess(scope: scope).supportStatus, .auditOnly)
    }

    func testKeepsExfatBackupScopesAuditOnly() {
        let classifier = ScopeSupportClassifier()
        let scope = DriveManagedScope(
            displayName: "Desktop Backup",
            path: "/Volumes/Shared/Desktop",
            scopeKind: .backupFolder,
            driveMode: .backup,
            source: .config,
            volumeKind: .external,
            fileSystemKind: .exfat,
            supportStatus: .auditOnly
        )

        XCTAssertEqual(classifier.assess(scope: scope).supportStatus, .auditOnly)
    }

    func testRejectsUnknownFilesystemScopes() {
        let classifier = ScopeSupportClassifier()
        let scope = DriveManagedScope(
            displayName: "Unknown Scope",
            path: "/tmp/Unknown",
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .inferred,
            volumeKind: .internalVolume,
            fileSystemKind: .unknown,
            supportStatus: .auditOnly
        )

        XCTAssertEqual(classifier.assess(scope: scope).supportStatus, .unsupported)
    }

    func testKeepsSupportedScopesAuditOnlyUntilProcessAwareProtectionExists() {
        let classifier = ScopeSupportClassifier()
        let scope = DriveManagedScope(
            displayName: "Protected Mirror",
            path: "/Volumes/Work/Google Drive",
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .external,
            fileSystemKind: .apfs,
            supportStatus: .auditOnly
        )

        let updated = classifier.applyingAssessment(to: scope)

        XCTAssertEqual(updated.supportStatus, .supported)
        XCTAssertEqual(updated.enforcementMode, .auditOnly)
    }
}
#endif
