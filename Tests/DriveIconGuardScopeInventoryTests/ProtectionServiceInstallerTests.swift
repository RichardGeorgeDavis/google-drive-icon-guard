#if canImport(Testing)
import DriveIconGuardXPCClient
import Foundation
import Testing

@Test
func protectionServiceInstallerWritesLaunchAgentAndReceipt() throws {
    let root = try makeInstallerFixtureRoot()
    _ = try makeInstallerHelperExecutable(at: root)
    let paths = ProtectionServiceRegistrationPaths(
        applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
        launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
    )
    let installer = ProtectionServiceInstaller(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
        registrationPaths: paths
    )

    let receipt = try installer.install()
    let plistURL = paths.launchAgentPlistURL(for: .beta)

    #expect(receipt.state == .installed)
    #expect(receipt.machServiceName == ProtectionServiceRegistrationConfiguration.beta.machServiceName)
    #expect(FileManager.default.fileExists(atPath: plistURL.path))
    #expect(FileManager.default.fileExists(atPath: paths.receiptURL.path))

    let plistData = try Data(contentsOf: plistURL)
    let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
    let machServices = plist?["MachServices"] as? [String: Bool]
    #expect(machServices?[ProtectionServiceRegistrationConfiguration.beta.machServiceName] == true)
}

@Test
func protectionServiceInstallerUninstallRemovesLaunchAgentAndReceipt() throws {
    let root = try makeInstallerFixtureRoot()
    _ = try makeInstallerHelperExecutable(at: root)
    let paths = ProtectionServiceRegistrationPaths(
        applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
        launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
    )
    let installer = ProtectionServiceInstaller(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
        registrationPaths: paths
    )

    _ = try installer.install()
    try installer.uninstall()

    #expect(FileManager.default.fileExists(atPath: paths.receiptURL.path) == false)
    #expect(FileManager.default.fileExists(atPath: paths.launchAgentPlistURL(for: .beta).path) == false)
}

@Test
func protectionServiceReceiptLocatorFindsApplicationSupportReceipt() throws {
    let root = try makeInstallerFixtureRoot()
    let paths = ProtectionServiceRegistrationPaths(
        applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
        launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
    )
    let receipt = ProtectionInstallationReceipt(
        state: .installed,
        detail: "Installed from application support receipt.",
        helperExecutablePath: "/tmp/drive-icon-guard-helper",
        machServiceName: ProtectionServiceRegistrationConfiguration.beta.machServiceName
    )
    try FileManager.default.createDirectory(at: paths.applicationSupportDirectory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    let data = try encoder.encode(receipt)
    try data.write(to: paths.receiptURL)

    let locator = ProtectionInstallationReceiptLocator(
        currentDirectoryPath: root.path,
        registrationPaths: paths
    )

    switch locator.loadReceipt() {
    case .loaded(let loaded):
        #expect(loaded == receipt)
    default:
        Issue.record("Expected receipt locator to load application support receipt.")
    }
}

private func makeInstallerFixtureRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@discardableResult
private func makeInstallerHelperExecutable(at root: URL) throws -> URL {
    let helperURL = root.appendingPathComponent(".build/debug/drive-icon-guard-helper", isDirectory: false)
    try FileManager.default.createDirectory(at: helperURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "#!/bin/zsh\nexit 0\n".write(to: helperURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
    return helperURL
}
#elseif canImport(XCTest)
import DriveIconGuardXPCClient
import Foundation
import XCTest

final class ProtectionServiceInstallerTests: XCTestCase {
    func testProtectionServiceInstallerWritesLaunchAgentAndReceipt() throws {
        let root = try makeInstallerFixtureRoot()
        let helperURL = try makeInstallerHelperExecutable(at: root)
        let paths = ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
        )
        let installer = ProtectionServiceInstaller(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
            registrationPaths: paths
        )

        let receipt = try installer.install()
        let plistURL = paths.launchAgentPlistURL(for: .beta)

        XCTAssertEqual(receipt.state, .installed)
        XCTAssertEqual(receipt.machServiceName, ProtectionServiceRegistrationConfiguration.beta.machServiceName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: plistURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.receiptURL.path))

        let plistData = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        let machServices = plist?["MachServices"] as? [String: Bool]
        XCTAssertEqual(machServices?[ProtectionServiceRegistrationConfiguration.beta.machServiceName], true)
        XCTAssertEqual(helperURL.path, receipt.helperExecutablePath)
    }

    func testProtectionServiceInstallerUninstallRemovesLaunchAgentAndReceipt() throws {
        let root = try makeInstallerFixtureRoot()
        _ = try makeInstallerHelperExecutable(at: root)
        let paths = ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
        )
        let installer = ProtectionServiceInstaller(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
            registrationPaths: paths
        )

        _ = try installer.install()
        try installer.uninstall()

        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.receiptURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.launchAgentPlistURL(for: .beta).path))
    }

    func testProtectionServiceReceiptLocatorFindsApplicationSupportReceipt() throws {
        let root = try makeInstallerFixtureRoot()
        let paths = ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
        )
        let receipt = ProtectionInstallationReceipt(
            state: .installed,
            detail: "Installed from application support receipt.",
            helperExecutablePath: "/tmp/drive-icon-guard-helper",
            machServiceName: ProtectionServiceRegistrationConfiguration.beta.machServiceName
        )
        try FileManager.default.createDirectory(at: paths.applicationSupportDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        let data = try encoder.encode(receipt)
        try data.write(to: paths.receiptURL)

        let locator = ProtectionInstallationReceiptLocator(
            currentDirectoryPath: root.path,
            registrationPaths: paths
        )

        switch locator.loadReceipt() {
        case .loaded(let loaded):
            XCTAssertEqual(loaded, receipt)
        default:
            XCTFail("Expected receipt locator to load application support receipt.")
        }
    }
}

private func makeInstallerFixtureRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@discardableResult
private func makeInstallerHelperExecutable(at root: URL) throws -> URL {
    let helperURL = root.appendingPathComponent(".build/debug/drive-icon-guard-helper", isDirectory: false)
    try FileManager.default.createDirectory(at: helperURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "#!/bin/zsh\nexit 0\n".write(to: helperURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
    return helperURL
}
#endif
