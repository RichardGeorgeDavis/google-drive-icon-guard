#if canImport(Testing)
import DriveIconGuardHelper
import DriveIconGuardIPC
import Foundation
import Testing

@Test
func endpointSecurityMapperBuildsProcessAttributedEvent() {
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
    let mapper = EndpointSecurityEventMapper()
    let source = EndpointSecurityFileCandidateEvent(
        timestamp: timestamp,
        operation: .rename,
        targetPath: "/Volumes/Sync/G Drive/Folder/Icon\r",
        process: EndpointSecurityProcessMetadata(
            pid: 123,
            executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
            displayName: "Google Drive",
            bundleID: "com.google.drivefs",
            signingIdentity: "TEAMID.com.google.drivefs"
        )
    )

    let mapped = mapper.map(source)

    #expect(mapped.timestamp == timestamp)
    #expect(mapped.operation == .rename)
    #expect(mapped.targetPath == source.targetPath)
    #expect(mapped.processSignature.bundleID == "com.google.drivefs")
    #expect(mapped.processSignature.isGoogleDriveRelated)
}

@Test
func endpointSecurityMapperLeavesUnknownProcessAsNonDrive() {
    let mapper = EndpointSecurityEventMapper()
    let source = EndpointSecurityFileCandidateEvent(
        operation: .create,
        targetPath: "/tmp/test/Icon\r",
        process: EndpointSecurityProcessMetadata(
            pid: 44,
            executablePath: "/usr/bin/touch",
            displayName: "touch"
        )
    )

    let mapped = mapper.map(source)
    #expect(mapped.processSignature.isGoogleDriveRelated == false)
}

@Test
func endpointSecurityMapperPreservesWhitespaceInTargetPath() {
    let mapper = EndpointSecurityEventMapper()
    let source = EndpointSecurityFileCandidateEvent(
        operation: .create,
        targetPath: " /tmp/Icon\r ",
        process: EndpointSecurityProcessMetadata(
            pid: 88,
            executablePath: "/usr/bin/touch",
            displayName: "touch"
        )
    )

    let mapped = mapper.map(source)
    #expect(mapped.targetPath == " /tmp/Icon\r ")
}

@Test
func endpointSecurityMapperPropagatesMissingBundleMetadata() {
    let mapper = EndpointSecurityEventMapper()
    let source = EndpointSecurityFileCandidateEvent(
        operation: .rename,
        targetPath: "/tmp/Icon\r",
        process: EndpointSecurityProcessMetadata(
            pid: 99,
            executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
            displayName: "Google Drive",
            bundleID: nil,
            signingIdentity: nil
        )
    )

    let mapped = mapper.map(source)
    #expect(mapped.processSignature.bundleID == nil)
    #expect(mapped.processSignature.signingIdentity == nil)
    #expect(mapped.processSignature.isGoogleDriveRelated)
}

@Test
func endpointSecurityPathBuilderJoinsDirectoryAndFilename() {
    let path = EndpointSecurityPathBuilder.join(directoryPath: "/tmp/folder", fileName: "Icon\r")
    #expect(path == "/tmp/folder/Icon\r")
}

@Test
func endpointSecurityPathBuilderHandlesMissingComponents() {
    #expect(EndpointSecurityPathBuilder.join(directoryPath: " ", fileName: "Icon\r") == "Icon\r")
    #expect(EndpointSecurityPathBuilder.join(directoryPath: "/tmp/folder", fileName: " ") == "/tmp/folder")
}
#elseif canImport(XCTest)
import DriveIconGuardHelper
import DriveIconGuardIPC
import Foundation
import XCTest

final class EndpointSecurityEventMapperTests: XCTestCase {
    func testEndpointSecurityMapperBuildsProcessAttributedEvent() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let mapper = EndpointSecurityEventMapper()
        let source = EndpointSecurityFileCandidateEvent(
            timestamp: timestamp,
            operation: .rename,
            targetPath: "/Volumes/Sync/G Drive/Folder/Icon\r",
            process: EndpointSecurityProcessMetadata(
                pid: 123,
                executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                displayName: "Google Drive",
                bundleID: "com.google.drivefs",
                signingIdentity: "TEAMID.com.google.drivefs"
            )
        )

        let mapped = mapper.map(source)

        XCTAssertEqual(mapped.timestamp, timestamp)
        XCTAssertEqual(mapped.operation, .rename)
        XCTAssertEqual(mapped.targetPath, source.targetPath)
        XCTAssertEqual(mapped.processSignature.bundleID, "com.google.drivefs")
        XCTAssertTrue(mapped.processSignature.isGoogleDriveRelated)
    }

    func testEndpointSecurityMapperLeavesUnknownProcessAsNonDrive() {
        let mapper = EndpointSecurityEventMapper()
        let source = EndpointSecurityFileCandidateEvent(
            operation: .create,
            targetPath: "/tmp/test/Icon\r",
            process: EndpointSecurityProcessMetadata(
                pid: 44,
                executablePath: "/usr/bin/touch",
                displayName: "touch"
            )
        )

        let mapped = mapper.map(source)
        XCTAssertFalse(mapped.processSignature.isGoogleDriveRelated)
    }

    func testEndpointSecurityMapperPreservesWhitespaceInTargetPath() {
        let mapper = EndpointSecurityEventMapper()
        let source = EndpointSecurityFileCandidateEvent(
            operation: .create,
            targetPath: " /tmp/Icon\r ",
            process: EndpointSecurityProcessMetadata(
                pid: 88,
                executablePath: "/usr/bin/touch",
                displayName: "touch"
            )
        )

        let mapped = mapper.map(source)
        XCTAssertEqual(mapped.targetPath, " /tmp/Icon\r ")
    }

    func testEndpointSecurityMapperPropagatesMissingBundleMetadata() {
        let mapper = EndpointSecurityEventMapper()
        let source = EndpointSecurityFileCandidateEvent(
            operation: .rename,
            targetPath: "/tmp/Icon\r",
            process: EndpointSecurityProcessMetadata(
                pid: 99,
                executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                displayName: "Google Drive",
                bundleID: nil,
                signingIdentity: nil
            )
        )

        let mapped = mapper.map(source)
        XCTAssertNil(mapped.processSignature.bundleID)
        XCTAssertNil(mapped.processSignature.signingIdentity)
        XCTAssertTrue(mapped.processSignature.isGoogleDriveRelated)
    }

    func testEndpointSecurityPathBuilderJoinsDirectoryAndFilename() {
        let path = EndpointSecurityPathBuilder.join(directoryPath: "/tmp/folder", fileName: "Icon\r")
        XCTAssertEqual(path, "/tmp/folder/Icon\r")
    }

    func testEndpointSecurityPathBuilderHandlesMissingComponents() {
        XCTAssertEqual(EndpointSecurityPathBuilder.join(directoryPath: " ", fileName: "Icon\r"), "Icon\r")
        XCTAssertEqual(EndpointSecurityPathBuilder.join(directoryPath: "/tmp/folder", fileName: " "), "/tmp/folder")
    }
}
#endif
