#if canImport(Testing)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared
import DriveIconGuardXPCClient
import Foundation
import Testing

private final class EndpointEventBox: @unchecked Sendable {
    var events: [ProtectionServiceEventPayload] = []
}

private final class ReadySubscriber: ProcessAttributedEventSubscriber, @unchecked Sendable {
    let status = ProtectionEventSourceStatus(
        state: .ready,
        detail: "Test subscriber is ready."
    )

    func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void) {}
    func stop() {}
}

@Test
@MainActor
func localProtectionServiceEndpointAcceptsTrustedInstalledFlow() throws {
    let fixture = try makeInstalledBoundaryFixture()
    let eventBox = EndpointEventBox()
    let endpoint = LocalProtectionServiceEndpoint(
        service: fixture.service,
        installationStatusResolver: fixture.statusResolver
    )

    let configurationResult = endpoint.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: true,
            scopes: [makeProtectedScope()]
        ),
        context: trustedContext()
    )
    #expect(configurationResult.accepted)

    let subscribeResult = endpoint.subscribeEvents(
        context: trustedContext(),
        handler: { eventBox.events.append(contentsOf: $0) }
    )
    #expect(subscribeResult.accepted)

    let startResult = endpoint.start(context: trustedContext())
    #expect(startResult.accepted)
    #expect(startResult.status.activeProtectedScopeCount == 1)
    #expect(startResult.status.installationState == .installed)

    let evaluation = fixture.service.process(makeProtectedEvent())

    #expect(evaluation.decision == .deny)
    #expect(eventBox.events.count == 1)
    #expect(eventBox.events.first?.status == .applied)
}

@Test
func localProtectionServiceEndpointRejectsUntrustedCaller() throws {
    let fixture = try makeInstalledBoundaryFixture()
    let endpoint = LocalProtectionServiceEndpoint(
        service: fixture.service,
        installationStatusResolver: fixture.statusResolver
    )

    let result = endpoint.start(
        context: ProtectionServiceAuthorizationContext(
            callerBundleID: "com.example.other",
            hasAuditToken: true
        )
    )

    #expect(result.accepted == false)
    #expect(result.failureReason == .callerIdentityUntrusted)
}

@Test
func localProtectionServiceEndpointRejectsWhenInstallationIsNotReady() throws {
    let fixture = try makeBundledBoundaryFixture()
    let endpoint = LocalProtectionServiceEndpoint(
        service: fixture.service,
        installationStatusResolver: fixture.statusResolver
    )

    let result = endpoint.start(context: trustedContext())

    #expect(result.accepted == false)
    #expect(result.failureReason == .installationNotReady)
    #expect(result.status.installationState == .bundledOnly)
}

@Test
func localProtectionServiceEndpointRejectsInvalidConfiguration() throws {
    let fixture = try makeInstalledBoundaryFixture()
    let endpoint = LocalProtectionServiceEndpoint(
        service: fixture.service,
        installationStatusResolver: fixture.statusResolver
    )

    let result = endpoint.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: true,
            scopes: [
                DriveManagedScope(
                    displayName: "Bad Scope",
                    path: "relative/path",
                    scopeKind: .myDrive,
                    driveMode: .mirror,
                    source: .config,
                    volumeKind: .internalVolume,
                    fileSystemKind: .apfs,
                    supportStatus: .supported,
                    enforcementMode: .blockKnownArtefacts
                )
            ]
        ),
        context: trustedContext()
    )

    #expect(result.accepted == false)
    #expect(result.failureReason == .invalidConfiguration)
}

@Test
@MainActor
func boundaryProtectionServiceClientUsesProtectedEndpoint() throws {
    let fixture = try makeInstalledBoundaryFixture()
    let endpoint = LocalProtectionServiceEndpoint(
        service: fixture.service,
        installationStatusResolver: fixture.statusResolver
    )
    let client = BoundaryProtectionServiceClient(
        endpoint: endpoint,
        context: trustedContext()
    )
    let eventBox = EndpointEventBox()

    client.setEventHandler { eventBox.events.append(contentsOf: $0) }
    client.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: true,
            scopes: [makeProtectedScope()]
        )
    )
    client.start()

    let evaluation = fixture.service.process(makeProtectedEvent())

    #expect(evaluation.decision == .deny)
    #expect(client.status.installationState == .installed)
    #expect(eventBox.events.count == 1)
}

private func trustedContext() -> ProtectionServiceAuthorizationContext {
    ProtectionServiceAuthorizationContext(
        callerBundleID: "com.richardgeorgedavis.google-drive-icon-guard.beta",
        hasAuditToken: true
    )
}

private func makeProtectedScope() -> DriveManagedScope {
    DriveManagedScope(
        id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
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
}

private func makeProtectedEvent() -> ProcessAttributedFileEvent {
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
}

private func makeInstalledBoundaryFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver) {
    let root = try makeTemporaryFixtureRoot()
    let helperPath = try makeHelperExecutable(at: root)
    try writeReceipt(
        at: root.appendingPathComponent("Installer/installation-receipt.json", isDirectory: false),
        receipt: ProtectionInstallationReceipt(
            state: .installed,
            detail: "Installed for test boundary flow.",
            helperExecutablePath: helperPath.path
        )
    )

    return (
        HelperProtectionService(subscriber: ReadySubscriber()),
        makeResolver(root: root)
    )
}

private func makeBundledBoundaryFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver) {
    let root = try makeTemporaryFixtureRoot()
    _ = try makeHelperExecutable(at: root)
    return (
        HelperProtectionService(subscriber: ReadySubscriber()),
        makeResolver(root: root)
    )
}

private func makeResolver(root: URL) -> ProtectionInstallationStatusResolver {
    ProtectionInstallationStatusResolver(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: root.path),
        installationReceiptLocator: ProtectionInstallationReceiptLocator(currentDirectoryPath: root.path)
    )
}

private func makeTemporaryFixtureRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@discardableResult
private func makeHelperExecutable(at root: URL) throws -> URL {
    let helperURL = root.appendingPathComponent(".build/debug/drive-icon-guard-helper", isDirectory: false)
    try FileManager.default.createDirectory(at: helperURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "#!/bin/zsh\nexit 0\n".write(to: helperURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
    return helperURL
}

private func writeReceipt(at url: URL, receipt: ProtectionInstallationReceipt) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(receipt)
    try data.write(to: url)
}
#elseif canImport(XCTest)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared
import DriveIconGuardXPCClient
import Foundation
import XCTest

private final class EndpointEventBox: @unchecked Sendable {
    var events: [ProtectionServiceEventPayload] = []
}

private final class ReadySubscriber: ProcessAttributedEventSubscriber, @unchecked Sendable {
    let status = ProtectionEventSourceStatus(
        state: .ready,
        detail: "Test subscriber is ready."
    )

    func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void) {}
    func stop() {}
}

final class LocalProtectionServiceEndpointTests: XCTestCase {
    @MainActor
    func testLocalProtectionServiceEndpointAcceptsTrustedInstalledFlow() throws {
        let fixture = try makeInstalledBoundaryFixture()
        let eventBox = EndpointEventBox()
        let endpoint = LocalProtectionServiceEndpoint(
            service: fixture.service,
            installationStatusResolver: fixture.statusResolver
        )

        let configurationResult = endpoint.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: true,
                scopes: [makeProtectedScope()]
            ),
            context: trustedContext()
        )
        XCTAssertTrue(configurationResult.accepted)

        let subscribeResult = endpoint.subscribeEvents(
            context: trustedContext(),
            handler: { eventBox.events.append(contentsOf: $0) }
        )
        XCTAssertTrue(subscribeResult.accepted)

        let startResult = endpoint.start(context: trustedContext())
        XCTAssertTrue(startResult.accepted)
        XCTAssertEqual(startResult.status.activeProtectedScopeCount, 1)
        XCTAssertEqual(startResult.status.installationState, .installed)

        let evaluation = fixture.service.process(makeProtectedEvent())

        XCTAssertEqual(evaluation.decision, .deny)
        XCTAssertEqual(eventBox.events.count, 1)
        XCTAssertEqual(eventBox.events.first?.status, .applied)
    }

    func testLocalProtectionServiceEndpointRejectsUntrustedCaller() throws {
        let fixture = try makeInstalledBoundaryFixture()
        let endpoint = LocalProtectionServiceEndpoint(
            service: fixture.service,
            installationStatusResolver: fixture.statusResolver
        )

        let result = endpoint.start(
            context: ProtectionServiceAuthorizationContext(
                callerBundleID: "com.example.other",
                hasAuditToken: true
            )
        )

        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.failureReason, .callerIdentityUntrusted)
    }

    func testLocalProtectionServiceEndpointRejectsWhenInstallationIsNotReady() throws {
        let fixture = try makeBundledBoundaryFixture()
        let endpoint = LocalProtectionServiceEndpoint(
            service: fixture.service,
            installationStatusResolver: fixture.statusResolver
        )

        let result = endpoint.start(context: trustedContext())

        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.failureReason, .installationNotReady)
        XCTAssertEqual(result.status.installationState, .bundledOnly)
    }

    func testLocalProtectionServiceEndpointRejectsInvalidConfiguration() throws {
        let fixture = try makeInstalledBoundaryFixture()
        let endpoint = LocalProtectionServiceEndpoint(
            service: fixture.service,
            installationStatusResolver: fixture.statusResolver
        )

        let result = endpoint.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: true,
                scopes: [
                    DriveManagedScope(
                        displayName: "Bad Scope",
                        path: "relative/path",
                        scopeKind: .myDrive,
                        driveMode: .mirror,
                        source: .config,
                        volumeKind: .internalVolume,
                        fileSystemKind: .apfs,
                        supportStatus: .supported,
                        enforcementMode: .blockKnownArtefacts
                    )
                ]
            ),
            context: trustedContext()
        )

        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.failureReason, .invalidConfiguration)
    }

    @MainActor
    func testBoundaryProtectionServiceClientUsesProtectedEndpoint() throws {
        let fixture = try makeInstalledBoundaryFixture()
        let endpoint = LocalProtectionServiceEndpoint(
            service: fixture.service,
            installationStatusResolver: fixture.statusResolver
        )
        let client = BoundaryProtectionServiceClient(
            endpoint: endpoint,
            context: trustedContext()
        )
        let eventBox = EndpointEventBox()

        client.setEventHandler { eventBox.events.append(contentsOf: $0) }
        client.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: true,
                scopes: [makeProtectedScope()]
            )
        )
        client.start()

        let evaluation = fixture.service.process(makeProtectedEvent())

        XCTAssertEqual(evaluation.decision, .deny)
        XCTAssertEqual(client.status.installationState, .installed)
        XCTAssertEqual(eventBox.events.count, 1)
    }
}

private func trustedContext() -> ProtectionServiceAuthorizationContext {
    ProtectionServiceAuthorizationContext(
        callerBundleID: "com.richardgeorgedavis.google-drive-icon-guard.beta",
        hasAuditToken: true
    )
}

private func makeProtectedScope() -> DriveManagedScope {
    DriveManagedScope(
        id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
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
}

private func makeProtectedEvent() -> ProcessAttributedFileEvent {
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
}

private func makeInstalledBoundaryFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver) {
    let root = try makeTemporaryFixtureRoot()
    let helperPath = try makeHelperExecutable(at: root)
    try writeReceipt(
        at: root.appendingPathComponent("Installer/installation-receipt.json", isDirectory: false),
        receipt: ProtectionInstallationReceipt(
            state: .installed,
            detail: "Installed for test boundary flow.",
            helperExecutablePath: helperPath.path
        )
    )

    return (
        HelperProtectionService(subscriber: ReadySubscriber()),
        makeResolver(root: root)
    )
}

private func makeBundledBoundaryFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver) {
    let root = try makeTemporaryFixtureRoot()
    _ = try makeHelperExecutable(at: root)
    return (
        HelperProtectionService(subscriber: ReadySubscriber()),
        makeResolver(root: root)
    )
}

private func makeResolver(root: URL) -> ProtectionInstallationStatusResolver {
    ProtectionInstallationStatusResolver(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: root.path),
        installationReceiptLocator: ProtectionInstallationReceiptLocator(currentDirectoryPath: root.path)
    )
}

private func makeTemporaryFixtureRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@discardableResult
private func makeHelperExecutable(at root: URL) throws -> URL {
    let helperURL = root.appendingPathComponent(".build/debug/drive-icon-guard-helper", isDirectory: false)
    try FileManager.default.createDirectory(at: helperURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "#!/bin/zsh\nexit 0\n".write(to: helperURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
    return helperURL
}

private func writeReceipt(at url: URL, receipt: ProtectionInstallationReceipt) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(receipt)
    try data.write(to: url)
}
#endif
