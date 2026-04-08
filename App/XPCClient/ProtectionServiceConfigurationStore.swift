import Foundation
import DriveIconGuardIPC

public struct ProtectionServiceConfigurationStore {
    private let fileManager: FileManager
    private let registrationPaths: ProtectionServiceRegistrationPaths
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileManager: FileManager = .default,
        registrationPaths: ProtectionServiceRegistrationPaths = ProtectionServiceRegistrationPaths(),
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.fileManager = fileManager
        self.registrationPaths = registrationPaths
        self.encoder = encoder
        self.decoder = decoder
    }

    public var configurationURL: URL {
        registrationPaths.applicationSupportDirectory
            .appendingPathComponent("protection-configuration.json", isDirectory: false)
    }

    public func load() throws -> ProtectionServiceConfiguration? {
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: configurationURL)
        return try decoder.decode(ProtectionServiceConfiguration.self, from: data)
    }

    public func persist(_ configuration: ProtectionServiceConfiguration) throws {
        try fileManager.createDirectory(
            at: registrationPaths.applicationSupportDirectory,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(configuration)
        try data.write(to: configurationURL, options: .atomic)
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            return
        }

        try fileManager.removeItem(at: configurationURL)
    }
}
