import Foundation
import DriveIconGuardIPC

public final class ReplayProcessAttributedEventSubscriber: ProcessAttributedEventSubscriber, @unchecked Sendable {
    private let events: [ProcessAttributedFileEvent]
    private let queue: DispatchQueue
    private let completionGroup = DispatchGroup()

    private var hasStarted = false
    private var isStopped = false

    public init(
        events: [ProcessAttributedFileEvent],
        queue: DispatchQueue = DispatchQueue(label: "DriveIconGuard.ReplayProcessAttributedEventSubscriber")
    ) {
        self.events = events
        self.queue = queue
    }

    public convenience init(
        fileURL: URL,
        loader: ReplayProcessAttributedEventLoader = ReplayProcessAttributedEventLoader(),
        queue: DispatchQueue = DispatchQueue(label: "DriveIconGuard.ReplayProcessAttributedEventSubscriber")
    ) throws {
        try self.init(events: loader.load(from: fileURL), queue: queue)
    }

    public func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void) {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        isStopped = false
        completionGroup.enter()

        queue.async { [events] in
            defer { self.completionGroup.leave() }

            for event in events {
                if self.isStopped {
                    break
                }

                eventHandler(event)
            }
        }
    }

    public func stop() {
        isStopped = true
    }

    @discardableResult
    public func waitUntilFinished(timeout: TimeInterval = 5.0) -> Bool {
        completionGroup.wait(timeout: .now() + timeout) == .success
    }
}
