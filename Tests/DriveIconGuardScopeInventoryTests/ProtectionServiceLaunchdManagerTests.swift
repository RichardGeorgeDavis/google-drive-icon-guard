#if canImport(Testing)
import DriveIconGuardXPCClient
import Foundation
import Testing

private final class StubLaunchctlRunner: ProtectionServiceLaunchctlRunning, @unchecked Sendable {
    var resultsByArguments: [String: ProtectionServiceLaunchdCommandResult] = [:]
    var invocations: [[String]] = []

    func run(arguments: [String]) throws -> ProtectionServiceLaunchdCommandResult {
        invocations.append(arguments)
        let key = arguments.joined(separator: "\u{1F}")
        return resultsByArguments[key]
            ?? ProtectionServiceLaunchdCommandResult(
                arguments: arguments,
                exitCode: 0,
                standardOutput: "",
                standardError: ""
            )
    }
}

@Test
func protectionServiceLaunchdManagerRunsBootstrapKickstartAndStatus() throws {
    let runner = StubLaunchctlRunner()
    let paths = ProtectionServiceRegistrationPaths(
        applicationSupportDirectory: URL(fileURLWithPath: "/tmp/app-support", isDirectory: true),
        launchAgentsDirectory: URL(fileURLWithPath: "/tmp/launch-agents", isDirectory: true)
    )
    let manager = ProtectionServiceLaunchdManager(
        runner: runner,
        registrationPaths: paths,
        userID: 501
    )

    let printArgs = ["print", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]
    runner.resultsByArguments[printArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
        arguments: printArgs,
        exitCode: 0,
        standardOutput: "service = loaded",
        standardError: ""
    )

    _ = try manager.bootstrap()
    _ = try manager.kickstart()
    let status = try manager.status()

    #expect(status.isLoaded)
    #expect(runner.invocations[0] == ["bootstrap", "gui/501", "/tmp/launch-agents/com.richardgeorgedavis.google-drive-icon-guard.beta.helper.plist"])
    #expect(runner.invocations[1] == ["kickstart", "-k", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"])
    #expect(runner.invocations[2] == printArgs)
}

@Test
func protectionServiceDeploymentCoordinatorWritesErrorReceiptWhenBootstrapFails() throws {
    let root = try makeLaunchdFixtureRoot()
    _ = try makeLaunchdHelperExecutable(at: root)
    let paths = ProtectionServiceRegistrationPaths(
        applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
        launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
    )
    let installer = ProtectionServiceInstaller(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
        registrationPaths: paths
    )
    let runner = StubLaunchctlRunner()
    let bootstrapArgs = ["bootstrap", "gui/501", paths.launchAgentPlistURL(for: .beta).path]
    runner.resultsByArguments[bootstrapArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
        arguments: bootstrapArgs,
        exitCode: 5,
        standardOutput: "",
        standardError: "bootstrap failed"
    )
    let printArgs = ["print", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]
    runner.resultsByArguments[printArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
        arguments: printArgs,
        exitCode: 113,
        standardOutput: "",
        standardError: "could not find service"
    )
    let manager = ProtectionServiceLaunchdManager(
        runner: runner,
        registrationPaths: paths,
        userID: 501
    )
    let coordinator = ProtectionServiceDeploymentCoordinator(
        installer: installer,
        launchdManager: manager
    )

    let result = try coordinator.installAndBootstrap()
    let receiptData = try Data(contentsOf: paths.receiptURL)
    let receipt = try JSONDecoder().decode(ProtectionInstallationReceipt.self, from: receiptData)

    #expect(result.receipt.state == .error)
    #expect(receipt.state == .error)
    #expect(result.launchdStatus.isLoaded == false)
}

@Test
func protectionServiceDeploymentCoordinatorTreatsLoadedServiceAsInstalledWhenBootstrapFails() throws {
    let root = try makeLaunchdFixtureRoot()
    _ = try makeLaunchdHelperExecutable(at: root)
    let paths = ProtectionServiceRegistrationPaths(
        applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
        launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
    )
    let installer = ProtectionServiceInstaller(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
        registrationPaths: paths
    )
    let runner = StubLaunchctlRunner()
    let bootstrapArgs = ["bootstrap", "gui/501", paths.launchAgentPlistURL(for: .beta).path]
    runner.resultsByArguments[bootstrapArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
        arguments: bootstrapArgs,
        exitCode: 5,
        standardOutput: "",
        standardError: "bootstrap failed: 5: Input/output error"
    )
    let printArgs = ["print", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]
    runner.resultsByArguments[printArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
        arguments: printArgs,
        exitCode: 0,
        standardOutput: "service = loaded",
        standardError: ""
    )
    let manager = ProtectionServiceLaunchdManager(
        runner: runner,
        registrationPaths: paths,
        userID: 501
    )
    let coordinator = ProtectionServiceDeploymentCoordinator(
        installer: installer,
        launchdManager: manager
    )

    let result = try coordinator.installAndBootstrap()
    let receiptData = try Data(contentsOf: paths.receiptURL)
    let receipt = try JSONDecoder().decode(ProtectionInstallationReceipt.self, from: receiptData)

    #expect(result.receipt.state == .installed)
    #expect(receipt.state == .installed)
    #expect(result.launchdStatus.isLoaded)
    #expect(result.receipt.detail.contains("already loaded"))
    #expect(runner.invocations.contains(["kickstart", "-k", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]))
}

@Test
func protectionServiceDeploymentCoordinatorBootoutRemovesFiles() throws {
    let root = try makeLaunchdFixtureRoot()
    _ = try makeLaunchdHelperExecutable(at: root)
    let paths = ProtectionServiceRegistrationPaths(
        applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
        launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
    )
    let installer = ProtectionServiceInstaller(
        helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
        registrationPaths: paths
    )
    _ = try installer.install()

    let runner = StubLaunchctlRunner()
    let printArgs = ["print", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]
    runner.resultsByArguments[printArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
        arguments: printArgs,
        exitCode: 0,
        standardOutput: "service = loaded",
        standardError: ""
    )
    let manager = ProtectionServiceLaunchdManager(
        runner: runner,
        registrationPaths: paths,
        userID: 501
    )
    let coordinator = ProtectionServiceDeploymentCoordinator(
        installer: installer,
        launchdManager: manager
    )

    _ = try coordinator.bootoutAndUninstall()

    #expect(FileManager.default.fileExists(atPath: paths.receiptURL.path) == false)
    #expect(FileManager.default.fileExists(atPath: paths.launchAgentPlistURL(for: .beta).path) == false)
    #expect(runner.invocations.contains(["bootout", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]))
}

private func makeLaunchdFixtureRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@discardableResult
private func makeLaunchdHelperExecutable(at root: URL) throws -> URL {
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

private final class StubLaunchctlRunner: ProtectionServiceLaunchctlRunning, @unchecked Sendable {
    var resultsByArguments: [String: ProtectionServiceLaunchdCommandResult] = [:]
    var invocations: [[String]] = []

    func run(arguments: [String]) throws -> ProtectionServiceLaunchdCommandResult {
        invocations.append(arguments)
        let key = arguments.joined(separator: "\u{1F}")
        return resultsByArguments[key]
            ?? ProtectionServiceLaunchdCommandResult(
                arguments: arguments,
                exitCode: 0,
                standardOutput: "",
                standardError: ""
            )
    }
}

final class ProtectionServiceLaunchdManagerTests: XCTestCase {
    func testProtectionServiceLaunchdManagerRunsBootstrapKickstartAndStatus() throws {
        let runner = StubLaunchctlRunner()
        let paths = ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: URL(fileURLWithPath: "/tmp/app-support", isDirectory: true),
            launchAgentsDirectory: URL(fileURLWithPath: "/tmp/launch-agents", isDirectory: true)
        )
        let manager = ProtectionServiceLaunchdManager(
            runner: runner,
            registrationPaths: paths,
            userID: 501
        )

        let printArgs = ["print", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]
        runner.resultsByArguments[printArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
            arguments: printArgs,
            exitCode: 0,
            standardOutput: "service = loaded",
            standardError: ""
        )

        _ = try manager.bootstrap()
        _ = try manager.kickstart()
        let status = try manager.status()

        XCTAssertTrue(status.isLoaded)
        XCTAssertEqual(runner.invocations[0], ["bootstrap", "gui/501", "/tmp/launch-agents/com.richardgeorgedavis.google-drive-icon-guard.beta.helper.plist"])
        XCTAssertEqual(runner.invocations[1], ["kickstart", "-k", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"])
        XCTAssertEqual(runner.invocations[2], printArgs)
    }

    func testProtectionServiceDeploymentCoordinatorWritesErrorReceiptWhenBootstrapFails() throws {
        let root = try makeLaunchdFixtureRoot()
        _ = try makeLaunchdHelperExecutable(at: root)
        let paths = ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
        )
        let installer = ProtectionServiceInstaller(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
            registrationPaths: paths
        )
        let runner = StubLaunchctlRunner()
        let bootstrapArgs = ["bootstrap", "gui/501", paths.launchAgentPlistURL(for: .beta).path]
        runner.resultsByArguments[bootstrapArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
            arguments: bootstrapArgs,
            exitCode: 5,
            standardOutput: "",
            standardError: "bootstrap failed"
        )
        let printArgs = ["print", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]
        runner.resultsByArguments[printArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
            arguments: printArgs,
            exitCode: 113,
            standardOutput: "",
            standardError: "could not find service"
        )
        let manager = ProtectionServiceLaunchdManager(
            runner: runner,
            registrationPaths: paths,
            userID: 501
        )
        let coordinator = ProtectionServiceDeploymentCoordinator(
            installer: installer,
            launchdManager: manager
        )

        let result = try coordinator.installAndBootstrap()
        let receiptData = try Data(contentsOf: paths.receiptURL)
        let receipt = try JSONDecoder().decode(ProtectionInstallationReceipt.self, from: receiptData)

        XCTAssertEqual(result.receipt.state, .error)
        XCTAssertEqual(receipt.state, .error)
        XCTAssertFalse(result.launchdStatus.isLoaded)
    }

    func testProtectionServiceDeploymentCoordinatorTreatsLoadedServiceAsInstalledWhenBootstrapFails() throws {
        let root = try makeLaunchdFixtureRoot()
        _ = try makeLaunchdHelperExecutable(at: root)
        let paths = ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
        )
        let installer = ProtectionServiceInstaller(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
            registrationPaths: paths
        )
        let runner = StubLaunchctlRunner()
        let bootstrapArgs = ["bootstrap", "gui/501", paths.launchAgentPlistURL(for: .beta).path]
        runner.resultsByArguments[bootstrapArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
            arguments: bootstrapArgs,
            exitCode: 5,
            standardOutput: "",
            standardError: "bootstrap failed: 5: Input/output error"
        )
        let printArgs = ["print", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]
        runner.resultsByArguments[printArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
            arguments: printArgs,
            exitCode: 0,
            standardOutput: "service = loaded",
            standardError: ""
        )
        let manager = ProtectionServiceLaunchdManager(
            runner: runner,
            registrationPaths: paths,
            userID: 501
        )
        let coordinator = ProtectionServiceDeploymentCoordinator(
            installer: installer,
            launchdManager: manager
        )

        let result = try coordinator.installAndBootstrap()
        let receiptData = try Data(contentsOf: paths.receiptURL)
        let receipt = try JSONDecoder().decode(ProtectionInstallationReceipt.self, from: receiptData)

        XCTAssertEqual(result.receipt.state, .installed)
        XCTAssertEqual(receipt.state, .installed)
        XCTAssertTrue(result.launchdStatus.isLoaded)
        XCTAssertTrue(result.receipt.detail.contains("already loaded"))
        XCTAssertTrue(runner.invocations.contains(["kickstart", "-k", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]))
    }

    func testProtectionServiceDeploymentCoordinatorBootoutRemovesFiles() throws {
        let root = try makeLaunchdFixtureRoot()
        _ = try makeLaunchdHelperExecutable(at: root)
        let paths = ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
        )
        let installer = ProtectionServiceInstaller(
            helperHostLocator: ProtectionHelperHostLocator(currentDirectoryPath: root.path),
            registrationPaths: paths
        )
        _ = try installer.install()

        let runner = StubLaunchctlRunner()
        let printArgs = ["print", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]
        runner.resultsByArguments[printArgs.joined(separator: "\u{1F}")] = ProtectionServiceLaunchdCommandResult(
            arguments: printArgs,
            exitCode: 0,
            standardOutput: "service = loaded",
            standardError: ""
        )
        let manager = ProtectionServiceLaunchdManager(
            runner: runner,
            registrationPaths: paths,
            userID: 501
        )
        let coordinator = ProtectionServiceDeploymentCoordinator(
            installer: installer,
            launchdManager: manager
        )

        _ = try coordinator.bootoutAndUninstall()

        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.receiptURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.launchAgentPlistURL(for: .beta).path))
        XCTAssertTrue(runner.invocations.contains(["bootout", "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper"]))
    }
}

private func makeLaunchdFixtureRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@discardableResult
private func makeLaunchdHelperExecutable(at root: URL) throws -> URL {
    let helperURL = root.appendingPathComponent(".build/debug/drive-icon-guard-helper", isDirectory: false)
    try FileManager.default.createDirectory(at: helperURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "#!/bin/zsh\nexit 0\n".write(to: helperURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
    return helperURL
}
#endif
