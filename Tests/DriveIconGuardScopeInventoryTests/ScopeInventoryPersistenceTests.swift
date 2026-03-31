#if canImport(Testing)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import Testing

@Test
func persistsLatestAndHistorySnapshots() throws {
    let fileManager = FileManager.default
    let projectRoot = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .path

    let persistence = ScopeInventoryPersistence(fileManager: fileManager)
    let report = ScopeInventoryReport(
        generatedAt: Date(timeIntervalSince1970: 1_711_270_000),
        configLocations: ["/tmp/DriveFS"],
        scopes: [],
        warnings: []
    )

    let result = try persistence.persist(report, projectRoot: projectRoot)

    #expect(fileManager.fileExists(atPath: result.latestURL.path))
    #expect(fileManager.fileExists(atPath: result.historyURL.path))
    #expect(result.historyURL.path.contains("/cache/scope-inventory/history/"))
    #expect(result.historyURL.lastPathComponent == "2024-03-24T08-46-40Z.json")
}

@Test
func loadsRecentSnapshotsAndComputesComparisonDelta() throws {
    let fileManager = FileManager.default
    let projectRoot = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .path

    let persistence = ScopeInventoryPersistence(fileManager: fileManager)
    let previousReport = ScopeInventoryReport(
        generatedAt: Date(timeIntervalSince1970: 1_711_270_000),
        configLocations: ["/tmp/DriveFS"],
        scopes: [
            DriveManagedScope(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                displayName: "My Drive",
                path: "/tmp/My Drive",
                scopeKind: .myDrive,
                driveMode: .mirror,
                source: .config,
                volumeKind: .internalVolume,
                fileSystemKind: .apfs,
                supportStatus: .supported
            )
        ],
        warnings: [DiscoveryWarning(code: "older_warning", message: "older warning")],
        artefactInventory: ArtefactInventorySummary(
            generatedAt: Date(timeIntervalSince1970: 1_711_270_000),
            scannedScopeCount: 1,
            matchedScopeCount: 1,
            totalArtefactCount: 2,
            totalBytes: 2_048,
            scopeResults: [],
            warnings: []
        )
    )
    let currentReport = ScopeInventoryReport(
        generatedAt: Date(timeIntervalSince1970: 1_711_273_600),
        configLocations: ["/tmp/DriveFS"],
        scopes: [
            DriveManagedScope(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                displayName: "My Drive",
                path: "/tmp/My Drive",
                scopeKind: .myDrive,
                driveMode: .mirror,
                source: .config,
                volumeKind: .internalVolume,
                fileSystemKind: .apfs,
                supportStatus: .supported
            ),
            DriveManagedScope(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                displayName: "Desktop",
                path: "/tmp/Desktop",
                scopeKind: .backupFolder,
                driveMode: .backup,
                source: .config,
                volumeKind: .internalVolume,
                fileSystemKind: .apfs,
                supportStatus: .auditOnly
            )
        ],
        warnings: [],
        artefactInventory: ArtefactInventorySummary(
            generatedAt: Date(timeIntervalSince1970: 1_711_273_600),
            scannedScopeCount: 2,
            matchedScopeCount: 2,
            totalArtefactCount: 5,
            totalBytes: 5_120,
            scopeResults: [],
            warnings: [DiscoveryWarning(code: "scan_warning", message: "scan warning")]
        )
    )

    _ = try persistence.persist(previousReport, projectRoot: projectRoot)
    _ = try persistence.persist(currentReport, projectRoot: projectRoot)

    let snapshots = try persistence.loadRecentSnapshots(limit: 5, projectRoot: projectRoot)

    #expect(snapshots.count == 2)
    #expect(snapshots.first?.report.generatedAt == currentReport.generatedAt)
    #expect(snapshots.last?.report.generatedAt == previousReport.generatedAt)

    let comparison = persistence.compare(current: currentReport, previous: previousReport)
    #expect(comparison.delta.scopeCount == 1)
    #expect(comparison.delta.artefactCount == 3)
    #expect(comparison.delta.matchedScopeCount == 1)
    #expect(comparison.delta.totalBytes == 3_072)
    #expect(comparison.delta.warningCount == 0)
    #expect(comparison.delta.perScopeChanges.count == 1)
    #expect(comparison.delta.perScopeChanges.first?.changeKind == .added)
    #expect(comparison.delta.perScopeChanges.first?.scopePath == "/tmp/Desktop")
}

@Test
func persistsAndLoadsActivityLog() throws {
    let fileManager = FileManager.default
    let projectRoot = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .path

    let persistence = ScopeInventoryPersistence(fileManager: fileManager)
    let activityLog = PersistedActivityLog(
        events: [
            EventRecord(
                timestamp: Date(timeIntervalSince1970: 1_711_273_600),
                processSignature: ProcessSignature(
                    bundleID: "com.example.test",
                    executablePath: "/tmp/test",
                    displayName: "Test",
                    isGoogleDriveRelated: false
                ),
                targetPath: "/tmp/My Drive",
                artefactType: .iconFile,
                decision: .auditOnly,
                aggregatedCount: 3,
                rawEventType: "scope_scan_result"
            )
        ]
    )

    try persistence.persistActivityLog(activityLog, projectRoot: projectRoot)
    let loadedLog = try persistence.loadActivityLog(projectRoot: projectRoot)

    #expect(loadedLog == activityLog)
}

@Test
func clearsStoredDataDirectory() throws {
    let fileManager = FileManager.default
    let projectRoot = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .path

    let persistence = ScopeInventoryPersistence(fileManager: fileManager)
    let report = ScopeInventoryReport(
        generatedAt: Date(timeIntervalSince1970: 1_711_270_000),
        configLocations: ["/tmp/DriveFS"],
        scopes: [],
        warnings: []
    )

    _ = try persistence.persist(report, projectRoot: projectRoot)
    try persistence.persistActivityLog(PersistedActivityLog(), projectRoot: projectRoot)
    let storageRoot = persistence.storageRootURL(projectRoot: projectRoot)

    #expect(fileManager.fileExists(atPath: storageRoot.path))

    try persistence.clearStoredData(projectRoot: projectRoot)

    #expect(fileManager.fileExists(atPath: storageRoot.path) == false)
}
#elseif canImport(XCTest)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import XCTest

final class ScopeInventoryPersistenceTests: XCTestCase {
    func testPersistsLatestAndHistorySnapshots() throws {
        let fileManager = FileManager.default
        let projectRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .path

        let persistence = ScopeInventoryPersistence(fileManager: fileManager)
        let report = ScopeInventoryReport(
            generatedAt: Date(timeIntervalSince1970: 1_711_270_000),
            configLocations: ["/tmp/DriveFS"],
            scopes: [],
            warnings: []
        )

        let result = try persistence.persist(report, projectRoot: projectRoot)

        XCTAssertTrue(fileManager.fileExists(atPath: result.latestURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: result.historyURL.path))
        XCTAssertTrue(result.historyURL.path.contains("/cache/scope-inventory/history/"))
        XCTAssertEqual(result.historyURL.lastPathComponent, "2024-03-24T08-46-40Z.json")
    }

    func testLoadsRecentSnapshotsAndComputesComparisonDelta() throws {
        let fileManager = FileManager.default
        let projectRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .path

        let persistence = ScopeInventoryPersistence(fileManager: fileManager)
        let previousReport = ScopeInventoryReport(
            generatedAt: Date(timeIntervalSince1970: 1_711_270_000),
            configLocations: ["/tmp/DriveFS"],
            scopes: [
                DriveManagedScope(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    displayName: "My Drive",
                    path: "/tmp/My Drive",
                    scopeKind: .myDrive,
                    driveMode: .mirror,
                    source: .config,
                    volumeKind: .internalVolume,
                    fileSystemKind: .apfs,
                    supportStatus: .supported
                )
            ],
            warnings: [DiscoveryWarning(code: "older_warning", message: "older warning")],
            artefactInventory: ArtefactInventorySummary(
                generatedAt: Date(timeIntervalSince1970: 1_711_270_000),
                scannedScopeCount: 1,
                matchedScopeCount: 1,
                totalArtefactCount: 2,
                totalBytes: 2_048,
                scopeResults: [],
                warnings: []
            )
        )
        let currentReport = ScopeInventoryReport(
            generatedAt: Date(timeIntervalSince1970: 1_711_273_600),
            configLocations: ["/tmp/DriveFS"],
            scopes: [
                DriveManagedScope(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    displayName: "My Drive",
                    path: "/tmp/My Drive",
                    scopeKind: .myDrive,
                    driveMode: .mirror,
                    source: .config,
                    volumeKind: .internalVolume,
                    fileSystemKind: .apfs,
                    supportStatus: .supported
                ),
                DriveManagedScope(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    displayName: "Desktop",
                    path: "/tmp/Desktop",
                    scopeKind: .backupFolder,
                    driveMode: .backup,
                    source: .config,
                    volumeKind: .internalVolume,
                    fileSystemKind: .apfs,
                    supportStatus: .auditOnly
                )
            ],
            warnings: [],
            artefactInventory: ArtefactInventorySummary(
                generatedAt: Date(timeIntervalSince1970: 1_711_273_600),
                scannedScopeCount: 2,
                matchedScopeCount: 2,
                totalArtefactCount: 5,
                totalBytes: 5_120,
                scopeResults: [],
                warnings: [DiscoveryWarning(code: "scan_warning", message: "scan warning")]
            )
        )

        _ = try persistence.persist(previousReport, projectRoot: projectRoot)
        _ = try persistence.persist(currentReport, projectRoot: projectRoot)

        let snapshots = try persistence.loadRecentSnapshots(limit: 5, projectRoot: projectRoot)

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots.first?.report.generatedAt, currentReport.generatedAt)
        XCTAssertEqual(snapshots.last?.report.generatedAt, previousReport.generatedAt)

        let comparison = persistence.compare(current: currentReport, previous: previousReport)
        XCTAssertEqual(comparison.delta.scopeCount, 1)
        XCTAssertEqual(comparison.delta.artefactCount, 3)
        XCTAssertEqual(comparison.delta.matchedScopeCount, 1)
        XCTAssertEqual(comparison.delta.totalBytes, 3_072)
        XCTAssertEqual(comparison.delta.warningCount, 0)
        XCTAssertEqual(comparison.delta.perScopeChanges.count, 1)
        XCTAssertEqual(comparison.delta.perScopeChanges.first?.changeKind, .added)
        XCTAssertEqual(comparison.delta.perScopeChanges.first?.scopePath, "/tmp/Desktop")
    }

    func testPersistsAndLoadsActivityLog() throws {
        let fileManager = FileManager.default
        let projectRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .path

        let persistence = ScopeInventoryPersistence(fileManager: fileManager)
        let activityLog = PersistedActivityLog(
            events: [
                EventRecord(
                    timestamp: Date(timeIntervalSince1970: 1_711_273_600),
                    processSignature: ProcessSignature(
                        bundleID: "com.example.test",
                        executablePath: "/tmp/test",
                        displayName: "Test",
                        isGoogleDriveRelated: false
                    ),
                    targetPath: "/tmp/My Drive",
                    artefactType: .iconFile,
                    decision: .auditOnly,
                    aggregatedCount: 3,
                    rawEventType: "scope_scan_result"
                )
            ]
        )

        try persistence.persistActivityLog(activityLog, projectRoot: projectRoot)
        let loadedLog = try persistence.loadActivityLog(projectRoot: projectRoot)

        XCTAssertEqual(loadedLog, activityLog)
    }

    func testClearsStoredDataDirectory() throws {
        let fileManager = FileManager.default
        let projectRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .path

        let persistence = ScopeInventoryPersistence(fileManager: fileManager)
        let report = ScopeInventoryReport(
            generatedAt: Date(timeIntervalSince1970: 1_711_270_000),
            configLocations: ["/tmp/DriveFS"],
            scopes: [],
            warnings: []
        )

        _ = try persistence.persist(report, projectRoot: projectRoot)
        try persistence.persistActivityLog(PersistedActivityLog(), projectRoot: projectRoot)
        let storageRoot = persistence.storageRootURL(projectRoot: projectRoot)

        XCTAssertTrue(fileManager.fileExists(atPath: storageRoot.path))

        try persistence.clearStoredData(projectRoot: projectRoot)

        XCTAssertFalse(fileManager.fileExists(atPath: storageRoot.path))
    }
}
#endif
