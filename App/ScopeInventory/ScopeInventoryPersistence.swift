import Foundation
import DriveIconGuardShared

public struct ScopeInventoryPersistence {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func defaultOutputURL(projectRoot: String = FileManager.default.currentDirectoryPath) -> URL {
        URL(fileURLWithPath: projectRoot, isDirectory: true)
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent("scope-inventory", isDirectory: true)
            .appendingPathComponent("latest.json", isDirectory: false)
    }

    @discardableResult
    public func persist(
        _ report: ScopeInventoryReport,
        outputURL: URL? = nil,
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws -> URL {
        let destinationURL = outputURL ?? defaultOutputURL(projectRoot: projectRoot)
        let parentDirectoryURL = destinationURL.deletingLastPathComponent()

        try fileManager.createDirectory(at: parentDirectoryURL, withIntermediateDirectories: true)

        let data = try PrettyJSONEncoder.encode(report)
        try data.write(to: destinationURL, options: .atomic)

        return destinationURL
    }
}
