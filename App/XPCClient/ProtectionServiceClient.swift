import Foundation
import DriveIconGuardIPC
import DriveIconGuardShared

@MainActor
public protocol ProtectionServiceClient: AnyObject {
    var status: ProtectionServiceStatusSnapshot { get }
    var helperExecutablePath: String? { get }

    func start()
    func stop()
    func updateConfiguration(_ configuration: ProtectionServiceConfiguration)
    func evaluateNow()
    func setEventHandler(_ handler: @escaping @Sendable ([ProtectionServiceEventPayload]) -> Void)
}
