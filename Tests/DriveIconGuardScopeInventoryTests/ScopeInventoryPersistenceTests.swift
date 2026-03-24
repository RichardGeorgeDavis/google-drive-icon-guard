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
}
#endif
