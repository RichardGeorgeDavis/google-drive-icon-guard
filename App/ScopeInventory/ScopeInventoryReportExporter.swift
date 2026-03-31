import Foundation
import DriveIconGuardShared

public struct ScopeInventoryReportExporter {
    private let reviewPlanner: ScopeReviewPlanner

    public init(reviewPlanner: ScopeReviewPlanner = ScopeReviewPlanner()) {
        self.reviewPlanner = reviewPlanner
    }

    public func markdownReport(for report: ScopeInventoryReport) -> String {
        markdownReport(for: report, scopes: report.scopes)
    }

    public func markdownReport(
        for report: ScopeInventoryReport,
        scopeID: UUID
    ) -> String? {
        guard let scope = report.scopes.first(where: { $0.id == scopeID }) else {
            return nil
        }

        return markdownReport(for: report, scopes: [scope])
    }

    private func markdownReport(for report: ScopeInventoryReport, scopes: [DriveManagedScope]) -> String {
        let scopeIDs = Set(scopes.map(\.id))
        let scopeResults = report.artefactInventory.scopeResults.filter { scopeIDs.contains($0.scopeID) }
        let scopedInventory = ArtefactInventorySummary(
            generatedAt: report.artefactInventory.generatedAt,
            scannedScopeCount: scopeResults.filter { $0.scanStatus == .scanned }.count,
            matchedScopeCount: scopeResults.filter { $0.matchedArtefactCount > 0 }.count,
            totalArtefactCount: scopeResults.reduce(0) { $0 + $1.matchedArtefactCount },
            totalBytes: scopeResults.reduce(0) { $0 + $1.matchedBytes },
            scopeResults: scopeResults,
            warnings: report.artefactInventory.warnings
        )
        let scopedReport = ScopeInventoryReport(
            generatedAt: report.generatedAt,
            configLocations: report.configLocations,
            scopes: scopes,
            warnings: report.warnings,
            artefactInventory: scopedInventory
        )

        var lines: [String] = []
        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file

        lines.append("# Google Drive Icon Guard Findings")
        lines.append("")
        lines.append("Generated: \(iso8601(scopedReport.generatedAt))")
        lines.append("")
        lines.append("## Summary")
        lines.append("")
        lines.append("- Scopes: \(scopedReport.scopes.count)")
        lines.append("- Supported: \(scopedReport.scopes.filter { $0.supportStatus == .supported }.count)")
        lines.append("- Audit Only: \(scopedReport.scopes.filter { $0.supportStatus == .auditOnly }.count)")
        lines.append("- Unsupported: \(scopedReport.scopes.filter { $0.supportStatus == .unsupported }.count)")
        lines.append("- Artefacts: \(scopedReport.artefactInventory.totalArtefactCount)")
        lines.append("- Disk impact: \(byteFormatter.string(fromByteCount: Int64(scopedReport.artefactInventory.totalBytes)))")
        lines.append("")

        if !combinedWarnings(for: scopedReport).isEmpty {
            lines.append("## Warnings")
            lines.append("")
            for warning in combinedWarnings(for: scopedReport) {
                lines.append("- **\(warning.code)**: \(warning.message)")
            }
            lines.append("")
        }

        lines.append("## Scope Review")
        lines.append("")

        for scope in scopedReport.scopes {
            let scanResult = scopedReport.artefactInventory.scopeResults.first(where: { $0.scopeID == scope.id })
            let reviewPlan = reviewPlanner.makePlan(for: scope, scanResult: scanResult)

            lines.append("### \(scope.displayName)")
            lines.append("")
            lines.append("- Path: `\(scope.path)`")
            lines.append("- Support: `\(scope.supportStatus.rawValue)`")
            lines.append("- Drive Mode: `\(scope.driveMode.rawValue)`")
            lines.append("- Scope Kind: `\(scope.scopeKind.rawValue)`")
            lines.append("- Source: `\(scope.source.rawValue)`")
            lines.append("- Review Priority: `\(reviewPlan.priority.rawValue)`")
            lines.append("- Recommended Action: \(reviewPlan.recommendedAction)")

            if let scanResult {
                lines.append("- Scan Status: `\(scanResult.scanStatus.rawValue)`")
                if scanResult.scanStatus == .scanned {
                    lines.append("- Coverage: \(scanResult.scannedDirectoryCount) director\(scanResult.scannedDirectoryCount == 1 ? "y" : "ies"), \(scanResult.inspectedFileCount) file\(scanResult.inspectedFileCount == 1 ? "" : "s") inspected, \(scanResult.skippedSymbolicLinkCount) symbolic link\(scanResult.skippedSymbolicLinkCount == 1 ? "" : "s") skipped")
                }
                lines.append("- Artefacts: \(scanResult.matchedArtefactCount)")
                lines.append("- Disk impact: \(byteFormatter.string(fromByteCount: Int64(scanResult.matchedBytes)))")

                if !scanResult.artefactSummaries.isEmpty {
                    lines.append("- Breakdown:")
                    for summary in scanResult.artefactSummaries {
                        lines.append("  - `\(summary.artefactType.rawValue)`: \(summary.count) using \(byteFormatter.string(fromByteCount: Int64(summary.totalBytes)))")
                    }
                }

                if !scanResult.sampleMatches.isEmpty {
                    lines.append("- Sample Matches:")
                    for sample in scanResult.sampleMatches.prefix(5) {
                        lines.append("  - `\(sample.relativePath)` (`\(sample.ruleName)`, \(byteFormatter.string(fromByteCount: Int64(sample.sizeBytes))))")
                    }
                }
            }

            if !reviewPlan.rationale.isEmpty {
                lines.append("- Rationale:")
                for reason in reviewPlan.rationale {
                    lines.append("  - \(reason)")
                }
            }

            if !reviewPlan.operatorNotes.isEmpty {
                lines.append("- Operator Notes:")
                for note in reviewPlan.operatorNotes {
                    lines.append("  - \(note)")
                }
            }

            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func combinedWarnings(for report: ScopeInventoryReport) -> [DiscoveryWarning] {
        report.warnings + report.artefactInventory.warnings
    }

    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
