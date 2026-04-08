import DriveIconGuardIPC
import DriveIconGuardShared
import Foundation

public protocol ProtectionServiceRuntimeControlling: Sendable {
    func updateScopes(_ scopes: [DriveManagedScope])
    func start(evaluationHandler: @escaping @Sendable (HelperProtectionEvaluation) -> Void) throws
    func stop()
    func runtimeStatus() -> ProtectionEventSourceStatus
}

extension HelperProtectionService: ProtectionServiceRuntimeControlling {}
