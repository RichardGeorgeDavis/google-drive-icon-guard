import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct ProtectionServiceLaunchdCommandResult: Equatable, Sendable {
    public var arguments: [String]
    public var exitCode: Int32
    public var standardOutput: String
    public var standardError: String

    public init(
        arguments: [String],
        exitCode: Int32,
        standardOutput: String,
        standardError: String
    ) {
        self.arguments = arguments
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public protocol ProtectionServiceLaunchctlRunning: Sendable {
    func run(arguments: [String]) throws -> ProtectionServiceLaunchdCommandResult
}

public struct ProcessProtectionServiceLaunchctlRunner: ProtectionServiceLaunchctlRunning {
    public init() {}

    public func run(arguments: [String]) throws -> ProtectionServiceLaunchdCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return ProtectionServiceLaunchdCommandResult(
            arguments: arguments,
            exitCode: process.terminationStatus,
            standardOutput: stdout,
            standardError: stderr
        )
    }
}

public struct ProtectionServiceLaunchdStatus: Codable, Equatable, Sendable {
    public var domainTarget: String
    public var serviceTarget: String
    public var isLoaded: Bool
    public var detail: String

    public init(
        domainTarget: String,
        serviceTarget: String,
        isLoaded: Bool,
        detail: String
    ) {
        self.domainTarget = domainTarget
        self.serviceTarget = serviceTarget
        self.isLoaded = isLoaded
        self.detail = detail
    }
}

public enum ProtectionServiceLaunchdError: LocalizedError {
    case commandFailed(ProtectionServiceLaunchdCommandResult)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let result):
            let stderr = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            let stdout = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = stderr.isEmpty ? stdout : stderr
            return "launchctl \(result.arguments.joined(separator: " ")) failed with exit code \(result.exitCode): \(detail)"
        }
    }
}

public struct ProtectionServiceLaunchdManager {
    private let runner: any ProtectionServiceLaunchctlRunning
    private let registrationConfiguration: ProtectionServiceRegistrationConfiguration
    private let registrationPaths: ProtectionServiceRegistrationPaths
    private let userID: uid_t

    public init(
        runner: any ProtectionServiceLaunchctlRunning = ProcessProtectionServiceLaunchctlRunner(),
        registrationConfiguration: ProtectionServiceRegistrationConfiguration = .beta,
        registrationPaths: ProtectionServiceRegistrationPaths = ProtectionServiceRegistrationPaths(),
        userID: uid_t = getuid()
    ) {
        self.runner = runner
        self.registrationConfiguration = registrationConfiguration
        self.registrationPaths = registrationPaths
        self.userID = userID
    }

    public var domainTarget: String {
        "gui/\(userID)"
    }

    public var serviceTarget: String {
        "\(domainTarget)/\(registrationConfiguration.launchdLabel)"
    }

    public func bootstrap() throws -> ProtectionServiceLaunchdCommandResult {
        let plistPath = registrationPaths.launchAgentPlistURL(for: registrationConfiguration).path
        let result = try runner.run(arguments: ["bootstrap", domainTarget, plistPath])
        guard result.exitCode == 0 else {
            throw ProtectionServiceLaunchdError.commandFailed(result)
        }
        return result
    }

    public func bootout() throws -> ProtectionServiceLaunchdCommandResult {
        let result = try runner.run(arguments: ["bootout", serviceTarget])
        guard result.exitCode == 0 else {
            throw ProtectionServiceLaunchdError.commandFailed(result)
        }
        return result
    }

    public func kickstart() throws -> ProtectionServiceLaunchdCommandResult {
        let result = try runner.run(arguments: ["kickstart", "-k", serviceTarget])
        guard result.exitCode == 0 else {
            throw ProtectionServiceLaunchdError.commandFailed(result)
        }
        return result
    }

    public func status() throws -> ProtectionServiceLaunchdStatus {
        let result = try runner.run(arguments: ["print", serviceTarget])
        if result.exitCode == 0 {
            let detail = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return ProtectionServiceLaunchdStatus(
                domainTarget: domainTarget,
                serviceTarget: serviceTarget,
                isLoaded: true,
                detail: detail.isEmpty ? "launchctl print succeeded for \(serviceTarget)." : detail
            )
        }

        let detail = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        return ProtectionServiceLaunchdStatus(
            domainTarget: domainTarget,
            serviceTarget: serviceTarget,
            isLoaded: false,
            detail: detail.isEmpty ? "launchctl print did not find \(serviceTarget)." : detail
        )
    }
}

public struct ProtectionServiceDeploymentResult: Codable, Equatable, Sendable {
    public var receipt: ProtectionInstallationReceipt
    public var launchdStatus: ProtectionServiceLaunchdStatus

    public init(
        receipt: ProtectionInstallationReceipt,
        launchdStatus: ProtectionServiceLaunchdStatus
    ) {
        self.receipt = receipt
        self.launchdStatus = launchdStatus
    }
}

public struct ProtectionServiceDeploymentCoordinator {
    private let installer: ProtectionServiceInstaller
    private let launchdManager: ProtectionServiceLaunchdManager

    public init(
        installer: ProtectionServiceInstaller = ProtectionServiceInstaller(),
        launchdManager: ProtectionServiceLaunchdManager = ProtectionServiceLaunchdManager()
    ) {
        self.installer = installer
        self.launchdManager = launchdManager
    }

    public func installAndBootstrap(helperExecutablePath: String? = nil) throws -> ProtectionServiceDeploymentResult {
        var receipt = try installer.install(helperExecutablePath: helperExecutablePath)

        do {
            _ = try launchdManager.bootstrap()
            _ = try launchdManager.kickstart()
            let launchdStatus = try launchdManager.status()
            receipt.detail = "LaunchAgent registration was written and launchctl bootstrap/kickstart completed for \(launchdStatus.serviceTarget)."
            try installer.persistReceipt(receipt)
            return ProtectionServiceDeploymentResult(
                receipt: receipt,
                launchdStatus: launchdStatus
            )
        } catch {
            var failureStatus = (try? launchdManager.status()) ?? ProtectionServiceLaunchdStatus(
                domainTarget: launchdManager.domainTarget,
                serviceTarget: launchdManager.serviceTarget,
                isLoaded: false,
                detail: error.localizedDescription
            )

            if failureStatus.isLoaded {
                _ = try? launchdManager.kickstart()
                failureStatus = (try? launchdManager.status()) ?? failureStatus
                receipt.state = .installed
                receipt.detail = "LaunchAgent files were written. launchctl bootstrap returned an error, but an existing helper service is already loaded for \(failureStatus.serviceTarget). Reusing that running service; use Remove Installed Helper if you need a clean reinstall."
                try installer.persistReceipt(receipt)
                return ProtectionServiceDeploymentResult(
                    receipt: receipt,
                    launchdStatus: failureStatus
                )
            }

            receipt.state = .error
            receipt.detail = "LaunchAgent files were written, but launchctl bootstrap failed: \(error.localizedDescription)"
            try? installer.persistReceipt(receipt)
            return ProtectionServiceDeploymentResult(
                receipt: receipt,
                launchdStatus: failureStatus
            )
        }
    }

    public func bootoutAndUninstall() throws -> ProtectionServiceLaunchdStatus {
        let statusBeforeRemoval = (try? launchdManager.status()) ?? ProtectionServiceLaunchdStatus(
            domainTarget: launchdManager.domainTarget,
            serviceTarget: launchdManager.serviceTarget,
            isLoaded: false,
            detail: "Service was not loaded before bootout."
        )

        if statusBeforeRemoval.isLoaded {
            _ = try launchdManager.bootout()
        }

        try installer.uninstall()
        return (try? launchdManager.status()) ?? ProtectionServiceLaunchdStatus(
            domainTarget: launchdManager.domainTarget,
            serviceTarget: launchdManager.serviceTarget,
            isLoaded: false,
            detail: "LaunchAgent registration files were removed."
        )
    }

    public func status() throws -> ProtectionServiceLaunchdStatus {
        try launchdManager.status()
    }
}
