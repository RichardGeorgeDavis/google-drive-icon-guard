import DriveIconGuardShared
import Darwin
import Foundation

public struct ScopeRemediationPlanner {
    private let fileManager: FileManager
    private let rules: [ArtefactRule]
    private let previewLimit: Int

    public init(
        fileManager: FileManager = .default,
        rules: [ArtefactRule] = ArtefactScanner.defaultRules,
        previewLimit: Int = 50
    ) {
        self.fileManager = fileManager
        self.rules = rules
        self.previewLimit = max(1, previewLimit)
    }

    public func dryRunPreview(for scope: DriveManagedScope) -> ScopeRemediationPreview {
        guard scope.supportStatus == .supported else {
            return ScopeRemediationPreview(
                scopeID: scope.id,
                scopeDisplayName: scope.displayName,
                scopePath: scope.path,
                status: .unavailable,
                recommendedAction: "Dry-run remediation is only available for supported scopes. Keep this scope in review mode for now."
            )
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: scope.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return ScopeRemediationPreview(
                scopeID: scope.id,
                scopeDisplayName: scope.displayName,
                scopePath: scope.path,
                status: .unreadable,
                recommendedAction: "The scope path is unavailable, so dry-run remediation could not inspect candidate files.",
                warnings: [
                    FileAccessGuidance.warning(
                        operationCode: "remediation_scope_missing",
                        path: scope.path,
                        error: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT)),
                        genericMessage: "Dry-run remediation could not find the scope path: \(scope.path)"
                    )
                ]
            )
        }

        let enumeration = enumerateCandidates(for: scope)

        if enumeration.totalCount == 0 {
            return ScopeRemediationPreview(
                scopeID: scope.id,
                scopeDisplayName: scope.displayName,
                scopePath: scope.path,
                status: .noCandidates,
                recommendedAction: "No cleanup candidates were found in this supported scope. Keep monitoring rather than planning remediation.",
                warnings: enumeration.warnings
            )
        }

        return ScopeRemediationPreview(
            scopeID: scope.id,
            scopeDisplayName: scope.displayName,
            scopePath: scope.path,
            status: .ready,
            recommendedAction: "Review this dry-run candidate list before any future cleanup action. This preview does not modify the filesystem.",
            totalCandidateCount: enumeration.totalCount,
            totalBytes: enumeration.totalBytes,
            candidates: enumeration.previewCandidates,
            previewTruncated: enumeration.previewTruncated,
            warnings: enumeration.warnings
        )
    }

    public func dryRunShellScript(for scope: DriveManagedScope) -> String {
        let preview = dryRunPreview(for: scope)
        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file

        var lines: [String] = [
            "#!/bin/zsh",
            "set -euo pipefail",
            "",
            "# Dry-run cleanup preview for \(scope.displayName)",
            "# Scope path: \(scope.path)",
            "# Status: \(preview.status.rawValue)",
            "# Candidates: \(preview.totalCandidateCount)",
            "# Disk impact: \(byteFormatter.string(fromByteCount: Int64(preview.totalBytes)))",
            ""
        ]

        if preview.status != .ready {
            lines.append("echo \"Dry-run cleanup is not available: \(preview.recommendedAction.replacingOccurrences(of: "\"", with: "\\\""))\"")
            return lines.joined(separator: "\n")
        }

        let enumeration = enumerateCandidates(for: scope)
        lines.append("echo \"Dry-run only. No files will be removed.\"")
        lines.append("")

        for candidate in enumeration.allCandidates {
            let escapedPath = shellEscape(candidate.path)
            lines.append("printf 'Would remove: %s\\n' \(escapedPath)")
        }

        return lines.joined(separator: "\n")
    }

    public func applyCleanup(for scope: DriveManagedScope) -> ScopeRemediationApplyResult {
        guard scope.supportStatus == .supported else {
            return ScopeRemediationApplyResult(
                scopeID: scope.id,
                scopeDisplayName: scope.displayName,
                scopePath: scope.path,
                status: .unavailable,
                message: "Cleanup is only available for supported scopes. Keep this scope in review mode for now."
            )
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: scope.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return ScopeRemediationApplyResult(
                scopeID: scope.id,
                scopeDisplayName: scope.displayName,
                scopePath: scope.path,
                status: .unreadable,
                message: "The scope path is unavailable, so cleanup could not remove candidate files.",
                warnings: [
                    FileAccessGuidance.warning(
                        operationCode: "remediation_scope_missing",
                        path: scope.path,
                        error: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT)),
                        genericMessage: "Cleanup could not find the scope path: \(scope.path)"
                    )
                ]
            )
        }

        let enumeration = enumerateCandidates(for: scope)
        if enumeration.totalCount == 0 {
            return ScopeRemediationApplyResult(
                scopeID: scope.id,
                scopeDisplayName: scope.displayName,
                scopePath: scope.path,
                status: .noCandidates,
                message: "No cleanup candidates were found in this supported scope.",
                warnings: enumeration.warnings
            )
        }

        var warnings = enumeration.warnings
        var removedCount = 0
        var removedBytes = 0

        for candidate in enumeration.allCandidates {
            do {
                try fileManager.removeItem(atPath: candidate.path)
                removedCount += 1
                removedBytes += candidate.sizeBytes
            } catch {
                warnings.append(
                    FileAccessGuidance.warning(
                        operationCode: "remediation_remove_failed",
                        path: candidate.path,
                        error: error,
                        genericMessage: "Cleanup could not remove \(candidate.path): \(error.localizedDescription)"
                    )
                )
            }
        }

        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file

        if warnings.isEmpty {
            return ScopeRemediationApplyResult(
                scopeID: scope.id,
                scopeDisplayName: scope.displayName,
                scopePath: scope.path,
                status: .applied,
                message: "Removed \(removedCount) artefact(s) using \(byteFormatter.string(fromByteCount: Int64(removedBytes))).",
                removedCount: removedCount,
                removedBytes: removedBytes
            )
        }

        return ScopeRemediationApplyResult(
            scopeID: scope.id,
            scopeDisplayName: scope.displayName,
            scopePath: scope.path,
            status: .partialFailure,
            message: "Removed \(removedCount) artefact(s), but \(warnings.count) cleanup warning(s) were recorded.",
            removedCount: removedCount,
            removedBytes: removedBytes,
            warnings: warnings
        )
    }

    private func enumerateCandidates(for scope: DriveManagedScope) -> (
        allCandidates: [RemediationCandidate],
        previewCandidates: [RemediationCandidate],
        totalCount: Int,
        totalBytes: Int,
        previewTruncated: Bool,
        warnings: [DiscoveryWarning]
    ) {
        let rootURL = URL(fileURLWithPath: scope.path, isDirectory: true)
        var warnings: [DiscoveryWarning] = []
        var allCandidates: [RemediationCandidate] = []
        var previewCandidates: [RemediationCandidate] = []
        var totalBytes = 0
        var directoriesToScan = [rootURL]

        while let directoryURL = directoriesToScan.popLast() {
            let entryNames: [String]

            do {
                entryNames = try directoryEntryNames(atPath: directoryURL.path)
            } catch {
                warnings.append(
                    FileAccessGuidance.warning(
                        operationCode: "remediation_entry_unreadable",
                        path: directoryURL.path,
                        error: error,
                        genericMessage: "Dry-run remediation could not read \(directoryURL.path): \(error.localizedDescription)"
                    )
                )
                continue
            }

            let entries = entryNames.map { directoryURL.appendingPathComponent($0) }

            for entryURL in entries {
                let resourceValues: URLResourceValues

                do {
                    resourceValues = try entryURL.resourceValues(forKeys: FileFootprint.resourceKeys)
                } catch {
                    warnings.append(
                        FileAccessGuidance.warning(
                            operationCode: "remediation_metadata_unreadable",
                            path: entryURL.path,
                            error: error,
                            genericMessage: "Dry-run remediation could not read metadata for \(entryURL.path): \(error.localizedDescription)"
                        )
                    )
                    continue
                }

                if resourceValues.isSymbolicLink == true {
                    continue
                }

                if resourceValues.isDirectory == true {
                    directoriesToScan.append(entryURL)
                    continue
                }

                guard resourceValues.isRegularFile == true else {
                    continue
                }

                let filename = resourceValues.name ?? entryURL.lastPathComponent
                guard let rule = matchingRule(forFilename: filename, path: entryURL.path) else {
                    continue
                }

                let size = FileFootprint.bytes(for: resourceValues)
                let candidate = RemediationCandidate(
                    path: entryURL.path,
                    relativePath: relativePath(for: entryURL, rootURL: rootURL),
                    artefactType: rule.artefactType,
                    sizeBytes: size
                )

                allCandidates.append(candidate)
                totalBytes += size

                if previewCandidates.count < previewLimit {
                    previewCandidates.append(candidate)
                }
            }
        }

        return (
            allCandidates.sorted(by: { $0.path < $1.path }),
            previewCandidates.sorted(by: { $0.path < $1.path }),
            allCandidates.count,
            totalBytes,
            allCandidates.count > previewCandidates.count,
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

        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if filePath.hasPrefix(prefix) {
            return String(filePath.dropFirst(prefix.count))
        }

        return fileURL.lastPathComponent
    }

    private func directoryEntryNames(atPath path: String) throws -> [String] {
        guard let directory = opendir(path) else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: path])
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

    private func shellEscape(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
