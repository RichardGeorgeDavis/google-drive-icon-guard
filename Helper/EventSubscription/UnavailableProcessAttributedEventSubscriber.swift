import Foundation
import DriveIconGuardIPC

public final class UnavailableProcessAttributedEventSubscriber: ProcessAttributedEventSubscriber, @unchecked Sendable {
    public let status = ProtectionEventSourceStatus(
        state: .unavailable,
        detail: "No process-attributed event source is available. The helper can evaluate replayed events, but live Endpoint Security monitoring is not active."
    )

    public init() {}

    public func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void) {
        // Real process-attributed event capture is not wired yet.
    }

    public func stop() {}
}
