import Foundation
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared

public final class EndpointSecurityRuntimeCoordinator: @unchecked Sendable {
    private let subscriber: EndpointSecurityProcessAttributedEventSubscriber
    private let helperService: HelperProtectionService
    private let liveMonitoringSession: EndpointSecurityLiveMonitoringSession

    public init(
        policyEngine: HelperProtectionPolicyEngine = HelperProtectionPolicyEngine(),
        subscriber: EndpointSecurityProcessAttributedEventSubscriber = EndpointSecurityProcessAttributedEventSubscriber(),
        liveMonitoringSession: EndpointSecurityLiveMonitoringSession = SystemEndpointSecurityLiveMonitoringSession()
    ) {
        self.subscriber = subscriber
        self.liveMonitoringSession = liveMonitoringSession
        self.helperService = HelperProtectionService(
            policyEngine: policyEngine,
            subscriber: subscriber
        )
    }

    public func updateScopes(_ scopes: [DriveManagedScope]) {
        helperService.updateScopes(scopes)
    }

    public func start(
        evaluationHandler: @escaping @Sendable (HelperProtectionEvaluation) -> Void
    ) throws {
        helperService.start(evaluationHandler: evaluationHandler)

        do {
            try liveMonitoringSession.start(with: subscriber)
        } catch {
            helperService.stop()
            subscriber.markLiveMonitoringFailed(detail: error.localizedDescription)
            throw error
        }
    }

    public func stop() {
        liveMonitoringSession.stop()
        helperService.stop()
    }

    public func runtimeStatus() -> ProtectionEventSourceStatus {
        helperService.runtimeStatus()
    }

    @discardableResult
    public func process(_ event: ProcessAttributedFileEvent) -> HelperProtectionEvaluation {
        helperService.process(event)
    }
}
