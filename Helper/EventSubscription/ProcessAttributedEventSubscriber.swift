import Foundation
import DriveIconGuardIPC

public protocol ProcessAttributedEventSubscriber: AnyObject, Sendable {
    var status: ProtectionEventSourceStatus { get }

    func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void)
    func stop()
}
