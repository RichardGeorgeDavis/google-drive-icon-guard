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
    private let bundle: Bundle

    public init(fileManager: FileManager = .default, bundle: Bundle = .main) {
        self.fileManager = fileManager
        self.bundle = bundle
    }

    public func defaultOutputURL(projectRoot: String = FileManager.default.currentDirectoryPath) -> URL {
        storageRootURL(projectRoot: projectRoot)
            .appendingPathComponent("latest.json", isDirectory: false)
    }

    public func historyDirectoryURL(projectRoot: String = FileManager.default.currentDirectoryPath) -> URL {
        storageRootURL(projectRoot: projectRoot)
            .appendingPathComponent("history", isDirectory: true)
    }

    public func activityLogURL(projectRoot: String = FileManager.default.currentDirectoryPath) -> URL {
        storageRootURL(projectRoot: projectRoot)
            .appendingPathComponent("activity-log.json", isDirectory: false)
    }

    public func storageRootURL(projectRoot: String = FileManager.default.currentDirectoryPath) -> URL {
        resolvedStorageRootURL(projectRoot: projectRoot)
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

    public func loadReport(at url: URL) throws -> ScopeInventoryReport {
        let data = try Data(contentsOf: url)
        return try PrettyJSONDecoder.decode(ScopeInventoryReport.self, from: data)
    }

    public func loadRecentSnapshots(
        limit: Int = 5,
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws -> [PersistedScopeInventorySnapshot] {
        guard limit > 0 else {
            return []
        }

        let historyDirectoryURL = historyDirectoryURL(projectRoot: projectRoot)
        guard fileManager.fileExists(atPath: historyDirectoryURL.path) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: historyDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }
        .prefix(limit)

        return try urls.map { url in
            PersistedScopeInventorySnapshot(url: url, report: try loadReport(at: url))
        }
    }

    public func compare(
        current: ScopeInventoryReport,
        previous: ScopeInventoryReport
    ) -> ScopeInventoryHistoryComparison {
        let currentScanResultsByPath = Dictionary(
            uniqueKeysWithValues: current.artefactInventory.scopeResults.map { ($0.scopePath, $0) }
        )
        let previousScanResultsByPath = Dictionary(
            uniqueKeysWithValues: previous.artefactInventory.scopeResults.map { ($0.scopePath, $0) }
        )

        let currentScopesByPath = Dictionary(uniqueKeysWithValues: current.scopes.map { ($0.path, $0) })
        let previousScopesByPath = Dictionary(uniqueKeysWithValues: previous.scopes.map { ($0.path, $0) })
        let allPaths = Set(currentScopesByPath.keys).union(previousScopesByPath.keys)

        return ScopeInventoryHistoryComparison(
            currentGeneratedAt: current.generatedAt,
            previousGeneratedAt: previous.generatedAt,
            delta: ScopeInventoryHistoryDelta(
                scopeCount: current.scopes.count - previous.scopes.count,
                artefactCount: current.artefactInventory.totalArtefactCount - previous.artefactInventory.totalArtefactCount,
                matchedScopeCount: current.artefactInventory.matchedScopeCount - previous.artefactInventory.matchedScopeCount,
                totalBytes: current.artefactInventory.totalBytes - previous.artefactInventory.totalBytes,
                warningCount: combinedWarningCount(for: current) - combinedWarningCount(for: previous),
                perScopeChanges: allPaths.compactMap { path in
                    let currentScope = currentScopesByPath[path]
                    let previousScope = previousScopesByPath[path]
                    let currentScan = currentScanResultsByPath[path]
                    let previousScan = previousScanResultsByPath[path]

                    let changeKind: ScopeHistoryChangeKind
                    if currentScope != nil, previousScope == nil {
                        changeKind = .added
                    } else if currentScope == nil, previousScope != nil {
                        changeKind = .removed
                    } else {
                        changeKind = .changed
                    }

                    let artefactDelta = (currentScan?.matchedArtefactCount ?? 0) - (previousScan?.matchedArtefactCount ?? 0)
                    let byteDelta = (currentScan?.matchedBytes ?? 0) - (previousScan?.matchedBytes ?? 0)
                    let warningDelta = warningDeltaForPath(path, current: current, previous: previous)

                    if changeKind == .changed && artefactDelta == 0 && byteDelta == 0 && warningDelta == 0 {
                        return nil
                    }

                    return ScopeHistoryChange(
                        scopePath: path,
                        displayName: currentScope?.displayName ?? previousScope?.displayName ?? URL(fileURLWithPath: path).lastPathComponent,
                        changeKind: changeKind,
                        artefactDelta: artefactDelta,
                        byteDelta: byteDelta,
                        warningDelta: warningDelta
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.changeKind != rhs.changeKind {
                        return lhs.changeKind.rawValue < rhs.changeKind.rawValue
                    }
                    if lhs.artefactDelta != rhs.artefactDelta {
                        return lhs.artefactDelta > rhs.artefactDelta
                    }
                    return lhs.scopePath < rhs.scopePath
                }
            )
        )
    }

    public func loadActivityLog(
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws -> PersistedActivityLog {
        let url = activityLogURL(projectRoot: projectRoot)
        guard fileManager.fileExists(atPath: url.path) else {
            return PersistedActivityLog()
        }

        let data = try Data(contentsOf: url)
        return try PrettyJSONDecoder.decode(PersistedActivityLog.self, from: data)
    }

    public func persistActivityLog(
        _ activityLog: PersistedActivityLog,
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws {
        let destinationURL = activityLogURL(projectRoot: projectRoot)
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PrettyJSONEncoder.encode(activityLog)
        try data.write(to: destinationURL, options: .atomic)
    }

    public func clearStoredData(
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws {
        let rootURL = storageRootURL(projectRoot: projectRoot)
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return
        }

        try fileManager.removeItem(at: rootURL)
    }

    private func historyFileName(for report: ScopeInventoryReport) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"

        return formatter.string(from: report.generatedAt) + ".json"
    }

    private func combinedWarningCount(for report: ScopeInventoryReport) -> Int {
        report.warnings.count + report.artefactInventory.warnings.count
    }

    private func warningDeltaForPath(
        _ path: String,
        current: ScopeInventoryReport,
        previous: ScopeInventoryReport
    ) -> Int {
        let currentCount = combinedWarnings(for: current).filter { $0.message.contains(path) }.count
        let previousCount = combinedWarnings(for: previous).filter { $0.message.contains(path) }.count
        return currentCount - previousCount
    }

    private func combinedWarnings(for report: ScopeInventoryReport) -> [DiscoveryWarning] {
        report.warnings + report.artefactInventory.warnings
    }

    private func resolvedStorageRootURL(projectRoot: String) -> URL {
        if shouldUseAppSupportStorage {
            return appSupportStorageRootURL()
        }

        return URL(fileURLWithPath: projectRoot, isDirectory: true)
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent("scope-inventory", isDirectory: true)
    }

    private var shouldUseAppSupportStorage: Bool {
        bundle.bundleURL.pathExtension == "app"
    }

    private func appSupportStorageRootURL() -> URL {
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)

        let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle.bundleURL.deletingPathExtension().lastPathComponent

        return appSupportDirectory
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("scope-inventory", isDirectory: true)
    }
}
