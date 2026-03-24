import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation

@MainActor
final class ScopeInventoryViewModel: ObservableObject {
    @Published private(set) var report: ScopeInventoryReport?
    @Published private(set) var persistedPath: String?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: ScopeInventoryService

    init(service: ScopeInventoryService = ScopeInventoryService()) {
        self.service = service
    }

    func refresh() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let nextReport = service.generateReport()
                let persistenceResult = try service.persistReport(nextReport)

                report = nextReport
                persistedPath = persistenceResult.latestURL.path
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
