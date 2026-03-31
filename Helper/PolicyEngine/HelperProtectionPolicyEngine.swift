import Foundation
import DriveIconGuardIPC
import DriveIconGuardShared

public struct HelperProtectionPolicyEngine {
    private let processClassifier: GoogleDriveProcessClassifier
    private let artefactClassifier: AttributedArtefactClassifier
    private let circuitBreaker: ProtectionCircuitBreaker

    public init(
        processClassifier: GoogleDriveProcessClassifier = GoogleDriveProcessClassifier(),
        artefactClassifier: AttributedArtefactClassifier = AttributedArtefactClassifier(),
        circuitBreaker: ProtectionCircuitBreaker = ProtectionCircuitBreaker()
    ) {
        self.processClassifier = processClassifier
        self.artefactClassifier = artefactClassifier
        self.circuitBreaker = circuitBreaker
    }

    public func evaluate(
        event: ProcessAttributedFileEvent,
        scopes: [DriveManagedScope]
    ) -> HelperProtectionEvaluation {
        guard let scope = matchingScope(for: event.targetPath, scopes: scopes) else {
            return HelperProtectionEvaluation(
                event: event,
                decision: .allow,
                reason: "Target path is outside the discovered Drive-managed scopes."
            )
        }

        guard scope.supportStatus == .supported else {
            return HelperProtectionEvaluation(
                event: event,
                matchedScopeID: scope.id,
                decision: .auditOnly,
                reason: "Matched scope is not in a supported protection bucket."
            )
        }

        guard processClassifier.isGoogleDriveRelated(event.processSignature) else {
            return HelperProtectionEvaluation(
                event: event,
                matchedScopeID: scope.id,
                decision: .allow,
                reason: "Writer process is not classified as Google Drive."
            )
        }

        guard let artefactType = artefactClassifier.matchedArtefact(for: event) else {
            return HelperProtectionEvaluation(
                event: event,
                matchedScopeID: scope.id,
                decision: .allow,
                reason: "Target file does not match a high-confidence icon artefact rule."
            )
        }

        switch scope.enforcementMode {
        case .off:
            return HelperProtectionEvaluation(
                event: event,
                matchedScopeID: scope.id,
                matchedArtefactType: artefactType,
                decision: .allow,
                reason: "Protection is disabled for this scope."
            )

        case .auditOnly:
            return HelperProtectionEvaluation(
                event: event,
                matchedScopeID: scope.id,
                matchedArtefactType: artefactType,
                decision: .auditOnly,
                reason: "Scope is configured for audit-only handling."
            )

        case .blockKnownArtefacts:
            let key = "\(event.processSignature.executablePath)|\(event.targetPath)|\(artefactType.rawValue)"
            if circuitBreaker.isStorm(key: key, now: event.timestamp) {
                return HelperProtectionEvaluation(
                    event: event,
                    matchedScopeID: scope.id,
                    matchedArtefactType: artefactType,
                    decision: .stormSuppressed,
                    reason: "Repeated matching events triggered storm suppression."
                )
            }

            return HelperProtectionEvaluation(
                event: event,
                matchedScopeID: scope.id,
                matchedArtefactType: artefactType,
                decision: .deny,
                reason: "Google Drive writer and high-confidence artefact matched in a protected scope."
            )
        }
    }

    private func matchingScope(for path: String, scopes: [DriveManagedScope]) -> DriveManagedScope? {
        scopes
            .filter { isPath(path, inside: $0.path) }
            .sorted { $0.path.count > $1.path.count }
            .first
    }

    private func isPath(_ candidatePath: String, inside rootPath: String) -> Bool {
        if candidatePath == rootPath {
            return true
        }

        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return candidatePath.hasPrefix(prefix)
    }
}
