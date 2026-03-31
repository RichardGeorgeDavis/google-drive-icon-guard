import Foundation
import DriveIconGuardShared

public struct ScopeReviewPlanner {
    private let supportClassifier: ScopeSupportClassifier

    public init(supportClassifier: ScopeSupportClassifier = ScopeSupportClassifier()) {
        self.supportClassifier = supportClassifier
    }

    public func makePlan(
        for scope: DriveManagedScope,
        scanResult: ScopeArtefactScanResult?
    ) -> ScopeReviewPlan {
        let assessment = supportClassifier.assess(scope: scope)
        let artefactCount = scanResult?.matchedArtefactCount ?? 0
        let matchedBytes = scanResult?.matchedBytes ?? 0
        let coverageNote = coverageNote(for: scanResult)

        switch assessment.supportStatus {
        case .supported:
            if artefactCount > 0 {
                var notes = [
                    "Matched \(artefactCount) artefact(s) using \(ByteCountFormatter.string(fromByteCount: Int64(matchedBytes), countStyle: .file)).",
                    "Use Finder review first before introducing any destructive action."
                ]
                if let coverageNote {
                    notes.append(coverageNote)
                }

                return ScopeReviewPlan(
                    scopeID: scope.id,
                    priority: .ready,
                    headline: "Supported scope with remediation candidate",
                    recommendedAction: "Review the matched artefacts now. This scope is the strongest candidate for a future cleanup or protection flow once the helper boundary exists.",
                    rationale: assessment.rationale,
                    operatorNotes: notes
                )
            }

            var notes = [
                "No known icon artefacts were matched in the latest scan.",
                "This is the best place to validate future enforcement behavior."
            ]
            if let coverageNote {
                notes.append(coverageNote)
            }

            return ScopeReviewPlan(
                scopeID: scope.id,
                priority: .monitor,
                headline: "Supported scope currently clean",
                recommendedAction: "Keep scanning this scope. It is already in the safest current rollout bucket for future protection work.",
                rationale: assessment.rationale,
                operatorNotes: notes
            )

        case .auditOnly:
            if artefactCount > 0 {
                var notes = [
                    "Matched \(artefactCount) artefact(s) using \(ByteCountFormatter.string(fromByteCount: Int64(matchedBytes), countStyle: .file)).",
                    "This scope needs visibility and monitoring more than intervention right now."
                ]
                if let coverageNote {
                    notes.append(coverageNote)
                }

                return ScopeReviewPlan(
                    scopeID: scope.id,
                    priority: .attention,
                    headline: "Audit-only scope with active artefacts",
                    recommendedAction: "Review findings and keep this scope in audit mode. Do not plan cleanup here until support rules or helper coverage improve.",
                    rationale: assessment.rationale,
                    operatorNotes: notes
                )
            }

            var notes = [
                "No artefacts were matched in the latest scan.",
                "Audit-only status still blocks any stronger action path."
            ]
            if let coverageNote {
                notes.append(coverageNote)
            }

            return ScopeReviewPlan(
                scopeID: scope.id,
                priority: .monitor,
                headline: "Audit-only scope under observation",
                recommendedAction: "Continue auditing this scope over time and watch for new artefacts, path changes, or support-status changes.",
                rationale: assessment.rationale,
                operatorNotes: notes
            )

        case .unsupported:
            var notes = [
                "This scope does not meet the current rollout rules for safe protection."
            ]

            if artefactCount > 0 {
                notes.append("Matched \(artefactCount) artefact(s), but remediation should stay manual and cautious.")
            }
            if let coverageNote {
                notes.append(coverageNote)
            }

            return ScopeReviewPlan(
                scopeID: scope.id,
                priority: .blocked,
                headline: "Unsupported scope for protection work",
                recommendedAction: "Exclude this scope from remediation planning for now and keep any follow-up manual.",
                rationale: assessment.rationale,
                operatorNotes: notes
            )
        }
    }

    private func coverageNote(for scanResult: ScopeArtefactScanResult?) -> String? {
        guard let scanResult, scanResult.scanStatus == .scanned else {
            return nil
        }

        var message = "Recursive scan covered \(scanResult.scannedDirectoryCount) director"
        message += scanResult.scannedDirectoryCount == 1 ? "y" : "ies"
        message += " and inspected \(scanResult.inspectedFileCount) file"
        message += scanResult.inspectedFileCount == 1 ? "" : "s"

        if scanResult.skippedSymbolicLinkCount > 0 {
            message += "; skipped \(scanResult.skippedSymbolicLinkCount) symbolic link"
            message += scanResult.skippedSymbolicLinkCount == 1 ? "" : "s"
        }

        message += "."
        return message
    }
}
