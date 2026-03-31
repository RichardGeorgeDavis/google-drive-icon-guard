#if canImport(Testing)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import Testing

@Test
func exportsMarkdownReportWithScopeDetails() {
    let report = ScopeInventoryReport(
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
            )
        ],
        warnings: [DiscoveryWarning(code: "sample_warning", message: "Sample warning")],
        artefactInventory: ArtefactInventorySummary(
            generatedAt: Date(timeIntervalSince1970: 1_711_273_600),
            scannedScopeCount: 1,
            matchedScopeCount: 1,
            totalArtefactCount: 3,
            totalBytes: 6_144,
            scopeResults: [
                ScopeArtefactScanResult(
                    scopeID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    scopeDisplayName: "My Drive",
                    scopePath: "/tmp/My Drive",
                    scanStatus: .scanned,
                    scannedDirectoryCount: 3,
                    inspectedFileCount: 8,
                    skippedSymbolicLinkCount: 1,
                    matchedArtefactCount: 3,
                    matchedBytes: 6_144,
                    artefactSummaries: [
                        ArtefactTypeSummary(artefactType: .iconFile, count: 1, totalBytes: 4_096),
                        ArtefactTypeSummary(artefactType: .iconSidecar, count: 2, totalBytes: 2_048)
                    ],
                    sampleMatches: [
                        ArtefactSample(
                            relativePath: "Folder/Icon\r",
                            artefactType: .iconFile,
                            ruleID: "icon-carriage-return-file",
                            ruleName: "Finder Icon carriage-return file",
                            sizeBytes: 4_096
                        )
                    ]
                )
            ],
            warnings: []
        )
    )

    let markdown = ScopeInventoryReportExporter().markdownReport(for: report)

    #expect(markdown.contains("# Google Drive Icon Guard Findings"))
    #expect(markdown.contains("### My Drive"))
    #expect(markdown.contains("Review Priority: `ready`"))
    #expect(markdown.contains("`iconFile`: 1"))
    #expect(markdown.contains("Coverage: 3 directories, 8 files inspected, 1 symbolic link skipped"))
    #expect(markdown.contains("Sample warning"))
}

@Test
func exportsScopeOnlyMarkdownReport() {
    let firstScopeID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let secondScopeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let report = ScopeInventoryReport(
        generatedAt: Date(timeIntervalSince1970: 1_711_273_600),
        configLocations: ["/tmp/DriveFS"],
        scopes: [
            DriveManagedScope(
                id: firstScopeID,
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
                id: secondScopeID,
                displayName: "Other Scope",
                path: "/tmp/Other",
                scopeKind: .backupFolder,
                driveMode: .backup,
                source: .config,
                volumeKind: .external,
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
            totalBytes: 8_192,
            scopeResults: [
                ScopeArtefactScanResult(
                    scopeID: firstScopeID,
                    scopeDisplayName: "My Drive",
                    scopePath: "/tmp/My Drive",
                    scanStatus: .scanned,
                    scannedDirectoryCount: 3,
                    inspectedFileCount: 8,
                    skippedSymbolicLinkCount: 1,
                    matchedArtefactCount: 3,
                    matchedBytes: 6_144
                ),
                ScopeArtefactScanResult(
                    scopeID: secondScopeID,
                    scopeDisplayName: "Other Scope",
                    scopePath: "/tmp/Other",
                    scanStatus: .scanned,
                    scannedDirectoryCount: 2,
                    inspectedFileCount: 4,
                    skippedSymbolicLinkCount: 0,
                    matchedArtefactCount: 2,
                    matchedBytes: 2_048
                )
            ],
            warnings: []
        )
    )

    let markdown = ScopeInventoryReportExporter().markdownReport(for: report, scopeID: firstScopeID)

    #expect(markdown?.contains("- Scopes: 1") == true)
    #expect(markdown?.contains("- Artefacts: 3") == true)
    #expect(markdown?.contains("### My Drive") == true)
    #expect(markdown?.contains("### Other Scope") == false)
}
#elseif canImport(XCTest)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import XCTest

final class ScopeInventoryReportExporterTests: XCTestCase {
    func testExportsMarkdownReportWithScopeDetails() {
        let report = ScopeInventoryReport(
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
                )
            ],
            warnings: [DiscoveryWarning(code: "sample_warning", message: "Sample warning")],
            artefactInventory: ArtefactInventorySummary(
                generatedAt: Date(timeIntervalSince1970: 1_711_273_600),
                scannedScopeCount: 1,
                matchedScopeCount: 1,
                totalArtefactCount: 3,
                totalBytes: 6_144,
                scopeResults: [
                    ScopeArtefactScanResult(
                        scopeID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                        scopeDisplayName: "My Drive",
                        scopePath: "/tmp/My Drive",
                        scanStatus: .scanned,
                        scannedDirectoryCount: 3,
                        inspectedFileCount: 8,
                        skippedSymbolicLinkCount: 1,
                        matchedArtefactCount: 3,
                        matchedBytes: 6_144,
                        artefactSummaries: [
                            ArtefactTypeSummary(artefactType: .iconFile, count: 1, totalBytes: 4_096),
                            ArtefactTypeSummary(artefactType: .iconSidecar, count: 2, totalBytes: 2_048)
                        ],
                        sampleMatches: [
                            ArtefactSample(
                                relativePath: "Folder/Icon\r",
                                artefactType: .iconFile,
                                ruleID: "icon-carriage-return-file",
                                ruleName: "Finder Icon carriage-return file",
                                sizeBytes: 4_096
                            )
                        ]
                    )
                ],
                warnings: []
            )
        )

        let markdown = ScopeInventoryReportExporter().markdownReport(for: report)

        XCTAssertTrue(markdown.contains("# Google Drive Icon Guard Findings"))
        XCTAssertTrue(markdown.contains("### My Drive"))
        XCTAssertTrue(markdown.contains("Review Priority: `ready`"))
        XCTAssertTrue(markdown.contains("`iconFile`: 1"))
        XCTAssertTrue(markdown.contains("Coverage: 3 directories, 8 files inspected, 1 symbolic link skipped"))
        XCTAssertTrue(markdown.contains("Sample warning"))
    }

    func testExportsScopeOnlyMarkdownReport() {
        let firstScopeID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondScopeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let report = ScopeInventoryReport(
            generatedAt: Date(timeIntervalSince1970: 1_711_273_600),
            configLocations: ["/tmp/DriveFS"],
            scopes: [
                DriveManagedScope(
                    id: firstScopeID,
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
                    id: secondScopeID,
                    displayName: "Other Scope",
                    path: "/tmp/Other",
                    scopeKind: .backupFolder,
                    driveMode: .backup,
                    source: .config,
                    volumeKind: .external,
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
                totalBytes: 8_192,
                scopeResults: [
                    ScopeArtefactScanResult(
                        scopeID: firstScopeID,
                        scopeDisplayName: "My Drive",
                        scopePath: "/tmp/My Drive",
                        scanStatus: .scanned,
                        scannedDirectoryCount: 3,
                        inspectedFileCount: 8,
                        skippedSymbolicLinkCount: 1,
                        matchedArtefactCount: 3,
                        matchedBytes: 6_144
                    ),
                    ScopeArtefactScanResult(
                        scopeID: secondScopeID,
                        scopeDisplayName: "Other Scope",
                        scopePath: "/tmp/Other",
                        scanStatus: .scanned,
                        scannedDirectoryCount: 2,
                        inspectedFileCount: 4,
                        skippedSymbolicLinkCount: 0,
                        matchedArtefactCount: 2,
                        matchedBytes: 2_048
                    )
                ],
                warnings: []
            )
        )

        let markdown = ScopeInventoryReportExporter().markdownReport(for: report, scopeID: firstScopeID)

        XCTAssertTrue(markdown?.contains("- Scopes: 1") == true)
        XCTAssertTrue(markdown?.contains("- Artefacts: 3") == true)
        XCTAssertTrue(markdown?.contains("### My Drive") == true)
        XCTAssertTrue(markdown?.contains("### Other Scope") == false)
    }
}
#endif
