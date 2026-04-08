#if canImport(Testing)
import DriveIconGuardHelper
import DriveIconGuardIPC
import Foundation
import Testing

@Test
func callbackBridgeMapsCreateAndRenameAndUnlinkOperations() {
    let bridge = EndpointSecurityCallbackBridge()
    let process = EndpointSecurityProcessMetadata(
        pid: 9,
        executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
        displayName: "Google Drive",
        bundleID: "com.google.drivefs"
    )

    let createEvent = bridge.map(
        EndpointSecurityRawCallbackEvent(operation: .create, targetPath: "/tmp/a", process: process)
    )
    let renameEvent = bridge.map(
        EndpointSecurityRawCallbackEvent(operation: .rename, targetPath: "/tmp/b", process: process)
    )
    let unlinkEvent = bridge.map(
        EndpointSecurityRawCallbackEvent(operation: .unlink, targetPath: "/tmp/c", process: process)
    )

    #expect(createEvent?.operation == .create)
    #expect(renameEvent?.operation == .rename)
    #expect(unlinkEvent?.operation == .delete)
}

@Test
func callbackBridgeRejectsEmptyTargetPath() {
    let bridge = EndpointSecurityCallbackBridge()
    let process = EndpointSecurityProcessMetadata(
        pid: 10,
        executablePath: "/usr/bin/touch",
        displayName: "touch"
    )

    let result = bridge.map(
        EndpointSecurityRawCallbackEvent(
            operation: .create,
            targetPath: "   ",
            process: process
        )
    )

    #expect(result == nil)
}

@Test
func callbackBridgePreservesCarriageReturnInArtefactPath() {
    let bridge = EndpointSecurityCallbackBridge()
    let process = EndpointSecurityProcessMetadata(
        pid: 11,
        executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
        displayName: "Google Drive",
        bundleID: "com.google.drivefs"
    )

    let result = bridge.map(
        EndpointSecurityRawCallbackEvent(
            operation: .create,
            targetPath: "/tmp/Icon\r",
            process: process
        )
    )

    #expect(result?.targetPath == "/tmp/Icon\r")
}
#elseif canImport(XCTest)
import DriveIconGuardHelper
import DriveIconGuardIPC
import Foundation
import XCTest

final class EndpointSecurityCallbackBridgeTests: XCTestCase {
    func testCallbackBridgeMapsCreateAndRenameAndUnlinkOperations() {
        let bridge = EndpointSecurityCallbackBridge()
        let process = EndpointSecurityProcessMetadata(
            pid: 9,
            executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
            displayName: "Google Drive",
            bundleID: "com.google.drivefs"
        )

        let createEvent = bridge.map(
            EndpointSecurityRawCallbackEvent(operation: .create, targetPath: "/tmp/a", process: process)
        )
        let renameEvent = bridge.map(
            EndpointSecurityRawCallbackEvent(operation: .rename, targetPath: "/tmp/b", process: process)
        )
        let unlinkEvent = bridge.map(
            EndpointSecurityRawCallbackEvent(operation: .unlink, targetPath: "/tmp/c", process: process)
        )

        XCTAssertEqual(createEvent?.operation, .create)
        XCTAssertEqual(renameEvent?.operation, .rename)
        XCTAssertEqual(unlinkEvent?.operation, .delete)
    }

    func testCallbackBridgeRejectsEmptyTargetPath() {
        let bridge = EndpointSecurityCallbackBridge()
        let process = EndpointSecurityProcessMetadata(
            pid: 10,
            executablePath: "/usr/bin/touch",
            displayName: "touch"
        )

        let result = bridge.map(
            EndpointSecurityRawCallbackEvent(
                operation: .create,
                targetPath: "   ",
                process: process
            )
        )

        XCTAssertNil(result)
    }

    func testCallbackBridgePreservesCarriageReturnInArtefactPath() {
        let bridge = EndpointSecurityCallbackBridge()
        let process = EndpointSecurityProcessMetadata(
            pid: 11,
            executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
            displayName: "Google Drive",
            bundleID: "com.google.drivefs"
        )

        let result = bridge.map(
            EndpointSecurityRawCallbackEvent(
                operation: .create,
                targetPath: "/tmp/Icon\r",
                process: process
            )
        )

        XCTAssertEqual(result?.targetPath, "/tmp/Icon\r")
    }
}
#endif
