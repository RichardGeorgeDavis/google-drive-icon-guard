import Foundation
import DriveIconGuardShared

public struct ScopeInventoryService {
    private let probe: GoogleDriveProbe
    private let persistence: ScopeInventoryPersistence
    private let artefactScanner: ArtefactScanner
    private let reviewPlanner: ScopeReviewPlanner
    private let reportExporter: ScopeInventoryReportExporter
    private let remediationPlanner: ScopeRemediationPlanner

    public init(
        probe: GoogleDriveProbe = GoogleDriveProbe(),
        persistence: ScopeInventoryPersistence = ScopeInventoryPersistence(),
        artefactScanner: ArtefactScanner = ArtefactScanner(),
        reviewPlanner: ScopeReviewPlanner = ScopeReviewPlanner(),
        reportExporter: ScopeInventoryReportExporter = ScopeInventoryReportExporter(),
        remediationPlanner: ScopeRemediationPlanner = ScopeRemediationPlanner()
    ) {
        self.probe = probe
        self.persistence = persistence
        self.artefactScanner = artefactScanner
        self.reviewPlanner = reviewPlanner
        self.reportExporter = reportExporter
        self.remediationPlanner = remediationPlanner
    }

    public func generateReport() -> ScopeInventoryReport {
        var report = probe.discover()
        report.artefactInventory = artefactScanner.scan(
            scopes: report.scopes,
            generatedAt: report.generatedAt
        )
        return report
    }

    public func loadRecentSnapshots(
        limit: Int = 5,
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws -> [PersistedScopeInventorySnapshot] {
        try persistence.loadRecentSnapshots(limit: limit, projectRoot: projectRoot)
    }

    public func compare(
        current: ScopeInventoryReport,
        previous: ScopeInventoryReport
    ) -> ScopeInventoryHistoryComparison {
        persistence.compare(current: current, previous: previous)
    }

    public func reviewPlan(
        for scope: DriveManagedScope,
        report: ScopeInventoryReport
    ) -> ScopeReviewPlan {
        let scanResult = report.artefactInventory.scopeResults.first(where: { $0.scopeID == scope.id })
        return reviewPlanner.makePlan(for: scope, scanResult: scanResult)
    }

    public func exportMarkdownReport(for report: ScopeInventoryReport) -> String {
        reportExporter.markdownReport(for: report)
    }

    public func exportMarkdownReport(
        for report: ScopeInventoryReport,
        scopeID: UUID
    ) -> String? {
        reportExporter.markdownReport(for: report, scopeID: scopeID)
    }

    public func dryRunRemediationPreview(for scope: DriveManagedScope) -> ScopeRemediationPreview {
        remediationPlanner.dryRunPreview(for: scope)
    }

    public func dryRunRemediationScript(for scope: DriveManagedScope) -> String {
        remediationPlanner.dryRunShellScript(for: scope)
    }

    public func applyCleanup(for scope: DriveManagedScope) -> ScopeRemediationApplyResult {
        remediationPlanner.applyCleanup(for: scope)
    }

    public func loadActivityLog(
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws -> PersistedActivityLog {
        try persistence.loadActivityLog(projectRoot: projectRoot)
    }

    public func persistActivityLog(
        _ activityLog: PersistedActivityLog,
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws {
        try persistence.persistActivityLog(activityLog, projectRoot: projectRoot)
    }

    public func storageRootPath(
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) -> String {
        persistence.storageRootURL(projectRoot: projectRoot).path
    }

    public func clearStoredData(
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws {
        try persistence.clearStoredData(projectRoot: projectRoot)
    }

    @discardableResult
    public func persistReport(
        _ report: ScopeInventoryReport,
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws -> ScopeInventoryPersistenceResult {
        try persistence.persist(report, projectRoot: projectRoot)
    }
}
