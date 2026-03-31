import Foundation
import DriveIconGuardShared

public final class ScopeEnforcementMonitor: @unchecked Sendable {
    private let engine: ScopeEnforcementEngine
    private let queue: DispatchQueue
    private let interval: TimeInterval
    private let cooldown: TimeInterval

    private var timer: DispatchSourceTimer?
    private var trackedScopes: [DriveManagedScope] = []
    private var isEvaluating = false
    private var lastActionDatesByPath: [String: Date] = [:]
    private var eventHandler: (@Sendable ([ScopeEnforcementEvent]) -> Void)?

    public init(
        engine: ScopeEnforcementEngine = ScopeEnforcementEngine(),
        interval: TimeInterval = 3,
        cooldown: TimeInterval = 2,
        queue: DispatchQueue = DispatchQueue(label: "DriveIconGuard.ScopeEnforcementMonitor")
    ) {
        self.engine = engine
        self.interval = interval
        self.cooldown = cooldown
        self.queue = queue
    }

    deinit {
        stop()
    }

    public func start(eventHandler: @escaping @Sendable ([ScopeEnforcementEvent]) -> Void) {
        queue.async {
            self.eventHandler = eventHandler
            guard self.timer == nil else {
                return
            }

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + self.interval, repeating: self.interval)
            timer.setEventHandler { [weak self] in
                self?.evaluate()
            }
            self.timer = timer
            timer.resume()
        }
    }

    public func stop() {
        queue.async { [self] in
            self.timer?.setEventHandler {}
            self.timer?.cancel()
            self.timer = nil
            self.eventHandler = nil
        }
    }

    public func updateScopes(_ scopes: [DriveManagedScope]) {
        queue.async {
            self.trackedScopes = scopes
        }
    }

    public func evaluateNow() {
        queue.async {
            self.evaluate()
        }
    }

    private func evaluate() {
        guard !isEvaluating else {
            return
        }

        let now = Date()
        let eligibleScopes = trackedScopes.filter { scope in
            guard scope.supportStatus == .supported, scope.enforcementMode == .blockKnownArtefacts else {
                return false
            }

            if let lastActionDate = lastActionDatesByPath[scope.path] {
                return now.timeIntervalSince(lastActionDate) >= cooldown
            }

            return true
        }

        guard !eligibleScopes.isEmpty else {
            return
        }

        isEvaluating = true
        let events = engine.enforce(scopes: eligibleScopes)
        for event in events where event.applyResult.removedCount > 0 {
            lastActionDatesByPath[event.scope.path] = now
        }
        isEvaluating = false

        guard !events.isEmpty, let eventHandler else {
            return
        }

        eventHandler(events)
    }
}
