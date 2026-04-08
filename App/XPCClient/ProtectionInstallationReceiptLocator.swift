import Foundation
import DriveIconGuardIPC

public struct ProtectionInstallationReceipt: Codable, Equatable, Sendable {
    public var state: ProtectionInstallationState
    public var detail: String
    public var helperExecutablePath: String?
    public var machServiceName: String?
    public var launchAgentPlistPath: String?

    public init(
        state: ProtectionInstallationState,
        detail: String,
        helperExecutablePath: String? = nil,
        machServiceName: String? = nil,
        launchAgentPlistPath: String? = nil
    ) {
        self.state = state
        self.detail = detail
        self.helperExecutablePath = helperExecutablePath
        self.machServiceName = machServiceName
        self.launchAgentPlistPath = launchAgentPlistPath
    }
}

public enum ProtectionInstallationReceiptLoadResult: Equatable, Sendable {
    case unavailable
    case loaded(ProtectionInstallationReceipt)
    case invalidFormat(detail: String)
}

public struct ProtectionInstallationReceiptLocator {
    private let fileManager: FileManager
    private let bundle: Bundle
    private let currentDirectoryPath: String
    private let decoder: JSONDecoder
    private let registrationPaths: ProtectionServiceRegistrationPaths?

    public init(
        fileManager: FileManager = .default,
        bundle: Bundle = .main,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        decoder: JSONDecoder = JSONDecoder(),
        registrationPaths: ProtectionServiceRegistrationPaths? = nil
    ) {
        self.fileManager = fileManager
        self.bundle = bundle
        self.currentDirectoryPath = currentDirectoryPath
        self.decoder = decoder
        self.registrationPaths = registrationPaths
    }

    public func loadReceipt() -> ProtectionInstallationReceiptLoadResult {
        guard let receiptURL = locateReceiptURL() else {
            return .unavailable
        }

        do {
            let data = try Data(contentsOf: receiptURL)
            let receipt = try decoder.decode(ProtectionInstallationReceipt.self, from: data)
            return .loaded(receipt)
        } catch {
            return .invalidFormat(
                detail: "Installation receipt at \(receiptURL.path) could not be decoded: \(error.localizedDescription)"
            )
        }
    }

    public func locateReceiptURL() -> URL? {
        candidateURLs().first(where: { fileManager.fileExists(atPath: $0.path) })
    }

    private func candidateURLs() -> [URL] {
        let bundleRoot = bundle.bundleURL
        let resolvedRegistrationPaths = registrationPaths ?? ProtectionServiceRegistrationPaths(fileManager: fileManager)
        let urls = [
            bundleRoot.appendingPathComponent("Contents/Resources/Installer/installation-receipt.json", isDirectory: false),
            URL(fileURLWithPath: currentDirectoryPath, isDirectory: true).appendingPathComponent("Installer/installation-receipt.json", isDirectory: false),
            resolvedRegistrationPaths.receiptURL
        ]

        var seenPaths = Set<String>()
        return urls.filter { seenPaths.insert($0.path).inserted }
    }
}
