#if canImport(Testing)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import Testing

@Test
func enforcesKnownArtefactsForSupportedBlockingScopes() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let artefactURL = rootURL.appendingPathComponent("._Folder")

    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: artefactURL)

    let scope = DriveManagedScope(
        displayName: "Protected Scope",
        path: rootURL.path,
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .internalVolume,
        fileSystemKind: .apfs,
        supportStatus: .supported,
        enforcementMode: .blockKnownArtefacts
    )

    let engine = ScopeEnforcementEngine(
        artefactScanner: ArtefactScanner(fileManager: fileManager),
        remediationPlanner: ScopeRemediationPlanner(fileManager: fileManager)
    )
    let events = engine.enforce(scopes: [scope])

    #expect(events.count == 1)
    #expect(events.first?.detectedArtefactCount == 1)
    #expect(events.first?.applyResult.status == .applied)
    #expect(fileManager.fileExists(atPath: artefactURL.path) == false)
}

@Test
func ignoresAuditOnlyScopesDuringEnforcement() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let artefactURL = rootURL.appendingPathComponent("._Folder")

    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: artefactURL)

    let scope = DriveManagedScope(
        displayName: "Audit Scope",
        path: rootURL.path,
        scopeKind: .myDrive,
        driveMode: .stream,
        source: .config,
        volumeKind: .systemManaged,
        fileSystemKind: .apfs,
        supportStatus: .auditOnly,
        enforcementMode: .auditOnly
    )

    let engine = ScopeEnforcementEngine(
        artefactScanner: ArtefactScanner(fileManager: fileManager),
        remediationPlanner: ScopeRemediationPlanner(fileManager: fileManager)
    )
    let events = engine.enforce(scopes: [scope])

    #expect(events.isEmpty)
    #expect(fileManager.fileExists(atPath: artefactURL.path))
}
#elseif canImport(XCTest)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import XCTest

final class ScopeEnforcementEngineTests: XCTestCase {
    func testEnforcesKnownArtefactsForSupportedBlockingScopes() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let artefactURL = rootURL.appendingPathComponent("._Folder")

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: artefactURL)

        let scope = DriveManagedScope(
            displayName: "Protected Scope",
            path: rootURL.path,
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .internalVolume,
            fileSystemKind: .apfs,
            supportStatus: .supported,
            enforcementMode: .blockKnownArtefacts
        )

        let engine = ScopeEnforcementEngine(
            artefactScanner: ArtefactScanner(fileManager: fileManager),
            remediationPlanner: ScopeRemediationPlanner(fileManager: fileManager)
        )
        let events = engine.enforce(scopes: [scope])

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.detectedArtefactCount, 1)
        XCTAssertEqual(events.first?.applyResult.status, .applied)
        XCTAssertFalse(fileManager.fileExists(atPath: artefactURL.path))
    }

    func testIgnoresAuditOnlyScopesDuringEnforcement() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let artefactURL = rootURL.appendingPathComponent("._Folder")

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: artefactURL)

        let scope = DriveManagedScope(
            displayName: "Audit Scope",
            path: rootURL.path,
            scopeKind: .myDrive,
            driveMode: .stream,
            source: .config,
            volumeKind: .systemManaged,
            fileSystemKind: .apfs,
            supportStatus: .auditOnly,
            enforcementMode: .auditOnly
        )

        let engine = ScopeEnforcementEngine(
            artefactScanner: ArtefactScanner(fileManager: fileManager),
            remediationPlanner: ScopeRemediationPlanner(fileManager: fileManager)
        )
        let events = engine.enforce(scopes: [scope])

        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(fileManager.fileExists(atPath: artefactURL.path))
    }
}
#endif
