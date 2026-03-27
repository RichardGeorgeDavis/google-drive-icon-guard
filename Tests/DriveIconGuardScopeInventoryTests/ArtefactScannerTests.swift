#if canImport(Testing)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import Testing

@Test
func detectsAuditOnlyArtefactsWithinSupportedScope() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let folderURL = rootURL.appendingPathComponent("Folder", isDirectory: true)

    try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: rootURL.appendingPathComponent("._Folder"))
    try Data([1, 2, 3, 4]).write(to: folderURL.appendingPathComponent("Icon\r"))
    try Data([9, 9]).write(to: rootURL.appendingPathComponent("visible.txt"))

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

    let summary = ArtefactScanner(fileManager: fileManager).scan(scopes: [scope])

    #expect(summary.scannedScopeCount == 1)
    #expect(summary.matchedScopeCount == 1)
    #expect(summary.totalArtefactCount == 2)
    #expect(summary.totalBytes == 7)
    #expect(summary.warnings.isEmpty)
    #expect(summary.scopeResults.first?.scanStatus == .scanned)
    #expect(summary.scopeResults.first?.sampleMatches.count == 2)
    #expect(summary.scopeResults.first?.sampleMatches.contains(where: { $0.relativePath == "._Folder" && $0.artefactType == .iconSidecar }) == true)
    #expect(summary.scopeResults.first?.sampleMatches.contains(where: { $0.relativePath == "Folder/Icon\r" && $0.artefactType == .iconFile }) == true)
}

@Test
func skipsUnsupportedScopesAndWarnsOnMissingSupportedPaths() {
    let unsupportedScope = DriveManagedScope(
        displayName: "Unsupported Scope",
        path: "/tmp/Unsupported",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .internalVolume,
        fileSystemKind: .unknown,
        supportStatus: .unsupported
    )

    let missingScope = DriveManagedScope(
        displayName: "Missing Scope",
        path: "/tmp/Definitely-Missing-\(UUID().uuidString)",
        scopeKind: .backupFolder,
        driveMode: .backup,
        source: .config,
        volumeKind: .external,
        fileSystemKind: .apfs,
        supportStatus: .auditOnly
    )

    let summary = ArtefactScanner().scan(scopes: [unsupportedScope, missingScope])

    #expect(summary.scannedScopeCount == 0)
    #expect(summary.totalArtefactCount == 0)
    #expect(summary.scopeResults.first(where: { $0.scopeID == unsupportedScope.id })?.scanStatus == .skippedUnsupported)
    #expect(summary.scopeResults.first(where: { $0.scopeID == missingScope.id })?.scanStatus == .missingPath)
    #expect(summary.warnings.contains(where: { $0.code == "scope_scan_path_missing" }))
}
#elseif canImport(XCTest)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import XCTest

final class ArtefactScannerTests: XCTestCase {
    func testDetectsAuditOnlyArtefactsWithinSupportedScope() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let folderURL = rootURL.appendingPathComponent("Folder", isDirectory: true)

        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: rootURL.appendingPathComponent("._Folder"))
        try Data([1, 2, 3, 4]).write(to: folderURL.appendingPathComponent("Icon\r"))
        try Data([9, 9]).write(to: rootURL.appendingPathComponent("visible.txt"))

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

        let summary = ArtefactScanner(fileManager: fileManager).scan(scopes: [scope])

        XCTAssertEqual(summary.scannedScopeCount, 1)
        XCTAssertEqual(summary.matchedScopeCount, 1)
        XCTAssertEqual(summary.totalArtefactCount, 2)
        XCTAssertEqual(summary.totalBytes, 7)
        XCTAssertTrue(summary.warnings.isEmpty)
        XCTAssertEqual(summary.scopeResults.first?.scanStatus, .scanned)
        XCTAssertEqual(summary.scopeResults.first?.sampleMatches.count, 2)
        XCTAssertTrue(summary.scopeResults.first?.sampleMatches.contains(where: { $0.relativePath == "._Folder" && $0.artefactType == .iconSidecar }) == true)
        XCTAssertTrue(summary.scopeResults.first?.sampleMatches.contains(where: { $0.relativePath == "Folder/Icon\r" && $0.artefactType == .iconFile }) == true)
    }

    func testSkipsUnsupportedScopesAndWarnsOnMissingSupportedPaths() {
        let unsupportedScope = DriveManagedScope(
            displayName: "Unsupported Scope",
            path: "/tmp/Unsupported",
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .internalVolume,
            fileSystemKind: .unknown,
            supportStatus: .unsupported
        )

        let missingScope = DriveManagedScope(
            displayName: "Missing Scope",
            path: "/tmp/Definitely-Missing-\(UUID().uuidString)",
            scopeKind: .backupFolder,
            driveMode: .backup,
            source: .config,
            volumeKind: .external,
            fileSystemKind: .apfs,
            supportStatus: .auditOnly
        )

        let summary = ArtefactScanner().scan(scopes: [unsupportedScope, missingScope])

        XCTAssertEqual(summary.scannedScopeCount, 0)
        XCTAssertEqual(summary.totalArtefactCount, 0)
        XCTAssertEqual(summary.scopeResults.first(where: { $0.scopeID == unsupportedScope.id })?.scanStatus, .skippedUnsupported)
        XCTAssertEqual(summary.scopeResults.first(where: { $0.scopeID == missingScope.id })?.scanStatus, .missingPath)
        XCTAssertTrue(summary.warnings.contains(where: { $0.code == "scope_scan_path_missing" }))
    }
}
#endif
