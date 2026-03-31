#if canImport(Testing)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared
import Foundation
import Testing

@Test
func replayLoaderSupportsJSONArrayFiles() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let events = [sampleEvent(path: "/Volumes/Drive/A/Icon\r")]
    let url = temporaryDirectory.appendingPathComponent("events.json", isDirectory: false)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(events).write(to: url)

    let loaded = try ReplayProcessAttributedEventLoader().load(from: url)

    #expect(loaded == events)
}

@Test
func replaySubscriberDeliversEventsFromJSONLFiles() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let events = [
        sampleEvent(path: "/Volumes/Drive/A/Icon\r"),
        sampleEvent(path: "/Volumes/Drive/B/._cover.png")
    ]
    let url = temporaryDirectory.appendingPathComponent("events.jsonl", isDirectory: false)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let jsonl = try events
        .map { event in
            let data = try encoder.encode(event)
            return String(decoding: data, as: UTF8.self)
        }
        .joined(separator: "\n")
    try Data(jsonl.utf8).write(to: url)

    let subscriber = try ReplayProcessAttributedEventSubscriber(fileURL: url)
    let captured = LockedBox<[ProcessAttributedFileEvent]>([])
    subscriber.start { event in
        captured.withLock { $0.append(event) }
    }

    #expect(subscriber.waitUntilFinished())
    #expect(captured.value == events)
}

private func sampleEvent(path: String) -> ProcessAttributedFileEvent {
    ProcessAttributedFileEvent(
        timestamp: Date(timeIntervalSince1970: 1_743_370_800),
        processSignature: ProcessSignature(
            bundleID: "com.google.drivefs",
            executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
            displayName: "Google Drive",
            isGoogleDriveRelated: true
        ),
        targetPath: path,
        operation: .create
    )
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func withLock(_ body: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&storage)
    }
}
#elseif canImport(XCTest)
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared
import Foundation
import XCTest

final class ReplayProcessAttributedEventSubscriberTests: XCTestCase {
    func testReplayLoaderSupportsJSONArrayFiles() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let events = [sampleEvent(path: "/Volumes/Drive/A/Icon\r")]
        let url = temporaryDirectory.appendingPathComponent("events.json", isDirectory: false)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(events).write(to: url)

        let loaded = try ReplayProcessAttributedEventLoader().load(from: url)

        XCTAssertEqual(loaded, events)
    }

    func testReplaySubscriberDeliversEventsFromJSONLFiles() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let events = [
            sampleEvent(path: "/Volumes/Drive/A/Icon\r"),
            sampleEvent(path: "/Volumes/Drive/B/._cover.png")
        ]
        let url = temporaryDirectory.appendingPathComponent("events.jsonl", isDirectory: false)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonl = try events
            .map { event in
                let data = try encoder.encode(event)
                return String(decoding: data, as: UTF8.self)
            }
            .joined(separator: "\n")
        try Data(jsonl.utf8).write(to: url)

        let subscriber = try ReplayProcessAttributedEventSubscriber(fileURL: url)
        let captured = LockedBox<[ProcessAttributedFileEvent]>([])
        subscriber.start { event in
            captured.withLock { $0.append(event) }
        }

        XCTAssertTrue(subscriber.waitUntilFinished())
        XCTAssertEqual(captured.value, events)
    }

    private func sampleEvent(path: String) -> ProcessAttributedFileEvent {
        ProcessAttributedFileEvent(
            timestamp: Date(timeIntervalSince1970: 1_743_370_800),
            processSignature: ProcessSignature(
                bundleID: "com.google.drivefs",
                executablePath: "/Applications/Google Drive.app/Contents/MacOS/Google Drive",
                displayName: "Google Drive",
                isGoogleDriveRelated: true
            ),
            targetPath: path,
            operation: .create
        )
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func withLock(_ body: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&storage)
    }
}
#endif
