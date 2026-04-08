import Foundation
import DriveIconGuardShared

public final class ScopeEnforcementMonitor: @unchecked Sendable {
    private static let queueSpecificKey = DispatchSpecificKey<UInt8>()
    private let engine: ScopeEnforcementEngine
    private let queue: DispatchQueue
    private let interval: TimeInterval
    private let cooldown: TimeInterval
    private let maxIntervalMultiplier = 8.0
    private let jitterFactor = 0.15

    private var timer: DispatchSourceTimer?
    private var trackedScopes: [DriveManagedScope] = []
    private var isEvaluating = false
    private var isStarted = false
    private var lastActionDatesByPath: [String: Date] = [:]
    private var eventHandler: (@Sendable ([ScopeEnforcementEvent]) -> Void)?
    private var currentInterval: TimeInterval

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
        self.currentInterval = interval
        self.queue.setSpecific(key: Self.queueSpecificKey, value: 1)
    }

    deinit {
        stop()
    }

    public func start(eventHandler: @escaping @Sendable ([ScopeEnforcementEvent]) -> Void) {
        queue.async {
            self.isStarted = true
            self.eventHandler = eventHandler
            guard self.timer == nil else {
                return
            }

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + self.interval)
            timer.setEventHandler { [weak self] in
                self?.evaluate()
            }
            self.timer = timer
            timer.resume()
        }
    }

    public func stop() {
        if DispatchQueue.getSpecific(key: Self.queueSpecificKey) != nil {
            stopNow()
            return
        }

        queue.sync {
            stopNow()
        }
    }

    public func updateScopes(_ scopes: [DriveManagedScope]) {
        queue.async {
            let previousPaths = Set(self.trackedScopes.map(\.path))
            self.trackedScopes = scopes
            guard self.isStarted else {
                return
            }
            let nextPaths = Set(scopes.map(\.path))
            if previousPaths != nextPaths {
                self.currentInterval = self.interval
                self.evaluate()
            }
        }
    }

    public func evaluateNow() {
        queue.async {
            guard self.isStarted else {
                return
            }
            self.evaluate()
        }
    }

    private func evaluate() {
        guard isStarted, !isEvaluating else {
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
            advanceSchedule(didDetectEvents: false)
            return
        }

        isEvaluating = true
        let events = engine.enforce(scopes: eligibleScopes)
        for event in events where event.applyResult.removedCount > 0 {
            lastActionDatesByPath[event.scope.path] = now
        }
        isEvaluating = false
        advanceSchedule(didDetectEvents: !events.isEmpty)

        guard !events.isEmpty, let eventHandler else {
            return
        }

        eventHandler(events)
    }

    private func advanceSchedule(didDetectEvents: Bool) {
        guard timer != nil else {
            return
        }

        if didDetectEvents {
            currentInterval = interval
        } else {
            currentInterval = min(currentInterval * 2, interval * maxIntervalMultiplier)
        }

        let jitter = currentInterval * jitterFactor
        let randomizedJitter = Double.random(in: -jitter...jitter)
        let delay = max(interval, currentInterval + randomizedJitter)
        timer?.schedule(deadline: .now() + delay)
    }

    private func stopNow() {
        isStarted = false
        trackedScopes = []
        lastActionDatesByPath = [:]
        isEvaluating = false
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
        eventHandler = nil
        currentInterval = interval
    }
}
