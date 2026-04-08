#if canImport(Testing)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared
import DriveIconGuardXPCClient
import Foundation
import Testing

private actor XPCEventRecorder {
    private(set) var events: [ProtectionServiceEventPayload] = []

    func append(_ incoming: [ProtectionServiceEventPayload]) {
        events.append(contentsOf: incoming)
    }
}

private struct FixedContextResolver: ProtectionConnectionAuthorizationContextResolving {
    let context: ProtectionServiceAuthorizationContext

    func resolve(connection: NSXPCConnection) -> ProtectionServiceAuthorizationContext {
        context
    }
}

private final class ReadyXPCSubscriber: ProcessAttributedEventSubscriber, @unchecked Sendable {
    let status = ProtectionEventSourceStatus(
        state: .ready,
        detail: "XPC test subscriber is ready."
    )

    func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void) {}
    func stop() {}
}

@Test
@MainActor
func xpcProtectionServiceClientAcceptsTrustedInstalledFlow() async throws {
    let fixture = try makeXPCInstalledFixture()
    let endpoint = LocalProtectionServiceEndpoint(
        service: fixture.service,
        installationStatusResolver: fixture.statusResolver
    )
    let host = ProtectionXPCListenerHost(
        serviceEndpoint: endpoint,
        contextResolver: FixedContextResolver(context: trustedXPCContext())
    )
    let client = XPCProtectionServiceClient(listenerEndpoint: try #require(host.endpoint))
    let recorder = XPCEventRecorder()

    client.setEventHandler { events in
        Task {
            await recorder.append(events)
        }
    }

    client.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: true,
            scopes: [makeXPCProtectedScope()]
        )
    )
    client.start()

    let evaluation = fixture.service.process(makeXPCProtectedEvent())
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(evaluation.decision == .deny)
    #expect(client.status.installationState == .installed)
    #expect(await recorder.events.count == 1)
}

@Test
@MainActor
func xpcProtectionServiceClientRejectsUntrustedCaller() throws {
    let fixture = try makeXPCInstalledFixture()
    let endpoint = LocalProtectionServiceEndpoint(
        service: fixture.service,
        installationStatusResolver: fixture.statusResolver
    )
    let host = ProtectionXPCListenerHost(
        serviceEndpoint: endpoint,
        contextResolver: FixedContextResolver(
            context: ProtectionServiceAuthorizationContext(
                callerBundleID: "com.example.other",
                hasAuditToken: true
            )
        )
    )
    let client = XPCProtectionServiceClient(listenerEndpoint: try #require(host.endpoint))

    client.start()

    #expect(client.status.detail.contains("not trusted"))
}

@Test
@MainActor
func xpcProtectionServiceClientRejectsWhenInstallationIsNotReady() throws {
    let fixture = try makeXPCBundledFixture()
    let endpoint = LocalProtectionServiceEndpoint(
        service: fixture.service,
        installationStatusResolver: fixture.statusResolver
    )
    let host = ProtectionXPCListenerHost(
        serviceEndpoint: endpoint,
        contextResolver: FixedContextResolver(context: trustedXPCContext())
    )
    let client = XPCProtectionServiceClient(listenerEndpoint: try #require(host.endpoint))

    client.start()

    #expect(client.status.installationState == .bundledOnly)
    #expect(client.status.detail.contains("blocked until installation is verified as installed"))
}

@Test
@MainActor
func xpcProtectionServiceClientMarksMissingMachServiceAsUnreachable() {
    let client = XPCProtectionServiceClient(
        machServiceName: "com.richardgeorgedavis.google-drive-icon-guard.tests.missing.\(UUID().uuidString)",
        requestTimeout: 0.05
    )

    #expect(client.isReachable == false)
    #expect(client.lastTransportFailureDetail != nil)
    #expect(client.status.detail.contains("Installed helper"))
}

private func trustedXPCContext() -> ProtectionServiceAuthorizationContext {
    ProtectionServiceAuthorizationContext(
        callerBundleID: "com.richardgeorgedavis.google-drive-icon-guard.beta",
        hasAuditToken: true
    )
}

private func makeXPCInstalledFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver) {
    let root = try makeXPCTemporaryFixtureRoot()
    let helperPath = try makeXPCHelperExecutable(at: root)
    try writeXPCReceipt(
        at: root.appendingPathComponent("Installer/installation-receipt.json", isDirectory: false),
        receipt: ProtectionInstallationReceipt(
            state: .installed,
            detail: "Installed for XPC test flow.",
            helperExecutablePath: helperPath.path
        )
    )

    return (
        HelperProtectionService(subscriber: ReadyXPCSubscriber()),
        makeXPCResolver(root: root)
    )
}

private func makeXPCBundledFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver) {
    let root = try makeXPCTemporaryFixtureRoot()
    _ = try makeXPCHelperExecutable(at: root)
    return (
        HelperProtectionService(subscriber: ReadyXPCSubscriber()),
        makeXPCResolver(root: root)
    )
}

private func makeXPCResolver(root: URL) -> ProtectionInstallationStatusResolver {
    ProtectionInstallationStatusResolver(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: root.path),
        installationReceiptLocator: ProtectionInstallationReceiptLocator(
            currentDirectoryPath: root.path,
            registrationPaths: ProtectionServiceRegistrationPaths(
                applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
                launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
            )
        )
    )
}

private func makeXPCTemporaryFixtureRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@discardableResult
private func makeXPCHelperExecutable(at root: URL) throws -> URL {
    let helperURL = root.appendingPathComponent(".build/debug/drive-icon-guard-helper", isDirectory: false)
    try FileManager.default.createDirectory(at: helperURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "#!/bin/zsh\nexit 0\n".write(to: helperURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
    return helperURL
}

private func writeXPCReceipt(at url: URL, receipt: ProtectionInstallationReceipt) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(receipt)
    try data.write(to: url)
}

private func makeXPCProtectedScope() -> DriveManagedScope {
    DriveManagedScope(
        id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
        displayName: "Protected XPC Scope",
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

private func makeXPCProtectedEvent() -> ProcessAttributedFileEvent {
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
#elseif canImport(XCTest)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared
import DriveIconGuardXPCClient
import Foundation
import XCTest

private actor XPCEventRecorder {
    private(set) var events: [ProtectionServiceEventPayload] = []

    func append(_ incoming: [ProtectionServiceEventPayload]) {
        events.append(contentsOf: incoming)
    }
}

private struct FixedContextResolver: ProtectionConnectionAuthorizationContextResolving {
    let context: ProtectionServiceAuthorizationContext

    func resolve(connection: NSXPCConnection) -> ProtectionServiceAuthorizationContext {
        context
    }
}

private final class ReadyXPCSubscriber: ProcessAttributedEventSubscriber, @unchecked Sendable {
    let status = ProtectionEventSourceStatus(
        state: .ready,
        detail: "XPC test subscriber is ready."
    )

    func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void) {}
    func stop() {}
}

final class XPCProtectionServiceClientTests: XCTestCase {
    @MainActor
    func testXPCProtectionServiceClientAcceptsTrustedInstalledFlow() async throws {
        let fixture = try makeXPCInstalledFixture()
        let endpoint = LocalProtectionServiceEndpoint(
            service: fixture.service,
            installationStatusResolver: fixture.statusResolver
        )
        let host = ProtectionXPCListenerHost(
            serviceEndpoint: endpoint,
            contextResolver: FixedContextResolver(context: trustedXPCContext())
        )
        let client = XPCProtectionServiceClient(listenerEndpoint: try XCTUnwrap(host.endpoint))
        let recorder = XPCEventRecorder()

        client.setEventHandler { events in
            Task {
                await recorder.append(events)
            }
        }

        client.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: true,
                scopes: [makeXPCProtectedScope()]
            )
        )
        client.start()

        let evaluation = fixture.service.process(makeXPCProtectedEvent())
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(evaluation.decision, .deny)
        XCTAssertEqual(client.status.installationState, .installed)
        XCTAssertEqual(await recorder.events.count, 1)
    }

    @MainActor
    func testXPCProtectionServiceClientRejectsUntrustedCaller() throws {
        let fixture = try makeXPCInstalledFixture()
        let endpoint = LocalProtectionServiceEndpoint(
            service: fixture.service,
            installationStatusResolver: fixture.statusResolver
        )
        let host = ProtectionXPCListenerHost(
            serviceEndpoint: endpoint,
            contextResolver: FixedContextResolver(
                context: ProtectionServiceAuthorizationContext(
                    callerBundleID: "com.example.other",
                    hasAuditToken: true
                )
            )
        )
        let client = XPCProtectionServiceClient(listenerEndpoint: try XCTUnwrap(host.endpoint))

        client.start()

        XCTAssertTrue(client.status.detail.contains("not trusted"))
    }

    @MainActor
    func testXPCProtectionServiceClientRejectsWhenInstallationIsNotReady() throws {
        let fixture = try makeXPCBundledFixture()
        let endpoint = LocalProtectionServiceEndpoint(
            service: fixture.service,
            installationStatusResolver: fixture.statusResolver
        )
        let host = ProtectionXPCListenerHost(
            serviceEndpoint: endpoint,
            contextResolver: FixedContextResolver(context: trustedXPCContext())
        )
        let client = XPCProtectionServiceClient(listenerEndpoint: try XCTUnwrap(host.endpoint))

        client.start()

        XCTAssertEqual(client.status.installationState, .bundledOnly)
        XCTAssertTrue(client.status.detail.contains("blocked until installation is verified as installed"))
    }

    @MainActor
    func testXPCProtectionServiceClientMarksMissingMachServiceAsUnreachable() {
        let client = XPCProtectionServiceClient(
            machServiceName: "com.richardgeorgedavis.google-drive-icon-guard.tests.missing.\(UUID().uuidString)",
            requestTimeout: 0.05
        )

        XCTAssertFalse(client.isReachable)
        XCTAssertNotNil(client.lastTransportFailureDetail)
        XCTAssertTrue(client.status.detail.contains("Installed helper"))
    }
}

private func trustedXPCContext() -> ProtectionServiceAuthorizationContext {
    ProtectionServiceAuthorizationContext(
        callerBundleID: "com.richardgeorgedavis.google-drive-icon-guard.beta",
        hasAuditToken: true
    )
}

private func makeXPCInstalledFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver) {
    let root = try makeXPCTemporaryFixtureRoot()
    let helperPath = try makeXPCHelperExecutable(at: root)
    try writeXPCReceipt(
        at: root.appendingPathComponent("Installer/installation-receipt.json", isDirectory: false),
        receipt: ProtectionInstallationReceipt(
            state: .installed,
            detail: "Installed for XPC test flow.",
            helperExecutablePath: helperPath.path
        )
    )

    return (
        HelperProtectionService(subscriber: ReadyXPCSubscriber()),
        makeXPCResolver(root: root)
    )
}

private func makeXPCBundledFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver) {
    let root = try makeXPCTemporaryFixtureRoot()
    _ = try makeXPCHelperExecutable(at: root)
    return (
        HelperProtectionService(subscriber: ReadyXPCSubscriber()),
        makeXPCResolver(root: root)
    )
}

private func makeXPCResolver(root: URL) -> ProtectionInstallationStatusResolver {
    ProtectionInstallationStatusResolver(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: root.path),
        installationReceiptLocator: ProtectionInstallationReceiptLocator(
            currentDirectoryPath: root.path,
            registrationPaths: ProtectionServiceRegistrationPaths(
                applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
                launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
            )
        )
    )
}

private func makeXPCTemporaryFixtureRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@discardableResult
private func makeXPCHelperExecutable(at root: URL) throws -> URL {
    let helperURL = root.appendingPathComponent(".build/debug/drive-icon-guard-helper", isDirectory: false)
    try FileManager.default.createDirectory(at: helperURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "#!/bin/zsh\nexit 0\n".write(to: helperURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
    return helperURL
}

private func writeXPCReceipt(at url: URL, receipt: ProtectionInstallationReceipt) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(receipt)
    try data.write(to: url)
}

private func makeXPCProtectedScope() -> DriveManagedScope {
    DriveManagedScope(
        id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
        displayName: "Protected XPC Scope",
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

private func makeXPCProtectedEvent() -> ProcessAttributedFileEvent {
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
#endif
