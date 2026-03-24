import Foundation
import DriveIconGuardShared

public struct ScopeInventoryPersistenceResult: Equatable, Sendable {
    public var latestURL: URL
    public var historyURL: URL

    public init(latestURL: URL, historyURL: URL) {
        self.latestURL = latestURL
        self.historyURL = historyURL
    }
}

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

    public func historyDirectoryURL(projectRoot: String = FileManager.default.currentDirectoryPath) -> URL {
        URL(fileURLWithPath: projectRoot, isDirectory: true)
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent("scope-inventory", isDirectory: true)
            .appendingPathComponent("history", isDirectory: true)
    }

    @discardableResult
    public func persist(
        _ report: ScopeInventoryReport,
        outputURL: URL? = nil,
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws -> ScopeInventoryPersistenceResult {
        let destinationURL = outputURL ?? defaultOutputURL(projectRoot: projectRoot)
        let parentDirectoryURL = destinationURL.deletingLastPathComponent()
        let historyDirectoryURL = historyDirectoryURL(projectRoot: projectRoot)

        try fileManager.createDirectory(at: parentDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true)

        let data = try PrettyJSONEncoder.encode(report)
        let historyURL = historyDirectoryURL.appendingPathComponent(historyFileName(for: report), isDirectory: false)

        try data.write(to: destinationURL, options: .atomic)
        try data.write(to: historyURL, options: .atomic)

        return ScopeInventoryPersistenceResult(latestURL: destinationURL, historyURL: historyURL)
    }

    private func historyFileName(for report: ScopeInventoryReport) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"

        return formatter.string(from: report.generatedAt) + ".json"
    }
}
