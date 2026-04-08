#if canImport(Testing)
import DriveIconGuardIPC
import DriveIconGuardShared
import DriveIconGuardScopeInventory
import DriveIconGuardXPCClient
import Foundation
import Testing

@MainActor
@Test
func betaRuntimeNormalizesBlockingScopesToAuditOnly() throws {
    let tempRoot = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let helperPath = try makeHelperExecutable(in: tempRoot)
    #expect(FileManager.default.isExecutableFile(atPath: helperPath))

    let client = EmbeddedProtectionServiceClient(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path),
        installationReceiptLocator: makeReceiptLocator(root: tempRoot)
    )

    let scope = DriveManagedScope(
        displayName: "Supported Scope",
        path: tempRoot.appendingPathComponent("scope", isDirectory: true).path,
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .internalVolume,
        fileSystemKind: .apfs,
        supportStatus: .supported,
        enforcementMode: .blockKnownArtefacts
    )

    client.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: true,
            scopes: [scope]
        )
    )

    #expect(client.status.mode != .embedded)
    #expect(client.status.activeProtectedScopeCount == 0)
    client.stop()
}

@MainActor
@Test
func embeddedPathDoesNotReportReadyEventSourceState() throws {
    let tempRoot = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    _ = try makeHelperExecutable(in: tempRoot)
    let installerPath = tempRoot
        .appendingPathComponent("Installer", isDirectory: true)
        .appendingPathComponent("ServiceRegistration", isDirectory: true)
    try FileManager.default.createDirectory(at: installerPath, withIntermediateDirectories: true)

    let client = EmbeddedProtectionServiceClient(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path),
        installationReceiptLocator: makeReceiptLocator(root: tempRoot)
    )

    client.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: true,
            scopes: []
        )
    )

    #expect(client.status.eventSourceState == .needsApproval || client.status.eventSourceState == .bundled)
    #expect(client.status.eventSourceState != .ready)
    client.stop()
}

@MainActor
@Test
func installationStateIsUnavailableWhenNoHelperIsBundled() {
    let client = EmbeddedProtectionServiceClient(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: "/tmp/does-not-exist-\(UUID().uuidString)"),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: "/tmp/does-not-exist-\(UUID().uuidString)"),
        installationReceiptLocator: makeReceiptLocator(root: URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString)", isDirectory: true))
    )

    client.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: false,
            scopes: []
        )
    )

    #expect(client.status.installationState == .unavailable)
    client.stop()
}

@MainActor
@Test
func installationStateIsBundledOnlyWhenHelperExistsWithoutInstallerResources() throws {
    let tempRoot = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    _ = try makeHelperExecutable(in: tempRoot)
    let client = EmbeddedProtectionServiceClient(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path),
        installationReceiptLocator: makeReceiptLocator(root: tempRoot)
    )

    client.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: false,
            scopes: []
        )
    )

    #expect(client.status.installationState == .bundledOnly)
    client.stop()
}

@MainActor
@Test
func installationStateIsInstallPlanReadyWhenHelperAndResourcesExist() throws {
    let tempRoot = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    _ = try makeHelperExecutable(in: tempRoot)
    let installerPath = tempRoot
        .appendingPathComponent("Installer", isDirectory: true)
        .appendingPathComponent("ServiceRegistration", isDirectory: true)
    try FileManager.default.createDirectory(at: installerPath, withIntermediateDirectories: true)

    let client = EmbeddedProtectionServiceClient(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path),
        installationReceiptLocator: makeReceiptLocator(root: tempRoot)
    )

    client.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: false,
            scopes: []
        )
    )

    #expect(client.status.installationState == .installPlanReady)
    client.stop()
}

@MainActor
@Test
func installationStateIsInstalledWhenValidReceiptExists() throws {
    let tempRoot = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let helperPath = try makeHelperExecutable(in: tempRoot)
    try writeInstallationReceipt(
        in: tempRoot,
        receipt: ProtectionInstallationReceipt(
            state: .installed,
            detail: "Helper registration verified by receipt.",
            helperExecutablePath: helperPath
        )
    )

    let client = EmbeddedProtectionServiceClient(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path),
        installationReceiptLocator: makeReceiptLocator(root: tempRoot)
    )

    client.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: false,
            scopes: []
        )
    )

    #expect(client.status.installationState == .installed)
    client.stop()
}

@MainActor
@Test
func installationStateIsErrorWhenReceiptClaimsInstalledButHelperMismatchExists() throws {
    let tempRoot = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    _ = try makeHelperExecutable(in: tempRoot)
    try writeInstallationReceipt(
        in: tempRoot,
        receipt: ProtectionInstallationReceipt(
            state: .installed,
            detail: "Helper registration verified by receipt.",
            helperExecutablePath: "/tmp/other-helper"
        )
    )

    let client = EmbeddedProtectionServiceClient(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path),
        installationReceiptLocator: makeReceiptLocator(root: tempRoot)
    )

    client.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: false,
            scopes: []
        )
    )

    #expect(client.status.installationState == .error)
    #expect(client.status.installationDescription.contains("does not match"))
    client.stop()
}

@MainActor
@Test
func installationStateIsErrorWhenReceiptIsMalformed() throws {
    let tempRoot = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    _ = try makeHelperExecutable(in: tempRoot)
    let receiptPath = tempRoot
        .appendingPathComponent("Installer", isDirectory: true)
        .appendingPathComponent("installation-receipt.json", isDirectory: false)
    try FileManager.default.createDirectory(at: receiptPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "{not-json".write(to: receiptPath, atomically: true, encoding: .utf8)

    let client = EmbeddedProtectionServiceClient(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
        installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path),
        installationReceiptLocator: makeReceiptLocator(root: tempRoot)
    )

    client.updateConfiguration(
        ProtectionServiceConfiguration(
            liveProtectionEnabled: false,
            scopes: []
        )
    )

    #expect(client.status.installationState == .error)
    #expect(client.status.installationDescription.contains("could not be decoded"))
    client.stop()
}

private func makeTempRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("embedded-protection-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeReceiptLocator(root: URL) -> ProtectionInstallationReceiptLocator {
    ProtectionInstallationReceiptLocator(
        currentDirectoryPath: root.path,
        registrationPaths: ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
        )
    )
}

private func makeHelperExecutable(in root: URL) throws -> String {
    let buildDebug = root
        .appendingPathComponent(".build", isDirectory: true)
        .appendingPathComponent("debug", isDirectory: true)
    try FileManager.default.createDirectory(at: buildDebug, withIntermediateDirectories: true)
    let helper = buildDebug.appendingPathComponent("drive-icon-guard-helper", isDirectory: false)
    try "#!/bin/sh\nexit 0\n".write(to: helper, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
    return helper.path
}

private func writeInstallationReceipt(
    in root: URL,
    receipt: ProtectionInstallationReceipt
) throws {
    let receiptPath = root
        .appendingPathComponent("Installer", isDirectory: true)
        .appendingPathComponent("installation-receipt.json", isDirectory: false)
    try FileManager.default.createDirectory(at: receiptPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(receipt)
    try data.write(to: receiptPath)
}
#elseif canImport(XCTest)
import DriveIconGuardIPC
import DriveIconGuardShared
import DriveIconGuardScopeInventory
import DriveIconGuardXPCClient
import Foundation
import XCTest

@MainActor
final class EmbeddedProtectionServiceClientTests: XCTestCase {
    func testBetaRuntimeNormalizesBlockingScopesToAuditOnly() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let helperPath = try makeHelperExecutable(in: tempRoot)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: helperPath))

        let client = EmbeddedProtectionServiceClient(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
            installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path)
        )

        let scope = DriveManagedScope(
            displayName: "Supported Scope",
            path: tempRoot.appendingPathComponent("scope", isDirectory: true).path,
            scopeKind: .myDrive,
            driveMode: .mirror,
            source: .config,
            volumeKind: .internalVolume,
            fileSystemKind: .apfs,
            supportStatus: .supported,
            enforcementMode: .blockKnownArtefacts
        )

        client.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: true,
                scopes: [scope]
            )
        )

        XCTAssertNotEqual(client.status.mode, .embedded)
        XCTAssertEqual(client.status.activeProtectedScopeCount, 0)
        client.stop()
    }

    func testEmbeddedPathDoesNotReportReadyEventSourceState() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        _ = try makeHelperExecutable(in: tempRoot)
        let installerPath = tempRoot
            .appendingPathComponent("Installer", isDirectory: true)
            .appendingPathComponent("ServiceRegistration", isDirectory: true)
        try FileManager.default.createDirectory(at: installerPath, withIntermediateDirectories: true)

        let client = EmbeddedProtectionServiceClient(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
            installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path)
        )

        client.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: true,
                scopes: []
            )
        )

        XCTAssertTrue(client.status.eventSourceState == .needsApproval || client.status.eventSourceState == .bundled)
        XCTAssertNotEqual(client.status.eventSourceState, .ready)
        client.stop()
    }

    func testInstallationStateIsUnavailableWhenNoHelperIsBundled() {
        let client = EmbeddedProtectionServiceClient(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: "/tmp/does-not-exist-\(UUID().uuidString)"),
            installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: "/tmp/does-not-exist-\(UUID().uuidString)")
        )

        client.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: false,
                scopes: []
            )
        )

        XCTAssertEqual(client.status.installationState, .unavailable)
        client.stop()
    }

    func testInstallationStateIsBundledOnlyWhenHelperExistsWithoutInstallerResources() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        _ = try makeHelperExecutable(in: tempRoot)
        let client = EmbeddedProtectionServiceClient(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
            installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path)
        )

        client.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: false,
                scopes: []
            )
        )

        XCTAssertEqual(client.status.installationState, .bundledOnly)
        client.stop()
    }

    func testInstallationStateIsInstallPlanReadyWhenHelperAndResourcesExist() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        _ = try makeHelperExecutable(in: tempRoot)
        let installerPath = tempRoot
            .appendingPathComponent("Installer", isDirectory: true)
            .appendingPathComponent("ServiceRegistration", isDirectory: true)
        try FileManager.default.createDirectory(at: installerPath, withIntermediateDirectories: true)

        let client = EmbeddedProtectionServiceClient(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
            installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path)
        )

        client.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: false,
                scopes: []
            )
        )

        XCTAssertEqual(client.status.installationState, .installPlanReady)
        client.stop()
    }

    func testInstallationStateIsInstalledWhenValidReceiptExists() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let helperPath = try makeHelperExecutable(in: tempRoot)
        try writeInstallationReceipt(
            in: tempRoot,
            receipt: ProtectionInstallationReceipt(
                state: .installed,
                detail: "Helper registration verified by receipt.",
                helperExecutablePath: helperPath
            )
        )

        let client = EmbeddedProtectionServiceClient(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
            installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path),
            installationReceiptLocator: ProtectionInstallationReceiptLocator(currentDirectoryPath: tempRoot.path)
        )

        client.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: false,
                scopes: []
            )
        )

        XCTAssertEqual(client.status.installationState, .installed)
        client.stop()
    }

    func testInstallationStateIsErrorWhenReceiptClaimsInstalledButHelperMismatchExists() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        _ = try makeHelperExecutable(in: tempRoot)
        try writeInstallationReceipt(
            in: tempRoot,
            receipt: ProtectionInstallationReceipt(
                state: .installed,
                detail: "Helper registration verified by receipt.",
                helperExecutablePath: "/tmp/other-helper"
            )
        )

        let client = EmbeddedProtectionServiceClient(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
            installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path),
            installationReceiptLocator: ProtectionInstallationReceiptLocator(currentDirectoryPath: tempRoot.path)
        )

        client.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: false,
                scopes: []
            )
        )

        XCTAssertEqual(client.status.installationState, .error)
        XCTAssertTrue(client.status.installationDescription.contains("does not match"))
        client.stop()
    }

    func testInstallationStateIsErrorWhenReceiptIsMalformed() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        _ = try makeHelperExecutable(in: tempRoot)
        let receiptPath = tempRoot
            .appendingPathComponent("Installer", isDirectory: true)
            .appendingPathComponent("installation-receipt.json", isDirectory: false)
        try FileManager.default.createDirectory(at: receiptPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{not-json".write(to: receiptPath, atomically: true, encoding: .utf8)

        let client = EmbeddedProtectionServiceClient(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: tempRoot.path),
            installerResourceLocator: ProtectionInstallerResourceLocator(currentDirectoryPath: tempRoot.path),
            installationReceiptLocator: ProtectionInstallationReceiptLocator(currentDirectoryPath: tempRoot.path)
        )

        client.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: false,
                scopes: []
            )
        )

        XCTAssertEqual(client.status.installationState, .error)
        XCTAssertTrue(client.status.installationDescription.contains("could not be decoded"))
        client.stop()
    }
}

private func makeTempRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("embedded-protection-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeHelperExecutable(in root: URL) throws -> String {
    let buildDebug = root
        .appendingPathComponent(".build", isDirectory: true)
        .appendingPathComponent("debug", isDirectory: true)
    try FileManager.default.createDirectory(at: buildDebug, withIntermediateDirectories: true)
    let helper = buildDebug.appendingPathComponent("drive-icon-guard-helper", isDirectory: false)
    try "#!/bin/sh\nexit 0\n".write(to: helper, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
    return helper.path
}

private func writeInstallationReceipt(
    in root: URL,
    receipt: ProtectionInstallationReceipt
) throws {
    let receiptPath = root
        .appendingPathComponent("Installer", isDirectory: true)
        .appendingPathComponent("installation-receipt.json", isDirectory: false)
    try FileManager.default.createDirectory(at: receiptPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(receipt)
    try data.write(to: receiptPath)
}
#endif
