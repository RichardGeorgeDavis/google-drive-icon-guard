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
        installationStatusResolver: fixture.statusResolver,
        configurationStore: fixture.configurationStore
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
    waitFor(timeout: 2) { eventBox.events.count == 1 }
    #expect(eventBox.events.count == 1)
    #expect(eventBox.events.first?.status == .applied)
}

@Test
func localProtectionServiceEndpointRejectsUntrustedCaller() throws {
    let fixture = try makeInstalledBoundaryFixture()
    let endpoint = LocalProtectionServiceEndpoint(
        service: fixture.service,
        installationStatusResolver: fixture.statusResolver,
        configurationStore: fixture.configurationStore
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
        installationStatusResolver: fixture.statusResolver,
        configurationStore: fixture.configurationStore
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
        installationStatusResolver: fixture.statusResolver,
        configurationStore: fixture.configurationStore
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
        installationStatusResolver: fixture.statusResolver,
        configurationStore: fixture.configurationStore
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
    waitFor(timeout: 2) { eventBox.events.count == 1 }
    #expect(client.status.installationState == .installed)
    #expect(eventBox.events.count == 1)
}

@Test
func localProtectionServiceEndpointRestoresPersistedConfigurationForInstalledHelper() throws {
    let fixture = try makeInstalledBoundaryFixture()
    try fixture.configurationStore.persist(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: true,
            scopes: [makeProtectedScope()]
        )
    )

    let endpoint = LocalProtectionServiceEndpoint(
        service: fixture.service,
        installationStatusResolver: fixture.statusResolver,
        configurationStore: fixture.configurationStore
    )

    let status = endpoint.queryStatus(context: trustedContext()).status
    let evaluation = fixture.service.process(makeProtectedEvent())

    #expect(status.installationState == .installed)
    #expect(status.activeProtectedScopeCount == 1)
    #expect(evaluation.decision == .deny)
}

@Test
func localProtectionServiceEndpointSurfacesRuntimeStartFailure() throws {
    let fixture = try makeInstalledBoundaryFixture()
    let runtimeController = FakeRuntimeController()
    runtimeController.onStart = { _ in
        runtimeController.status = ProtectionEventSourceStatus(
            state: .error,
            detail: "Fake runtime start failed."
        )
        throw FakeRuntimeControllerError.startFailed
    }

    let endpoint = LocalProtectionServiceEndpoint(
        service: runtimeController,
        installationStatusResolver: fixture.statusResolver,
        configurationStore: fixture.configurationStore
    )

    let result = endpoint.start(context: trustedContext())

    #expect(result.accepted == false)
    #expect(result.failureReason == .runtimeStartFailed)
    #expect(result.status.eventSourceState == .error)
    #expect(result.detail.contains("fake runtime start failed"))
}

@Test
@MainActor
func localProtectionServiceEndpointHandlesSynchronousRuntimeEventDuringStart() throws {
    let fixture = try makeInstalledBoundaryFixture()
    let runtimeController = FakeRuntimeController()
    let eventBox = EndpointEventBox()
    runtimeController.onStart = { handler in
        runtimeController.status = ProtectionEventSourceStatus(
            state: .ready,
            detail: "Fake runtime is ready."
        )
        handler(makeProtectedEvaluation())
    }

    let endpoint = LocalProtectionServiceEndpoint(
        service: runtimeController,
        installationStatusResolver: fixture.statusResolver,
        configurationStore: fixture.configurationStore
    )

    let subscribeResult = endpoint.subscribeEvents(
        context: trustedContext(),
        handler: { eventBox.events.append(contentsOf: $0) }
    )
    #expect(subscribeResult.accepted)

    let configurationResult = endpoint.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: true,
            scopes: [makeProtectedScope()]
        ),
        context: trustedContext()
    )
    #expect(configurationResult.accepted)

    waitFor(timeout: 2) { eventBox.events.count == 1 }
    #expect(configurationResult.status.eventSourceState == .ready)
    #expect(runtimeController.startCallCount == 1)
    #expect(runtimeController.updatedScopes.last?.map(\.id) == [makeProtectedScope().id])
    #expect(eventBox.events.first?.scopeID == makeProtectedScope().id)
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

private func makeProtectedEvaluation() -> HelperProtectionEvaluation {
    HelperProtectionEvaluation(
        event: makeProtectedEvent(),
        matchedScopeID: makeProtectedScope().id,
        matchedArtefactType: .iconFile,
        decision: .deny,
        reason: "Synthetic runtime callback for LocalProtectionServiceEndpoint test."
    )
}

private func makeInstalledBoundaryFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver, configurationStore: ProtectionServiceConfigurationStore) {
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
        makeResolver(root: root),
        makeConfigurationStore(root: root)
    )
}

private func makeBundledBoundaryFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver, configurationStore: ProtectionServiceConfigurationStore) {
    let root = try makeTemporaryFixtureRoot()
    _ = try makeHelperExecutable(at: root)
    return (
        HelperProtectionService(subscriber: ReadySubscriber()),
        makeResolver(root: root),
        makeConfigurationStore(root: root)
    )
}

private func makeResolver(root: URL) -> ProtectionInstallationStatusResolver {
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

private func makeConfigurationStore(root: URL) -> ProtectionServiceConfigurationStore {
    ProtectionServiceConfigurationStore(
        registrationPaths: ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
        )
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

private func waitFor(timeout: TimeInterval, condition: @escaping () -> Bool) {
    let timeoutDate = Date().addingTimeInterval(timeout)
    while Date() < timeoutDate {
        if condition() {
            return
        }
        Thread.sleep(forTimeInterval: 0.02)
    }
}

private enum FakeRuntimeControllerError: Error, LocalizedError {
    case startFailed

    var errorDescription: String? {
        switch self {
        case .startFailed:
            return "fake runtime start failed"
        }
    }
}

private final class FakeRuntimeController: ProtectionServiceRuntimeControlling, @unchecked Sendable {
    var status = ProtectionEventSourceStatus(
        state: .bundled,
        detail: "Fake runtime controller is bundled."
    )
    var startCallCount = 0
    var updatedScopes: [[DriveManagedScope]] = []
    var onStart: ((@escaping @Sendable (HelperProtectionEvaluation) -> Void) throws -> Void)?

    func updateScopes(_ scopes: [DriveManagedScope]) {
        updatedScopes.append(scopes)
    }

    func start(evaluationHandler: @escaping @Sendable (HelperProtectionEvaluation) -> Void) throws {
        startCallCount += 1
        try onStart?(evaluationHandler)
    }

    func stop() {}

    func runtimeStatus() -> ProtectionEventSourceStatus {
        status
    }
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
            installationStatusResolver: fixture.statusResolver,
            configurationStore: fixture.configurationStore
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
        waitFor(timeout: 2) { eventBox.events.count == 1 }
        XCTAssertEqual(eventBox.events.count, 1)
        XCTAssertEqual(eventBox.events.first?.status, .applied)
    }

    func testLocalProtectionServiceEndpointRejectsUntrustedCaller() throws {
        let fixture = try makeInstalledBoundaryFixture()
        let endpoint = LocalProtectionServiceEndpoint(
            service: fixture.service,
            installationStatusResolver: fixture.statusResolver,
            configurationStore: fixture.configurationStore
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
            installationStatusResolver: fixture.statusResolver,
            configurationStore: fixture.configurationStore
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
            installationStatusResolver: fixture.statusResolver,
            configurationStore: fixture.configurationStore
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
            installationStatusResolver: fixture.statusResolver,
            configurationStore: fixture.configurationStore
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
        waitFor(timeout: 2) { eventBox.events.count == 1 }
        XCTAssertEqual(client.status.installationState, .installed)
        XCTAssertEqual(eventBox.events.count, 1)
    }

    func testLocalProtectionServiceEndpointRestoresPersistedConfigurationForInstalledHelper() throws {
        let fixture = try makeInstalledBoundaryFixture()
        try fixture.configurationStore.persist(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: true,
                scopes: [makeProtectedScope()]
            )
        )

        let endpoint = LocalProtectionServiceEndpoint(
            service: fixture.service,
            installationStatusResolver: fixture.statusResolver,
            configurationStore: fixture.configurationStore
        )

        let status = endpoint.queryStatus(context: trustedContext()).status
        let evaluation = fixture.service.process(makeProtectedEvent())

        XCTAssertEqual(status.installationState, .installed)
        XCTAssertEqual(status.activeProtectedScopeCount, 1)
        XCTAssertEqual(evaluation.decision, .deny)
    }

    func testLocalProtectionServiceEndpointSurfacesRuntimeStartFailure() throws {
        let fixture = try makeInstalledBoundaryFixture()
        let runtimeController = FakeRuntimeController()
        runtimeController.onStart = { _ in
            runtimeController.status = ProtectionEventSourceStatus(
                state: .error,
                detail: "Fake runtime start failed."
            )
            throw FakeRuntimeControllerError.startFailed
        }

        let endpoint = LocalProtectionServiceEndpoint(
            service: runtimeController,
            installationStatusResolver: fixture.statusResolver,
            configurationStore: fixture.configurationStore
        )

        let result = endpoint.start(context: trustedContext())

        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.failureReason, .runtimeStartFailed)
        XCTAssertEqual(result.status.eventSourceState, .error)
        XCTAssertTrue(result.detail.contains("fake runtime start failed"))
    }

    @MainActor
    func testLocalProtectionServiceEndpointHandlesSynchronousRuntimeEventDuringStart() throws {
        let fixture = try makeInstalledBoundaryFixture()
        let runtimeController = FakeRuntimeController()
        let eventBox = EndpointEventBox()
        runtimeController.onStart = { handler in
            runtimeController.status = ProtectionEventSourceStatus(
                state: .ready,
                detail: "Fake runtime is ready."
            )
            handler(makeProtectedEvaluation())
        }

        let endpoint = LocalProtectionServiceEndpoint(
            service: runtimeController,
            installationStatusResolver: fixture.statusResolver,
            configurationStore: fixture.configurationStore
        )

        let subscribeResult = endpoint.subscribeEvents(
            context: trustedContext(),
            handler: { eventBox.events.append(contentsOf: $0) }
        )
        XCTAssertTrue(subscribeResult.accepted)

        let configurationResult = endpoint.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: true,
                scopes: [makeProtectedScope()]
            ),
            context: trustedContext()
        )
        XCTAssertTrue(configurationResult.accepted)

        waitFor(timeout: 2) { eventBox.events.count == 1 }
        XCTAssertEqual(configurationResult.status.eventSourceState, .ready)
        XCTAssertEqual(runtimeController.startCallCount, 1)
        XCTAssertEqual(runtimeController.updatedScopes.last?.map(\.id), [makeProtectedScope().id])
        XCTAssertEqual(eventBox.events.first?.scopeID, makeProtectedScope().id)
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

private func makeProtectedEvaluation() -> HelperProtectionEvaluation {
    HelperProtectionEvaluation(
        event: makeProtectedEvent(),
        matchedScopeID: makeProtectedScope().id,
        matchedArtefactType: .iconFile,
        decision: .deny,
        reason: "Synthetic runtime callback for LocalProtectionServiceEndpoint test."
    )
}

private func makeInstalledBoundaryFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver, configurationStore: ProtectionServiceConfigurationStore) {
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
        makeResolver(root: root),
        makeConfigurationStore(root: root)
    )
}

private func makeBundledBoundaryFixture() throws -> (service: HelperProtectionService, statusResolver: ProtectionInstallationStatusResolver, configurationStore: ProtectionServiceConfigurationStore) {
    let root = try makeTemporaryFixtureRoot()
    _ = try makeHelperExecutable(at: root)
    return (
        HelperProtectionService(subscriber: ReadySubscriber()),
        makeResolver(root: root),
        makeConfigurationStore(root: root)
    )
}

private func makeResolver(root: URL) -> ProtectionInstallationStatusResolver {
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

private func makeConfigurationStore(root: URL) -> ProtectionServiceConfigurationStore {
    ProtectionServiceConfigurationStore(
        registrationPaths: ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
        )
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

private func waitFor(timeout: TimeInterval, condition: @escaping () -> Bool) {
    let timeoutDate = Date().addingTimeInterval(timeout)
    while Date() < timeoutDate {
        if condition() {
            return
        }
        Thread.sleep(forTimeInterval: 0.02)
    }
}

private enum FakeRuntimeControllerError: Error, LocalizedError {
    case startFailed

    var errorDescription: String? {
        switch self {
        case .startFailed:
            return "fake runtime start failed"
        }
    }
}

private final class FakeRuntimeController: ProtectionServiceRuntimeControlling, @unchecked Sendable {
    var status = ProtectionEventSourceStatus(
        state: .bundled,
        detail: "Fake runtime controller is bundled."
    )
    var startCallCount = 0
    var updatedScopes: [[DriveManagedScope]] = []
    var onStart: ((@escaping @Sendable (HelperProtectionEvaluation) -> Void) throws -> Void)?

    func updateScopes(_ scopes: [DriveManagedScope]) {
        updatedScopes.append(scopes)
    }

    func start(evaluationHandler: @escaping @Sendable (HelperProtectionEvaluation) -> Void) throws {
        startCallCount += 1
        try onStart?(evaluationHandler)
    }

    func stop() {}

    func runtimeStatus() -> ProtectionEventSourceStatus {
        status
    }
}
#endif
