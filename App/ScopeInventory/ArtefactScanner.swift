import DriveIconGuardShared
import Darwin
import Foundation

public struct ArtefactScanner {
    private let fileManager: FileManager
    private let rules: [ArtefactRule]
    private let maxSamplesPerScope: Int

    public init(
        fileManager: FileManager = .default,
        rules: [ArtefactRule] = ArtefactScanner.defaultRules,
        maxSamplesPerScope: Int = 5
    ) {
        self.fileManager = fileManager
        self.rules = rules
        self.maxSamplesPerScope = max(1, maxSamplesPerScope)
    }

    public func scan(scopes: [DriveManagedScope], generatedAt: Date = Date()) -> ArtefactInventorySummary {
        var warnings: [DiscoveryWarning] = []
        let scopeResults = scopes.map { scope in
            let outcome = scan(scope: scope)
            warnings.append(contentsOf: outcome.warnings)
            return outcome.result
        }

        let scannedResults = scopeResults.filter { $0.scanStatus == .scanned }

        return ArtefactInventorySummary(
            generatedAt: generatedAt,
            scannedScopeCount: scannedResults.count,
            matchedScopeCount: scannedResults.filter { $0.matchedArtefactCount > 0 }.count,
            totalArtefactCount: scannedResults.reduce(0) { $0 + $1.matchedArtefactCount },
            totalBytes: scannedResults.reduce(0) { $0 + $1.matchedBytes },
            scopeResults: scopeResults.sorted(by: sortResults),
            warnings: warnings
        )
    }

    private func scan(scope: DriveManagedScope) -> (result: ScopeArtefactScanResult, warnings: [DiscoveryWarning]) {
        var warnings: [DiscoveryWarning] = []

        guard scope.supportStatus != .unsupported else {
            return (
                ScopeArtefactScanResult(
                    scopeID: scope.id,
                    scopeDisplayName: scope.displayName,
                    scopePath: scope.path,
                    scanStatus: .skippedUnsupported
                ),
                []
            )
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: scope.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            warnings.append(
                    FileAccessGuidance.warning(
                        operationCode: "scope_scan_path_missing",
                        path: scope.path,
                        error: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT)),
                        genericMessage: "Audit scan skipped \(scope.displayName) because the scope path was not found or is not a directory: \(scope.path)"
                    )
                )

            return (
                ScopeArtefactScanResult(
                    scopeID: scope.id,
                    scopeDisplayName: scope.displayName,
                    scopePath: scope.path,
                    scanStatus: .missingPath
                ),
                warnings
            )
        }

        let rootURL = URL(fileURLWithPath: scope.path, isDirectory: true)
        var scannedDirectoryCount = 0
        var inspectedFileCount = 0
        var skippedSymbolicLinkCount = 0
        var matchedArtefactCount = 0
        var matchedBytes = 0
        var artefactBuckets: [ArtefactType: (count: Int, bytes: Int)] = [:]
        var sampleMatches: [ArtefactSample] = []

        var directoriesToScan = [rootURL]

        while let directoryURL = directoriesToScan.popLast() {
            scannedDirectoryCount += 1
            let entries: [URL]
            let entryNames: [String]

            do {
                entryNames = try directoryEntryNames(atPath: directoryURL.path)
            } catch {
                warnings.append(
                    FileAccessGuidance.warning(
                        operationCode: "scope_scan_entry_unreadable",
                        path: directoryURL.path,
                        error: error,
                        genericMessage: "Audit scan could not read \(directoryURL.path) while scanning \(scope.displayName): \(error.localizedDescription)"
                    )
                )

                if directoryURL == rootURL {
                    return (
                        ScopeArtefactScanResult(
                            scopeID: scope.id,
                            scopeDisplayName: scope.displayName,
                            scopePath: scope.path,
                            scanStatus: .unreadable
                        ),
                        warnings
                    )
                }

                continue
            }

            entries = entryNames.map { directoryURL.appendingPathComponent($0) }

            for entryURL in entries {
                let resourceValues: URLResourceValues

                do {
                    resourceValues = try entryURL.resourceValues(forKeys: FileFootprint.resourceKeys)
                } catch {
                    warnings.append(
                        FileAccessGuidance.warning(
                            operationCode: "scope_scan_resource_values_failed",
                            path: entryURL.path,
                            error: error,
                            genericMessage: "Audit scan could not read file metadata for \(entryURL.path): \(error.localizedDescription)"
                        )
                    )
                    continue
                }

                if resourceValues.isSymbolicLink == true {
                    skippedSymbolicLinkCount += 1
                    continue
                }

                if resourceValues.isDirectory == true {
                    directoriesToScan.append(entryURL)
                    continue
                }

                guard resourceValues.isRegularFile == true else {
                    continue
                }

                inspectedFileCount += 1

                let filename = resourceValues.name ?? entryURL.lastPathComponent
                guard let rule = matchingRule(forFilename: filename, path: entryURL.path) else {
                    continue
                }

                let fileSize = FileFootprint.bytes(for: resourceValues)
                matchedArtefactCount += 1
                matchedBytes += fileSize
                let existingBucket = artefactBuckets[rule.artefactType] ?? (0, 0)
                artefactBuckets[rule.artefactType] = (
                    count: existingBucket.count + 1,
                    bytes: existingBucket.bytes + fileSize
                )

                if sampleMatches.count < maxSamplesPerScope {
                    sampleMatches.append(
                        ArtefactSample(
                            relativePath: relativePath(for: entryURL, rootURL: rootURL),
                            artefactType: rule.artefactType,
                            ruleID: rule.id,
                            ruleName: rule.name,
                            sizeBytes: fileSize
                        )
                    )
                }
            }
        }

        return (
            ScopeArtefactScanResult(
                scopeID: scope.id,
                scopeDisplayName: scope.displayName,
                scopePath: scope.path,
                scanStatus: .scanned,
                scannedDirectoryCount: scannedDirectoryCount,
                inspectedFileCount: inspectedFileCount,
                skippedSymbolicLinkCount: skippedSymbolicLinkCount,
                matchedArtefactCount: matchedArtefactCount,
                matchedBytes: matchedBytes,
                artefactSummaries: artefactBuckets
                    .map { key, value in
                        ArtefactTypeSummary(artefactType: key, count: value.count, totalBytes: value.bytes)
                    }
                    .sorted { lhs, rhs in
                        if lhs.count != rhs.count {
                            return lhs.count > rhs.count
                        }
                        return lhs.artefactType.rawValue < rhs.artefactType.rawValue
                    },
                sampleMatches: sampleMatches
            ),
            warnings
        )
    }

    private func matchingRule(forFilename filename: String, path: String) -> ArtefactRule? {
        rules.first { rule in
            switch rule.matchType {
            case .exactPath:
                return path == rule.matchValue
            case .filename:
                return filename == rule.matchValue
            case .metadataKey:
                return false
            case .regex:
                return filename.range(of: rule.matchValue, options: .regularExpression) != nil
            }
        }
    }

    private func relativePath(for fileURL: URL, rootURL: URL) -> String {
        let rootPath = rootURL.path
        let filePath = fileURL.path

        if filePath == rootPath {
            return "."
        }

        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if filePath.hasPrefix(prefix) {
            return String(filePath.dropFirst(prefix.count))
        }

        return fileURL.lastPathComponent
    }

    private func sortResults(lhs: ScopeArtefactScanResult, rhs: ScopeArtefactScanResult) -> Bool {
        if lhs.matchedArtefactCount != rhs.matchedArtefactCount {
            return lhs.matchedArtefactCount > rhs.matchedArtefactCount
        }

        return lhs.scopePath < rhs.scopePath
    }

    private func directoryEntryNames(atPath path: String) throws -> [String] {
        guard let directory = opendir(path) else {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errno),
                userInfo: [NSFilePathErrorKey: path]
            )
        }

        defer { closedir(directory) }

        var names: [String] = []

        while let entry = readdir(directory) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) {
                    String(cString: $0)
                }
            }

            if name == "." || name == ".." {
                continue
            }

            names.append(name)
        }

        return names
    }

    public static let defaultRules: [ArtefactRule] = [
        ArtefactRule(
            id: "icon-carriage-return-file",
            name: "Finder Icon carriage-return file",
            artefactType: .iconFile,
            matchType: .filename,
            matchValue: "Icon\r",
            confidence: .high,
            action: .audit
        ),
        ArtefactRule(
            id: "appledouble-sidecar",
            name: "AppleDouble sidecar",
            artefactType: .iconSidecar,
            matchType: .regex,
            matchValue: #"^\._"#,
            confidence: .medium,
            action: .audit
        )
    ]
}
