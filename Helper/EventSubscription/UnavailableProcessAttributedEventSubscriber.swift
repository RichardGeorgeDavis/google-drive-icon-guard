import Foundation
import DriveIconGuardIPC

public final class UnavailableProcessAttributedEventSubscriber: ProcessAttributedEventSubscriber, @unchecked Sendable {
    public init() {}

    public func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void) {
        // Real process-attributed event capture is not wired yet.
    }

    public func stop() {}
}
