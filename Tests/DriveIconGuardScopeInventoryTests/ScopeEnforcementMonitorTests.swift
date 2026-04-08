#if canImport(Testing)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import Testing

@Test
func evaluateNowRespectsCooldownForRepeatedCleanup() throws {
    let tempRoot = try makeMonitorTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let scopeRoot = tempRoot.appendingPathComponent("scope", isDirectory: true)
    try FileManager.default.createDirectory(at: scopeRoot, withIntermediateDirectories: true)
    try Data("icon".utf8).write(to: scopeRoot.appendingPathComponent("Icon\r"))

    let monitor = ScopeEnforcementMonitor(interval: 120, cooldown: 30)
    let recorder = EventRecorder()
    monitor.start { events in
        recorder.append(events)
    }
    defer { monitor.stop() }

    monitor.updateScopes([makeSupportedScope(path: scopeRoot.path)])
    monitor.evaluateNow()
    waitFor(timeout: 2) { recorder.count > 0 }
    #expect(recorder.count == 1)
    #expect(recorder.first?.first?.applyResult.removedCount == 1)

    try Data("icon".utf8).write(to: scopeRoot.appendingPathComponent("Icon\r"))
    monitor.evaluateNow()
    Thread.sleep(forTimeInterval: 0.25)

    #expect(recorder.count == 1)
}

@Test
func stopPreventsFurtherCleanupAfterShutdown() throws {
    let tempRoot = try makeMonitorTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let scopeRoot = tempRoot.appendingPathComponent("scope", isDirectory: true)
    try FileManager.default.createDirectory(at: scopeRoot, withIntermediateDirectories: true)
    try Data("icon".utf8).write(to: scopeRoot.appendingPathComponent("Icon\r"))

    let monitor = ScopeEnforcementMonitor(interval: 120, cooldown: 0)
    monitor.start { _ in }
    monitor.stop()

    monitor.updateScopes([makeSupportedScope(path: scopeRoot.path)])
    monitor.evaluateNow()
    Thread.sleep(forTimeInterval: 0.25)
    #expect(FileManager.default.fileExists(atPath: scopeRoot.appendingPathComponent("Icon\r").path))
}

private func makeMonitorTempRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("scope-enforcement-monitor-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeSupportedScope(path: String) -> DriveManagedScope {
    DriveManagedScope(
        displayName: "Supported Scope",
        path: path,
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .internalVolume,
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

private final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [[ScopeEnforcementEvent]] = []

    func append(_ events: [ScopeEnforcementEvent]) {
        lock.lock()
        values.append(events)
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        let value = values.count
        lock.unlock()
        return value
    }

    var first: [ScopeEnforcementEvent]? {
        lock.lock()
        let value = values.first
        lock.unlock()
        return value
    }
}

#elseif canImport(XCTest)
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation
import XCTest

final class ScopeEnforcementMonitorTests: XCTestCase {
    func testEvaluateNowRespectsCooldownForRepeatedCleanup() throws {
        let tempRoot = try makeMonitorTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let scopeRoot = tempRoot.appendingPathComponent("scope", isDirectory: true)
        try FileManager.default.createDirectory(at: scopeRoot, withIntermediateDirectories: true)
        try Data("icon".utf8).write(to: scopeRoot.appendingPathComponent("Icon\r"))

        let monitor = ScopeEnforcementMonitor(interval: 120, cooldown: 30)
        let recorder = EventRecorder()
        monitor.start { events in
            recorder.append(events)
        }
        defer { monitor.stop() }

        monitor.updateScopes([makeSupportedScope(path: scopeRoot.path)])
        monitor.evaluateNow()
        waitFor(timeout: 2) { recorder.count > 0 }
        XCTAssertEqual(recorder.count, 1)
        XCTAssertEqual(recorder.first?.first?.applyResult.removedCount, 1)

        try Data("icon".utf8).write(to: scopeRoot.appendingPathComponent("Icon\r"))
        monitor.evaluateNow()
        Thread.sleep(forTimeInterval: 0.25)

        XCTAssertEqual(recorder.count, 1)
    }

    func testStopPreventsFurtherCleanupAfterShutdown() throws {
        let tempRoot = try makeMonitorTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let scopeRoot = tempRoot.appendingPathComponent("scope", isDirectory: true)
        try FileManager.default.createDirectory(at: scopeRoot, withIntermediateDirectories: true)
        try Data("icon".utf8).write(to: scopeRoot.appendingPathComponent("Icon\r"))

        let monitor = ScopeEnforcementMonitor(interval: 120, cooldown: 0)
        monitor.start { _ in }
        monitor.stop()

        monitor.updateScopes([makeSupportedScope(path: scopeRoot.path)])
        monitor.evaluateNow()
        Thread.sleep(forTimeInterval: 0.25)
        XCTAssertTrue(FileManager.default.fileExists(atPath: scopeRoot.appendingPathComponent("Icon\r").path))
    }
}

private func makeMonitorTempRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("scope-enforcement-monitor-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeSupportedScope(path: String) -> DriveManagedScope {
    DriveManagedScope(
        displayName: "Supported Scope",
        path: path,
        scopeKind: .myDrive,
        driveMode: .mirror,
        source: .config,
        volumeKind: .internalVolume,
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
#endif
