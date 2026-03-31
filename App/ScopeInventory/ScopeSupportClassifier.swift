import Foundation
import DriveIconGuardShared

public struct ScopeSupportClassifier {
    public init() {}

    public func assess(scope: DriveManagedScope) -> ScopeAssessment {
        if scope.driveMode == .stream {
            return ScopeAssessment(
                supportStatus: .auditOnly,
                rationale: ["Stream and File Provider scopes start in audit-only mode."]
            )
        }

        if scope.scopeKind == .photosLibrary {
            return ScopeAssessment(
                supportStatus: .auditOnly,
                rationale: ["Photos-related scopes are detectable but higher risk, so they stay audit-only."]
            )
        }

        if scope.volumeKind == .systemManaged {
            return ScopeAssessment(
                supportStatus: .auditOnly,
                rationale: ["System-managed storage requires audit-first treatment."]
            )
        }

        if scope.volumeKind == .network || scope.fileSystemKind == .smb {
            return ScopeAssessment(
                supportStatus: .auditOnly,
                rationale: ["Network-backed scopes are audit-only until filesystem behavior is validated."]
            )
        }

        if scope.volumeKind == .removable {
            return ScopeAssessment(
                supportStatus: .auditOnly,
                rationale: ["Removable volumes stay audit-only until disconnect and remount behavior is validated."]
            )
        }

        if scope.fileSystemKind == .unknown {
            return ScopeAssessment(
                supportStatus: .unsupported,
                rationale: ["Unknown filesystem behavior is too risky for enforcement."]
            )
        }

        if scope.fileSystemKind == .exfat {
            return ScopeAssessment(
                supportStatus: .auditOnly,
                rationale: ["Non-native filesystems should start audit-only before any protection rollout."]
            )
        }

        let usesNativeFilesystem = scope.fileSystemKind == .apfs || scope.fileSystemKind == .hfsplus
        let isProtectableMode = scope.driveMode == .mirror || (scope.driveMode == .backup && scope.scopeKind == .backupFolder)
        let isLocalVolume = scope.volumeKind == .internalVolume || scope.volumeKind == .external

        if usesNativeFilesystem && isProtectableMode && isLocalVolume {
            return ScopeAssessment(
                supportStatus: .supported,
                rationale: ["Local mirror or backup scope on a native filesystem is the safest starting point."]
            )
        }

        return ScopeAssessment(
            supportStatus: .unsupported,
            rationale: ["This scope does not yet meet the current rollout rules for safe protection."]
        )
    }

    public func applyingAssessment(to scope: DriveManagedScope) -> DriveManagedScope {
        var updatedScope = scope
        let assessment = assess(scope: scope)
        updatedScope.supportStatus = assessment.supportStatus
        switch assessment.supportStatus {
        case .supported:
            updatedScope.enforcementMode = .auditOnly
        case .auditOnly:
            updatedScope.enforcementMode = .auditOnly
        case .unsupported:
            updatedScope.enforcementMode = .off
        }
        return updatedScope
    }
}
