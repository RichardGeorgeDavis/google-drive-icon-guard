#if canImport(Testing)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import Testing

@Test
func marksSupportedScopeWithArtefactsAsReady() {
    let planner = ScopeReviewPlanner()
    let scope = DriveManagedScope(
        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        displayName: "My Drive",
        path: "/tmp/My Drive",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .internalVolume,
        fileSystemKind: .apfs,
        supportStatus: .supported
    )
    let scanResult = ScopeArtefactScanResult(
        scopeID: scope.id,
        scopeDisplayName: scope.displayName,
        scopePath: scope.path,
        scanStatus: .scanned,
        matchedArtefactCount: 4,
        matchedBytes: 4096
    )

    let plan = planner.makePlan(for: scope, scanResult: scanResult)

    #expect(plan.priority == ScopeReviewPriority.ready)
    #expect(plan.headline == "Supported scope with remediation candidate")
    #expect(plan.operatorNotes.contains(where: { $0.contains("Recursive scan covered") }))
}

@Test
func keepsAuditOnlyScopeWithArtefactsInAttentionBucket() {
    let planner = ScopeReviewPlanner()
    let scope = DriveManagedScope(
        id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
        displayName: "Stream Scope",
        path: "/tmp/Stream",
        scopeKind: .myDrive,
        driveMode: .stream,
        source: .config,
        volumeKind: .systemManaged,
        fileSystemKind: .apfs,
        supportStatus: .auditOnly
    )
    let scanResult = ScopeArtefactScanResult(
        scopeID: scope.id,
        scopeDisplayName: scope.displayName,
        scopePath: scope.path,
        scanStatus: .scanned,
        matchedArtefactCount: 2,
        matchedBytes: 2048
    )

    let plan = planner.makePlan(for: scope, scanResult: scanResult)

    #expect(plan.priority == ScopeReviewPriority.attention)
    #expect(plan.recommendedAction.contains("keep this scope in audit mode"))
}

@Test
func blocksUnsupportedScope() {
    let planner = ScopeReviewPlanner()
    let scope = DriveManagedScope(
        id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
        displayName: "Unknown Scope",
        path: "/tmp/Unknown",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .internalVolume,
        fileSystemKind: .unknown,
        supportStatus: .unsupported
    )

    let plan = planner.makePlan(for: scope, scanResult: nil)

    #expect(plan.priority == ScopeReviewPriority.blocked)
#expect(plan.headline == "Unsupported scope for protection work")
}
#elseif canImport(XCTest)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import XCTest

final class ScopeReviewPlannerTests: XCTestCase {
    func testMarksSupportedScopeWithArtefactsAsReady() {
        let planner = ScopeReviewPlanner()
        let scope = DriveManagedScope(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            displayName: "My Drive",
            path: "/tmp/My Drive",
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .internalVolume,
            fileSystemKind: .apfs,
            supportStatus: .supported
        )
        let scanResult = ScopeArtefactScanResult(
            scopeID: scope.id,
            scopeDisplayName: scope.displayName,
            scopePath: scope.path,
            scanStatus: .scanned,
            matchedArtefactCount: 4,
            matchedBytes: 4096
        )

        let plan = planner.makePlan(for: scope, scanResult: scanResult)

        XCTAssertEqual(plan.priority, ScopeReviewPriority.ready)
        XCTAssertEqual(plan.headline, "Supported scope with remediation candidate")
        XCTAssertTrue(plan.operatorNotes.contains(where: { $0.contains("Recursive scan covered") }))
    }

    func testKeepsAuditOnlyScopeWithArtefactsInAttentionBucket() {
        let planner = ScopeReviewPlanner()
        let scope = DriveManagedScope(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            displayName: "Stream Scope",
            path: "/tmp/Stream",
            scopeKind: .myDrive,
            driveMode: .stream,
            source: .config,
            volumeKind: .systemManaged,
            fileSystemKind: .apfs,
            supportStatus: .auditOnly
        )
        let scanResult = ScopeArtefactScanResult(
            scopeID: scope.id,
            scopeDisplayName: scope.displayName,
            scopePath: scope.path,
            scanStatus: .scanned,
            matchedArtefactCount: 2,
            matchedBytes: 2048
        )

        let plan = planner.makePlan(for: scope, scanResult: scanResult)

        XCTAssertEqual(plan.priority, ScopeReviewPriority.attention)
        XCTAssertTrue(plan.recommendedAction.contains("keep this scope in audit mode"))
    }

    func testBlocksUnsupportedScope() {
        let planner = ScopeReviewPlanner()
        let scope = DriveManagedScope(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            displayName: "Unknown Scope",
            path: "/tmp/Unknown",
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .internalVolume,
            fileSystemKind: .unknown,
            supportStatus: .unsupported
        )

        let plan = planner.makePlan(for: scope, scanResult: nil)

        XCTAssertEqual(plan.priority, ScopeReviewPriority.blocked)
        XCTAssertEqual(plan.headline, "Unsupported scope for protection work")
    }
}
#endif
