import Foundation

public struct ProtectionServiceRegistrationConfiguration: Codable, Equatable, Sendable {
    public var launchdLabel: String
    public var machServiceName: String
    public var launchAgentPlistName: String

    public init(
        launchdLabel: String,
        machServiceName: String,
        launchAgentPlistName: String
    ) {
        self.launchdLabel = launchdLabel
        self.machServiceName = machServiceName
        self.launchAgentPlistName = launchAgentPlistName
    }

    public func programArguments(helperExecutablePath: String) -> [String] {
        [
            helperExecutablePath,
            "--xpc-service",
            "--mach-service-name",
            machServiceName
        ]
    }

    public static let beta = ProtectionServiceRegistrationConfiguration(
        launchdLabel: "com.richardgeorgedavis.google-drive-icon-guard.beta.helper",
        machServiceName: "com.richardgeorgedavis.google-drive-icon-guard.beta.helper.xpc",
        launchAgentPlistName: "com.richardgeorgedavis.google-drive-icon-guard.beta.helper.plist"
    )
}

public struct ProtectionServiceRegistrationPaths: Sendable {
    public var applicationSupportDirectory: URL
    public var launchAgentsDirectory: URL

    public init(
        fileManager: FileManager = .default,
        applicationSupportDirectory: URL? = nil,
        launchAgentsDirectory: URL? = nil
    ) {
        let defaultAppSupport = applicationSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Google Drive Icon Guard", isDirectory: true)
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
                .appendingPathComponent("ApplicationSupport/Google Drive Icon Guard", isDirectory: true)
        let defaultLaunchAgents = launchAgentsDirectory
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents", isDirectory: true)

        self.applicationSupportDirectory = defaultAppSupport
        self.launchAgentsDirectory = defaultLaunchAgents
    }

    public var receiptURL: URL {
        applicationSupportDirectory.appendingPathComponent("installation-receipt.json", isDirectory: false)
    }

    public func launchAgentPlistURL(for configuration: ProtectionServiceRegistrationConfiguration) -> URL {
        launchAgentsDirectory.appendingPathComponent(configuration.launchAgentPlistName, isDirectory: false)
    }
}

public struct ProtectionServiceRegistrationPlan: Codable, Equatable, Sendable {
    public var helperExecutablePath: String
    public var machServiceName: String
    public var launchdLabel: String
    public var launchAgentPlistPath: String
    public var receiptPath: String

    public init(
        helperExecutablePath: String,
        machServiceName: String,
        launchdLabel: String,
        launchAgentPlistPath: String,
        receiptPath: String
    ) {
        self.helperExecutablePath = helperExecutablePath
        self.machServiceName = machServiceName
        self.launchdLabel = launchdLabel
        self.launchAgentPlistPath = launchAgentPlistPath
        self.receiptPath = receiptPath
    }
}

public enum ProtectionServiceInstallerError: LocalizedError {
    case missingHelperExecutable
    case helperIsNotExecutable(path: String)

    public var errorDescription: String? {
        switch self {
        case .missingHelperExecutable:
            return "No packaged helper executable could be located for service registration."
        case .helperIsNotExecutable(let path):
            return "Helper executable at \(path) is missing or not executable."
        }
    }
}

public struct ProtectionServiceInstaller {
    private let fileManager: FileManager
    private let helperHostLocator: ProtectionHelperHostLocator
    private let registrationConfiguration: ProtectionServiceRegistrationConfiguration
    private let registrationPaths: ProtectionServiceRegistrationPaths
    private let encoder: JSONEncoder

    public init(
        fileManager: FileManager = .default,
        helperHostLocator: ProtectionHelperHostLocator = ProtectionHelperHostLocator(),
        registrationConfiguration: ProtectionServiceRegistrationConfiguration = .beta,
        registrationPaths: ProtectionServiceRegistrationPaths = ProtectionServiceRegistrationPaths(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.fileManager = fileManager
        self.helperHostLocator = helperHostLocator
        self.registrationConfiguration = registrationConfiguration
        self.registrationPaths = registrationPaths
        self.encoder = encoder
    }

    public func install(helperExecutablePath: String? = nil) throws -> ProtectionInstallationReceipt {
        let resolvedHelperPath = try resolveHelperExecutablePath(explicitPath: helperExecutablePath)
        let launchAgentPlistURL = registrationPaths.launchAgentPlistURL(for: registrationConfiguration)

        try fileManager.createDirectory(at: registrationPaths.applicationSupportDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: registrationPaths.launchAgentsDirectory, withIntermediateDirectories: true)

        let plistData = try renderedLaunchAgentPlist(helperExecutablePath: resolvedHelperPath)
        try plistData.write(to: launchAgentPlistURL)

        let receipt = ProtectionInstallationReceipt(
            state: .installed,
            detail: "LaunchAgent registration was written to \(launchAgentPlistURL.path). Bootstrap/start still depends on launchd lifecycle and user approval.",
            helperExecutablePath: resolvedHelperPath,
            machServiceName: registrationConfiguration.machServiceName,
            launchAgentPlistPath: launchAgentPlistURL.path
        )
        try persistReceipt(receipt)
        return receipt
    }

    public func uninstall() throws {
        let launchAgentPlistURL = registrationPaths.launchAgentPlistURL(for: registrationConfiguration)
        if fileManager.fileExists(atPath: launchAgentPlistURL.path) {
            try fileManager.removeItem(at: launchAgentPlistURL)
        }

        if fileManager.fileExists(atPath: registrationPaths.receiptURL.path) {
            try fileManager.removeItem(at: registrationPaths.receiptURL)
        }
    }

    public func plan(helperExecutablePath: String? = nil) throws -> ProtectionServiceRegistrationPlan {
        let resolvedHelperPath = try resolveHelperExecutablePath(explicitPath: helperExecutablePath)
        let launchAgentPlistURL = registrationPaths.launchAgentPlistURL(for: registrationConfiguration)
        return ProtectionServiceRegistrationPlan(
            helperExecutablePath: resolvedHelperPath,
            machServiceName: registrationConfiguration.machServiceName,
            launchdLabel: registrationConfiguration.launchdLabel,
            launchAgentPlistPath: launchAgentPlistURL.path,
            receiptPath: registrationPaths.receiptURL.path
        )
    }

    private func resolveHelperExecutablePath(explicitPath: String?) throws -> String {
        let resolvedPath = explicitPath ?? helperHostLocator.locate()?.path
        guard let resolvedPath else {
            throw ProtectionServiceInstallerError.missingHelperExecutable
        }

        guard fileManager.isExecutableFile(atPath: resolvedPath) else {
            throw ProtectionServiceInstallerError.helperIsNotExecutable(path: resolvedPath)
        }

        return resolvedPath
    }

    private func renderedLaunchAgentPlist(helperExecutablePath: String) throws -> Data {
        let plist: [String: Any] = [
            "Label": registrationConfiguration.launchdLabel,
            "ProgramArguments": registrationConfiguration.programArguments(helperExecutablePath: helperExecutablePath),
            "MachServices": [
                registrationConfiguration.machServiceName: true
            ],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Background"
        ]

        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    public func persistReceipt(_ receipt: ProtectionInstallationReceipt) throws {
        let data = try encoder.encode(receipt)
        try data.write(to: registrationPaths.receiptURL)
    }
}
