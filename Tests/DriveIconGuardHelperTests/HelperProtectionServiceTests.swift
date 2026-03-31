#if canImport(Testing)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared
import Foundation
import Testing

private final class EvaluationBox: @unchecked Sendable {
    var value: HelperProtectionEvaluation?
}

@Test
func helperProtectionServiceEvaluatesInjectedAttributedEvents() throws {
    let scope = DriveManagedScope(
        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
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
    let service = HelperProtectionService()
    service.updateScopes([scope])

    let captured = EvaluationBox()
    service.start { evaluation in
        captured.value = evaluation
    }

    let evaluation = service.process(
        ProcessAttributedFileEvent(
            processSignature: ProcessSignature(
                bundleID: "com.google.drivefs",
                executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                displayName: "Google Drive",
                isGoogleDriveRelated: true
            ),
            targetPath: "/Volumes/Work/Google Drive/Folder/Icon\r",
            operation: .create
        )
    )

    #expect(evaluation.decision == .deny)
    #expect(captured.value?.decision == .deny)
}

@Test
func helperProtectionServiceAllowsEventsOutsideProtectedScopes() {
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
    let service = HelperProtectionService()
    service.updateScopes([scope])

    let evaluation = service.process(
        ProcessAttributedFileEvent(
            processSignature: ProcessSignature(
                bundleID: "com.google.drivefs",
                executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                displayName: "Google Drive",
                isGoogleDriveRelated: true
            ),
            targetPath: "/tmp/Other/Icon\r",
            operation: .create
        )
    )

    #expect(evaluation.decision == .allow)
}

@Test
func helperProtectionServiceExposesSubscriberRuntimeStatus() {
    let service = HelperProtectionService(subscriber: UnavailableProcessAttributedEventSubscriber())

    let status = service.runtimeStatus()

    #expect(status.state == .unavailable)
    #expect(status.detail.contains("No process-attributed event source"))
}
#elseif canImport(XCTest)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared
import Foundation
import XCTest

private final class EvaluationBox: @unchecked Sendable {
    var value: HelperProtectionEvaluation?
}

final class HelperProtectionServiceTests: XCTestCase {
    func testHelperProtectionServiceEvaluatesInjectedAttributedEvents() {
        let scope = DriveManagedScope(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
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
        let service = HelperProtectionService()
        service.updateScopes([scope])

        let captured = EvaluationBox()
        service.start { evaluation in
            captured.value = evaluation
        }

        let evaluation = service.process(
            ProcessAttributedFileEvent(
                processSignature: ProcessSignature(
                    bundleID: "com.google.drivefs",
                    executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                    displayName: "Google Drive",
                    isGoogleDriveRelated: true
                ),
                targetPath: "/Volumes/Work/Google Drive/Folder/Icon\r",
                operation: .create
            )
        )

        XCTAssertEqual(evaluation.decision, .deny)
        XCTAssertEqual(captured.value?.decision, .deny)
    }

    func testHelperProtectionServiceAllowsEventsOutsideProtectedScopes() {
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
        let service = HelperProtectionService()
        service.updateScopes([scope])

        let evaluation = service.process(
            ProcessAttributedFileEvent(
                processSignature: ProcessSignature(
                    bundleID: "com.google.drivefs",
                    executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                    displayName: "Google Drive",
                    isGoogleDriveRelated: true
                ),
                targetPath: "/tmp/Other/Icon\r",
                operation: .create
            )
        )

        XCTAssertEqual(evaluation.decision, .allow)
    }

    func testHelperProtectionServiceExposesSubscriberRuntimeStatus() {
        let service = HelperProtectionService(subscriber: UnavailableProcessAttributedEventSubscriber())

        let status = service.runtimeStatus()

        XCTAssertEqual(status.state, .unavailable)
        XCTAssertTrue(status.detail.contains("No process-attributed event source"))
    }
}
#endif
