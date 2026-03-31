import Foundation
import DriveIconGuardIPC
import DriveIconGuardShared

public final class HelperProtectionService: @unchecked Sendable {
    private let policyEngine: HelperProtectionPolicyEngine
    private let subscriber: ProcessAttributedEventSubscriber
    private let queue: DispatchQueue

    private var scopes: [DriveManagedScope] = []
    private var evaluationHandler: (@Sendable (HelperProtectionEvaluation) -> Void)?
    private var isStarted = false

    public init(
        policyEngine: HelperProtectionPolicyEngine = HelperProtectionPolicyEngine(),
        subscriber: ProcessAttributedEventSubscriber = EndpointSecurityProcessAttributedEventSubscriber(),
        queue: DispatchQueue = DispatchQueue(label: "DriveIconGuard.HelperProtectionService")
    ) {
        self.policyEngine = policyEngine
        self.subscriber = subscriber
        self.queue = queue
    }

    deinit {
        stop()
    }

    public func start(evaluationHandler: @escaping @Sendable (HelperProtectionEvaluation) -> Void) {
        queue.sync {
            self.evaluationHandler = evaluationHandler
            guard !isStarted else {
                return
            }

            isStarted = true
            subscriber.start { [weak self] event in
                self?.queue.async {
                    self?.handle(event: event)
                }
            }
        }
    }

    public func stop() {
        queue.sync {
            guard isStarted else {
                return
            }

            isStarted = false
            subscriber.stop()
            evaluationHandler = nil
        }
    }

    public func updateScopes(_ scopes: [DriveManagedScope]) {
        queue.sync {
            self.scopes = scopes
        }
    }

    public func runtimeStatus() -> ProtectionEventSourceStatus {
        queue.sync {
            subscriber.status
        }
    }

    @discardableResult
    public func process(_ event: ProcessAttributedFileEvent) -> HelperProtectionEvaluation {
        queue.sync {
            processNow(event)
        }
    }

    private func handle(event: ProcessAttributedFileEvent) {
        _ = processNow(event)
    }

    private func processNow(_ event: ProcessAttributedFileEvent) -> HelperProtectionEvaluation {
        let evaluation = policyEngine.evaluate(event: event, scopes: scopes)
        evaluationHandler?(evaluation)
        return evaluation
    }
}
