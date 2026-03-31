import Foundation
import DriveIconGuardShared

public struct ScopeEnforcementEngine {
    private let artefactScanner: ArtefactScanner
    private let remediationPlanner: ScopeRemediationPlanner

    public init(
        artefactScanner: ArtefactScanner = ArtefactScanner(),
        remediationPlanner: ScopeRemediationPlanner = ScopeRemediationPlanner()
    ) {
        self.artefactScanner = artefactScanner
        self.remediationPlanner = remediationPlanner
    }

    public func enforce(scopes: [DriveManagedScope]) -> [ScopeEnforcementEvent] {
        let enforceableScopes = scopes.filter {
            $0.supportStatus == .supported && $0.enforcementMode == .blockKnownArtefacts
        }
        guard !enforceableScopes.isEmpty else {
            return []
        }

        let summary = artefactScanner.scan(scopes: enforceableScopes)

        return summary.scopeResults.compactMap { scanResult in
            guard
                scanResult.scanStatus == .scanned,
                scanResult.matchedArtefactCount > 0,
                let scope = enforceableScopes.first(where: { $0.id == scanResult.scopeID })
            else {
                return nil
            }

            let applyResult = remediationPlanner.applyCleanup(for: scope)
            return ScopeEnforcementEvent(
                scope: scope,
                detectedArtefactCount: scanResult.matchedArtefactCount,
                detectedBytes: scanResult.matchedBytes,
                applyResult: applyResult
            )
        }
    }
}
