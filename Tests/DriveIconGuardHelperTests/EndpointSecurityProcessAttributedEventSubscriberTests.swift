#if canImport(Testing)
import DriveIconGuardHelper
import DriveIconGuardIPC
import Foundation
import Testing

@Test
func endpointSecuritySubscriberReportsStructuredStatus() {
    let subscriber = EndpointSecurityProcessAttributedEventSubscriber()

    #expect(subscriber.status.state == .needsApproval || subscriber.status.state == .unavailable)
    #expect(subscriber.status.detail.isEmpty == false)

    subscriber.start { _ in }
    #expect(subscriber.status.state == .bundled || subscriber.status.state == .unavailable)
    #expect(subscriber.status.detail.isEmpty == false)
}

@Test
func endpointSecuritySubscriberStartDoesNotDispatchSyntheticPreflightEvent() {
    let subscriber = EndpointSecurityProcessAttributedEventSubscriber()
    let recorder = ProcessEventRecorder()

    subscriber.start { event in
        recorder.append(event)
    }

    #expect(recorder.count == 0)
}

#if os(macOS) && canImport(EndpointSecurity)
@Test
func endpointSecuritySubscriberMarksReadyAfterValidRawEventDispatch() {
    let subscriber = EndpointSecurityProcessAttributedEventSubscriber()
    let recorder = ProcessEventRecorder()
    subscriber.start { event in
        recorder.append(event)
    }

    subscriber.handleLiveRawEvent(makeRawEvent(targetPath: "/tmp/Icon\r"))

    #expect(subscriber.status.state == .ready)
    #expect(recorder.count == 1)
    #expect(recorder.first?.targetPath == "/tmp/Icon\r")
    #expect(recorder.first?.operation == .create)
}

@Test
func endpointSecuritySubscriberRejectsRawEventBeforeStart() {
    let subscriber = EndpointSecurityProcessAttributedEventSubscriber()

    subscriber.handleLiveRawEvent(makeRawEvent(targetPath: "/tmp/Icon\r"))

    #expect(subscriber.status.state == .error)
    #expect(subscriber.status.detail.contains("before subscriber event handler was set"))
}

@Test
func endpointSecuritySubscriberRejectsMalformedRawEvent() {
    let subscriber = EndpointSecurityProcessAttributedEventSubscriber()
    let recorder = ProcessEventRecorder()
    subscriber.start { event in
        recorder.append(event)
    }

    subscriber.handleLiveRawEvent(makeRawEvent(targetPath: "   "))

    #expect(subscriber.status.state == .error)
    #expect(subscriber.status.detail.contains("raw callback event conversion failed"))
    #expect(recorder.count == 0)
}

private func makeRawEvent(targetPath: String) -> EndpointSecurityRawCallbackEvent {
    EndpointSecurityRawCallbackEvent(
        operation: .create,
        targetPath: targetPath,
        process: EndpointSecurityProcessMetadata(
            pid: 42,
            executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
            displayName: "Google Drive",
            bundleID: "com.google.drivefs"
        )
    )
}
#endif

private final class ProcessEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [ProcessAttributedFileEvent] = []

    func append(_ event: ProcessAttributedFileEvent) {
        lock.lock()
        values.append(event)
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        let value = values.count
        lock.unlock()
        return value
    }

    var first: ProcessAttributedFileEvent? {
        lock.lock()
        let value = values.first
        lock.unlock()
        return value
    }
}
#elseif canImport(XCTest)
import DriveIconGuardHelper
import DriveIconGuardIPC
import Foundation
import XCTest

final class EndpointSecurityProcessAttributedEventSubscriberTests: XCTestCase {
    func testEndpointSecuritySubscriberReportsStructuredStatus() {
        let subscriber = EndpointSecurityProcessAttributedEventSubscriber()

        XCTAssertTrue(subscriber.status.state == .needsApproval || subscriber.status.state == .unavailable)
        XCTAssertFalse(subscriber.status.detail.isEmpty)

        subscriber.start { _ in }
        XCTAssertTrue(subscriber.status.state == .bundled || subscriber.status.state == .unavailable)
        XCTAssertFalse(subscriber.status.detail.isEmpty)
    }

    func testEndpointSecuritySubscriberStartDoesNotDispatchSyntheticPreflightEvent() {
        let subscriber = EndpointSecurityProcessAttributedEventSubscriber()
        let recorder = ProcessEventRecorder()

        subscriber.start { event in
            recorder.append(event)
        }

        XCTAssertEqual(recorder.count, 0)
    }

#if os(macOS) && canImport(EndpointSecurity)
    func testEndpointSecuritySubscriberMarksReadyAfterValidRawEventDispatch() {
        let subscriber = EndpointSecurityProcessAttributedEventSubscriber()
        let recorder = ProcessEventRecorder()
        subscriber.start { event in
            recorder.append(event)
        }

        subscriber.handleLiveRawEvent(makeRawEvent(targetPath: "/tmp/Icon\r"))

        XCTAssertEqual(subscriber.status.state, .ready)
        XCTAssertEqual(recorder.count, 1)
        XCTAssertEqual(recorder.first?.targetPath, "/tmp/Icon\r")
        XCTAssertEqual(recorder.first?.operation, .create)
    }

    func testEndpointSecuritySubscriberRejectsRawEventBeforeStart() {
        let subscriber = EndpointSecurityProcessAttributedEventSubscriber()

        subscriber.handleLiveRawEvent(makeRawEvent(targetPath: "/tmp/Icon\r"))

        XCTAssertEqual(subscriber.status.state, .error)
        XCTAssertTrue(subscriber.status.detail.contains("before subscriber event handler was set"))
    }

    func testEndpointSecuritySubscriberRejectsMalformedRawEvent() {
        let subscriber = EndpointSecurityProcessAttributedEventSubscriber()
        let recorder = ProcessEventRecorder()
        subscriber.start { event in
            recorder.append(event)
        }

        subscriber.handleLiveRawEvent(makeRawEvent(targetPath: "   "))

        XCTAssertEqual(subscriber.status.state, .error)
        XCTAssertTrue(subscriber.status.detail.contains("raw callback event conversion failed"))
        XCTAssertEqual(recorder.count, 0)
    }
#endif
}

#if os(macOS) && canImport(EndpointSecurity)
private func makeRawEvent(targetPath: String) -> EndpointSecurityRawCallbackEvent {
    EndpointSecurityRawCallbackEvent(
        operation: .create,
        targetPath: targetPath,
        process: EndpointSecurityProcessMetadata(
            pid: 42,
            executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
            displayName: "Google Drive",
            bundleID: "com.google.drivefs"
        )
    )
}
#endif

private final class ProcessEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [ProcessAttributedFileEvent] = []

    func append(_ event: ProcessAttributedFileEvent) {
        lock.lock()
        values.append(event)
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        let value = values.count
        lock.unlock()
        return value
    }

    var first: ProcessAttributedFileEvent? {
        lock.lock()
        let value = values.first
        lock.unlock()
        return value
    }
}
#endif
