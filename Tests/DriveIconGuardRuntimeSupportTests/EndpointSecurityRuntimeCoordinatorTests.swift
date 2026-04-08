#if canImport(Testing)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardRuntimeSupport
import DriveIconGuardShared
import Foundation
import Testing

@Test
func runtimeCoordinatorMarksReadyWhenLiveSessionStarts() throws {
    let session = FakeLiveMonitoringSession()
    session.onStart = { subscriber in
        subscriber.markLiveMonitoringReady(detail: "Subscribed for runtime-coordinator test.")
    }

    let coordinator = EndpointSecurityRuntimeCoordinator(liveMonitoringSession: session)
    try coordinator.start { _ in }

    #expect(coordinator.runtimeStatus().state == .ready)
    #expect(session.startCallCount == 1)

    coordinator.stop()
    #expect(session.stopCallCount == 1)
    #expect(coordinator.runtimeStatus().state == .bundled || coordinator.runtimeStatus().state == .unavailable)
}

@Test
func runtimeCoordinatorForwardsLiveEventIntoPolicyEvaluation() throws {
    let session = FakeLiveMonitoringSession()
    let scope = makeProtectedScope()
    let recorder = EvaluationRecorder()
    session.onStart = { subscriber in
        subscriber.markLiveMonitoringReady(detail: "Subscribed for runtime-coordinator test.")
        subscriber.handleLiveRawEvent(
            EndpointSecurityRawCallbackEvent(
                operation: .create,
                targetPath: "/Volumes/Work/Google Drive/Folder/Icon\r",
                process: EndpointSecurityProcessMetadata(
                    pid: 77,
                    executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                    displayName: "Google Drive",
                    bundleID: "com.google.drivefs"
                )
            )
        )
    }

    let coordinator = EndpointSecurityRuntimeCoordinator(liveMonitoringSession: session)
    coordinator.updateScopes([scope])
    try coordinator.start { evaluation in
        recorder.append(evaluation)
    }

    waitFor(timeout: 2) { recorder.count > 0 }
    #expect(recorder.first?.decision == .deny)
    #expect(recorder.first?.matchedScopeID == scope.id)

    coordinator.stop()
}

@Test
func runtimeCoordinatorPreservesErrorStatusWhenLiveSessionFails() {
    let session = FakeLiveMonitoringSession()
    session.onStart = { _ in
        throw FakeLiveMonitoringError.startFailed
    }

    let coordinator = EndpointSecurityRuntimeCoordinator(liveMonitoringSession: session)

    #expect(throws: FakeLiveMonitoringError.self) {
        try coordinator.start { _ in }
    }
    #expect(coordinator.runtimeStatus().state == .error)
    #expect(coordinator.runtimeStatus().detail.contains("fake live session start failed"))
}

private func makeProtectedScope() -> DriveManagedScope {
    DriveManagedScope(
        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        displayName: "Protected Scope",
        path: "/Volumes/Work/Google Drive",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .external,
        fileSystemKind: .apfs,
        supportStatus: .supported,
        enforcementMode: .blockKnownArtefacts
    )
}

private func waitFor(timeout: TimeInterval, condition: @escaping () -> Bool) {
    let timeoutDate = Date().addingTimeInterval(timeout)
    while Date() < timeoutDate {
        if condition() {
            return
        }
        Thread.sleep(forTimeInterval: 0.02)
    }
}

private enum FakeLiveMonitoringError: Error, LocalizedError {
    case startFailed

    var errorDescription: String? {
        switch self {
        case .startFailed:
            return "fake live session start failed"
        }
    }
}

private final class FakeLiveMonitoringSession: EndpointSecurityLiveMonitoringSession, @unchecked Sendable {
    var startCallCount = 0
    var stopCallCount = 0
    var onStart: ((EndpointSecurityProcessAttributedEventSubscriber) throws -> Void)?

    func start(with subscriber: EndpointSecurityProcessAttributedEventSubscriber) throws {
        startCallCount += 1
        try onStart?(subscriber)
    }

    func stop() {
        stopCallCount += 1
    }
}

private final class EvaluationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [HelperProtectionEvaluation] = []

    func append(_ value: HelperProtectionEvaluation) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        let value = values.count
        lock.unlock()
        return value
    }

    var first: HelperProtectionEvaluation? {
        lock.lock()
        let value = values.first
        lock.unlock()
        return value
    }
}
#elseif canImport(XCTest)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardRuntimeSupport
import DriveIconGuardShared
import Foundation
import XCTest

final class EndpointSecurityRuntimeCoordinatorTests: XCTestCase {
    func testRuntimeCoordinatorMarksReadyWhenLiveSessionStarts() throws {
        let session = FakeLiveMonitoringSession()
        session.onStart = { subscriber in
            subscriber.markLiveMonitoringReady(detail: "Subscribed for runtime-coordinator test.")
        }

        let coordinator = EndpointSecurityRuntimeCoordinator(liveMonitoringSession: session)
        try coordinator.start { _ in }

        XCTAssertEqual(coordinator.runtimeStatus().state, .ready)
        XCTAssertEqual(session.startCallCount, 1)

        coordinator.stop()
        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertTrue(coordinator.runtimeStatus().state == .bundled || coordinator.runtimeStatus().state == .unavailable)
    }

    func testRuntimeCoordinatorForwardsLiveEventIntoPolicyEvaluation() throws {
        let session = FakeLiveMonitoringSession()
        let scope = makeProtectedScope()
        let recorder = EvaluationRecorder()
        session.onStart = { subscriber in
            subscriber.markLiveMonitoringReady(detail: "Subscribed for runtime-coordinator test.")
            subscriber.handleLiveRawEvent(
                EndpointSecurityRawCallbackEvent(
                    operation: .create,
                    targetPath: "/Volumes/Work/Google Drive/Folder/Icon\r",
                    process: EndpointSecurityProcessMetadata(
                        pid: 77,
                        executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                        displayName: "Google Drive",
                        bundleID: "com.google.drivefs"
                    )
                )
            )
        }

        let coordinator = EndpointSecurityRuntimeCoordinator(liveMonitoringSession: session)
        coordinator.updateScopes([scope])
        try coordinator.start { evaluation in
            recorder.append(evaluation)
        }

        waitFor(timeout: 2) { recorder.count > 0 }
        XCTAssertEqual(recorder.first?.decision, .deny)
        XCTAssertEqual(recorder.first?.matchedScopeID, scope.id)

        coordinator.stop()
    }

    func testRuntimeCoordinatorPreservesErrorStatusWhenLiveSessionFails() {
        let session = FakeLiveMonitoringSession()
        session.onStart = { _ in
            throw FakeLiveMonitoringError.startFailed
        }

        let coordinator = EndpointSecurityRuntimeCoordinator(liveMonitoringSession: session)

        XCTAssertThrowsError(try coordinator.start { _ in }) { error in
            XCTAssertEqual(error.localizedDescription, "fake live session start failed")
        }
        XCTAssertEqual(coordinator.runtimeStatus().state, .error)
        XCTAssertTrue(coordinator.runtimeStatus().detail.contains("fake live session start failed"))
    }
}

private func makeProtectedScope() -> DriveManagedScope {
    DriveManagedScope(
        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        displayName: "Protected Scope",
        path: "/Volumes/Work/Google Drive",
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .external,
        fileSystemKind: .apfs,
        supportStatus: .supported,
        enforcementMode: .blockKnownArtefacts
    )
}

private func waitFor(timeout: TimeInterval, condition: @escaping () -> Bool) {
    let timeoutDate = Date().addingTimeInterval(timeout)
    while Date() < timeoutDate {
        if condition() {
            return
        }
        Thread.sleep(forTimeInterval: 0.02)
    }
}

private enum FakeLiveMonitoringError: Error, LocalizedError {
    case startFailed

    var errorDescription: String? {
        switch self {
        case .startFailed:
            return "fake live session start failed"
        }
    }
}

private final class FakeLiveMonitoringSession: EndpointSecurityLiveMonitoringSession, @unchecked Sendable {
    var startCallCount = 0
    var stopCallCount = 0
    var onStart: ((EndpointSecurityProcessAttributedEventSubscriber) throws -> Void)?

    func start(with subscriber: EndpointSecurityProcessAttributedEventSubscriber) throws {
        startCallCount += 1
        try onStart?(subscriber)
    }

    func stop() {
        stopCallCount += 1
    }
}

private final class EvaluationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [HelperProtectionEvaluation] = []

    func append(_ value: HelperProtectionEvaluation) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        let value = values.count
        lock.unlock()
        return value
    }

    var first: HelperProtectionEvaluation? {
        lock.lock()
        let value = values.first
        lock.unlock()
        return value
    }
}
#endif
