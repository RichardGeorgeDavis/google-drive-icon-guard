import Foundation

public struct ProtectionHelperHostLocator {
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

    public func locate() -> URL? {
        candidateURLs().first(where: { fileManager.isExecutableFile(atPath: $0.path) })
    }

    private func candidateURLs() -> [URL] {
        let executableName = "drive-icon-guard-helper"
        let bundleRoot = bundle.bundleURL
        let executableDirectory = bundle.executableURL?.deletingLastPathComponent()

        let urls = [
            bundleRoot.appendingPathComponent("Contents/Helpers", isDirectory: true).appendingPathComponent(executableName, isDirectory: false),
            bundleRoot.appendingPathComponent("Contents/Resources", isDirectory: true).appendingPathComponent(executableName, isDirectory: false),
            executableDirectory?.appendingPathComponent(executableName, isDirectory: false),
            URL(fileURLWithPath: currentDirectoryPath, isDirectory: true).appendingPathComponent(".build/debug", isDirectory: true).appendingPathComponent(executableName, isDirectory: false),
            URL(fileURLWithPath: currentDirectoryPath, isDirectory: true).appendingPathComponent(".build/release", isDirectory: true).appendingPathComponent(executableName, isDirectory: false)
        ]

        var seenPaths = Set<String>()
        return urls.compactMap { $0 }.filter { seenPaths.insert($0.path).inserted }
    }
}
