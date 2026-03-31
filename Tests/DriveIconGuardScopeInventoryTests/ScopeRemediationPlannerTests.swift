#if canImport(Testing)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import Testing

@Test
func preparesDryRunPreviewForSupportedScope() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: rootURL.appendingPathComponent("._Folder"))

    let scope = DriveManagedScope(
        displayName: "Supported Scope",
        path: rootURL.path,
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .internalVolume,
        fileSystemKind: .apfs,
        supportStatus: .supported
    )

    let preview = ScopeRemediationPlanner(fileManager: fileManager).dryRunPreview(for: scope)

    #expect(preview.status == .ready)
    #expect(preview.totalCandidateCount == 1)
    #expect(preview.candidates.first?.relativePath == "._Folder")
}

@Test
func blocksDryRunForAuditOnlyScope() {
    let scope = DriveManagedScope(
        displayName: "Audit Scope",
        path: "/tmp/Audit",
        scopeKind: .myDrive,
        driveMode: .stream,
        source: .config,
        volumeKind: .systemManaged,
        fileSystemKind: .apfs,
        supportStatus: .auditOnly
    )

    let preview = ScopeRemediationPlanner().dryRunPreview(for: scope)

    #expect(preview.status == .unavailable)
    #expect(preview.totalCandidateCount == 0)
}

@Test
func appliesCleanupForSupportedScope() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let artefactURL = rootURL.appendingPathComponent("._Folder")

    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: artefactURL)

    let scope = DriveManagedScope(
        displayName: "Supported Scope",
        path: rootURL.path,
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .internalVolume,
        fileSystemKind: .apfs,
        supportStatus: .supported
    )

    let result = ScopeRemediationPlanner(fileManager: fileManager).applyCleanup(for: scope)

    #expect(result.status == .applied)
    #expect(result.removedCount == 1)
    #expect(fileManager.fileExists(atPath: artefactURL.path) == false)
}

@Test
func blocksCleanupForAuditOnlyScope() {
    let scope = DriveManagedScope(
        displayName: "Audit Scope",
        path: "/tmp/Audit",
        scopeKind: .myDrive,
        driveMode: .stream,
        source: .config,
        volumeKind: .systemManaged,
        fileSystemKind: .apfs,
        supportStatus: .auditOnly
    )

    let result = ScopeRemediationPlanner().applyCleanup(for: scope)

    #expect(result.status == .unavailable)
    #expect(result.removedCount == 0)
}
#elseif canImport(XCTest)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import XCTest

final class ScopeRemediationPlannerTests: XCTestCase {
    func testPreparesDryRunPreviewForSupportedScope() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: rootURL.appendingPathComponent("._Folder"))

        let scope = DriveManagedScope(
            displayName: "Supported Scope",
            path: rootURL.path,
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .internalVolume,
            fileSystemKind: .apfs,
            supportStatus: .supported
        )

        let preview = ScopeRemediationPlanner(fileManager: fileManager).dryRunPreview(for: scope)

        XCTAssertEqual(preview.status, .ready)
        XCTAssertEqual(preview.totalCandidateCount, 1)
        XCTAssertEqual(preview.candidates.first?.relativePath, "._Folder")
    }

    func testBlocksDryRunForAuditOnlyScope() {
        let scope = DriveManagedScope(
            displayName: "Audit Scope",
            path: "/tmp/Audit",
            scopeKind: .myDrive,
            driveMode: .stream,
            source: .config,
            volumeKind: .systemManaged,
            fileSystemKind: .apfs,
            supportStatus: .auditOnly
        )

        let preview = ScopeRemediationPlanner().dryRunPreview(for: scope)

        XCTAssertEqual(preview.status, .unavailable)
        XCTAssertEqual(preview.totalCandidateCount, 0)
    }

    func testAppliesCleanupForSupportedScope() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let artefactURL = rootURL.appendingPathComponent("._Folder")

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: artefactURL)

        let scope = DriveManagedScope(
            displayName: "Supported Scope",
            path: rootURL.path,
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .internalVolume,
            fileSystemKind: .apfs,
            supportStatus: .supported
        )

        let result = ScopeRemediationPlanner(fileManager: fileManager).applyCleanup(for: scope)

        XCTAssertEqual(result.status, .applied)
        XCTAssertEqual(result.removedCount, 1)
        XCTAssertFalse(fileManager.fileExists(atPath: artefactURL.path))
    }

    func testBlocksCleanupForAuditOnlyScope() {
        let scope = DriveManagedScope(
            displayName: "Audit Scope",
            path: "/tmp/Audit",
            scopeKind: .myDrive,
            driveMode: .stream,
            source: .config,
            volumeKind: .systemManaged,
            fileSystemKind: .apfs,
            supportStatus: .auditOnly
        )

        let result = ScopeRemediationPlanner().applyCleanup(for: scope)

        XCTAssertEqual(result.status, .unavailable)
        XCTAssertEqual(result.removedCount, 0)
    }
}
#endif
