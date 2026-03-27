import Foundation

public struct ScopeInventoryService {
    private let probe: GoogleDriveProbe
    private let persistence: ScopeInventoryPersistence
    private let artefactScanner: ArtefactScanner

    public init(
        probe: GoogleDriveProbe = GoogleDriveProbe(),
        persistence: ScopeInventoryPersistence = ScopeInventoryPersistence(),
        artefactScanner: ArtefactScanner = ArtefactScanner()
    ) {
        self.probe = probe
        self.persistence = persistence
        self.artefactScanner = artefactScanner
    }

    public func generateReport() -> ScopeInventoryReport {
        var report = probe.discover()
        report.artefactInventory = artefactScanner.scan(
            scopes: report.scopes,
            generatedAt: report.generatedAt
        )
        return report
    }

    @discardableResult
    public func persistReport(
        _ report: ScopeInventoryReport,
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws -> ScopeInventoryPersistenceResult {
        try persistence.persist(report, projectRoot: projectRoot)
    }
}
