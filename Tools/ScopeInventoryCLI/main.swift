import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation

let service = ScopeInventoryService()
let report = service.generateReport()

do {
    let persistenceResult = try service.persistReport(report)
    let data = try PrettyJSONEncoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
    FileHandle.standardError.write(Data("Persisted latest scope inventory to \(persistenceResult.latestURL.path)\n".utf8))
    FileHandle.standardError.write(Data("Persisted history snapshot to \(persistenceResult.historyURL.path)\n".utf8))
} catch {
    FileHandle.standardError.write(Data("Failed to encode scope inventory report: \(error)\n".utf8))
    exit(1)
}
