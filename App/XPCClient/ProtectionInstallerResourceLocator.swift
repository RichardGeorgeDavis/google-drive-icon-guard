import Foundation

public struct ProtectionInstallerResourceLocator {
    private let fileManager: FileManager
    private let bundle: Bundle
    private let currentDirectoryPath: String

    public init(
        fileManager: FileManager = .default,
        bundle: Bundle = .main,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) {
        self.fileManager = fileManager
        self.bundle = bundle
        self.currentDirectoryPath = currentDirectoryPath
    }

    public func locateServiceRegistrationDirectory() -> URL? {
        candidateURLs().first(where: { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        })
    }

    private func candidateURLs() -> [URL] {
        let bundleRoot = bundle.bundleURL

        let urls = [
            bundleRoot.appendingPathComponent("Contents/Resources/Installer/ServiceRegistration", isDirectory: true),
            URL(fileURLWithPath: currentDirectoryPath, isDirectory: true).appendingPathComponent("Installer/ServiceRegistration", isDirectory: true)
        ]

        var seenPaths = Set<String>()
        return urls.filter { seenPaths.insert($0.path).inserted }
    }
}
