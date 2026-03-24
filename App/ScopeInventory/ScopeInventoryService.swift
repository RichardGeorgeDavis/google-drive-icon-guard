import Foundation

public struct ScopeInventoryService {
    private let probe: GoogleDriveProbe
    private let persistence: ScopeInventoryPersistence

    public init(
        probe: GoogleDriveProbe = GoogleDriveProbe(),
        persistence: ScopeInventoryPersistence = ScopeInventoryPersistence()
    ) {
        self.probe = probe
        self.persistence = persistence
    }

    public func generateReport() -> ScopeInventoryReport {
        probe.discover()
    }

    @discardableResult
    public func persistReport(
        _ report: ScopeInventoryReport,
        projectRoot: String = FileManager.default.currentDirectoryPath
    ) throws -> ScopeInventoryPersistenceResult {
        try persistence.persist(report, projectRoot: projectRoot)
    }
}
