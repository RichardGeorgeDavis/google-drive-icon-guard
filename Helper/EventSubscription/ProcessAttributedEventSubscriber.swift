import Foundation
import DriveIconGuardIPC

public protocol ProcessAttributedEventSubscriber: AnyObject, Sendable {
    func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void)
    func stop()
}
