import Foundation
import DriveIconGuardIPC

#if os(macOS) && canImport(EndpointSecurity)
import EndpointSecurity
#endif

public final class EndpointSecurityProcessAttributedEventSubscriber: ProcessAttributedEventSubscriber, @unchecked Sendable {
    public private(set) var status: ProtectionEventSourceStatus
    private let callbackBridge: EndpointSecurityCallbackBridge
    private let stateLock = NSLock()
    private var runtimeEventHandler: (@Sendable (ProcessAttributedFileEvent) -> Void)?

    public init(
        callbackBridge: EndpointSecurityCallbackBridge = EndpointSecurityCallbackBridge()
    ) {
        self.callbackBridge = callbackBridge
        #if os(macOS) && canImport(EndpointSecurity)
        status = ProtectionEventSourceStatus(
            state: .needsApproval,
            detail: "Endpoint Security support is compiled into this build, and event-to-policy mapping scaffolding is ready, but live monitoring still needs entitlement approval, install path, and runtime bridge wiring."
        )
        #else
        status = ProtectionEventSourceStatus(
            state: .unavailable,
            detail: "The Endpoint Security framework is unavailable in this build environment, so live process-attributed monitoring cannot start."
        )
        #endif
    }

    public func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void) {
        withStateLock {
            runtimeEventHandler = eventHandler
        }
        #if os(macOS) && canImport(EndpointSecurity)
        if callbackBridge.map(Self.preflightRawEvent) != nil {
            status = ProtectionEventSourceStatus(
                state: .bundled,
                detail: "Endpoint Security start was requested and callback bridge preflight succeeded. Live ES client/subscription wiring is still required before the subscriber can become ready."
            )
            return
        }
        status = ProtectionEventSourceStatus(
            state: .error,
            detail: "Endpoint Security start was requested, but callback bridge preflight failed before live ES client/subscription wiring."
        )
        #else
        status = ProtectionEventSourceStatus(
            state: .unavailable,
            detail: "Endpoint Security monitoring cannot start because the framework is unavailable in this build environment."
        )
        #endif
    }

    public func stop() {
        withStateLock {
            runtimeEventHandler = nil
        }
        #if os(macOS) && canImport(EndpointSecurity)
        status = ProtectionEventSourceStatus(
            state: .bundled,
            detail: "Endpoint Security preflight subscriber is bundled but idle."
        )
        #else
        status = ProtectionEventSourceStatus(
            state: .unavailable,
            detail: "Endpoint Security monitoring remains unavailable in this build environment."
        )
        #endif
    }

    public func markLiveMonitoringReady(detail: String) {
        let hasRuntimeEventHandler = withStateLock { runtimeEventHandler != nil }
        guard hasRuntimeEventHandler else {
            status = ProtectionEventSourceStatus(
                state: .error,
                detail: "Endpoint Security live monitoring was marked ready before subscriber event handler setup completed."
            )
            return
        }

        status = ProtectionEventSourceStatus(state: .ready, detail: detail)
    }

    public func markLiveMonitoringFailed(detail: String) {
        status = ProtectionEventSourceStatus(state: .error, detail: detail)
    }

    #if os(macOS) && canImport(EndpointSecurity)
    private static let preflightRawEvent = EndpointSecurityRawCallbackEvent(
        operation: .create,
        targetPath: "/tmp/.endpoint-security-bridge-preflight",
        process: EndpointSecurityProcessMetadata(
            pid: 0,
            executablePath: "/usr/bin/endpointsecurity-preflight",
            displayName: "Endpoint Security Preflight"
        )
    )

    /// Call this from the `es_new_client` callback closure when live Endpoint Security is wired in a target that links `EndpointSecurity`.
    /// `runtimeEventHandler` must already be set via `start(eventHandler:)`.
    public func handleLiveEndpointSecurityMessage(_ message: UnsafePointer<es_message_t>) {
        let eventHandler = withStateLock { runtimeEventHandler }
        guard let eventHandler else {
            status = ProtectionEventSourceStatus(
                state: .error,
                detail: "Endpoint Security live callback fired before subscriber event handler was set."
            )
            return
        }
        handleMessage(message, eventHandler: eventHandler)
    }

    /// Use this for tests or alternative runtime adapters that already extracted an ES callback into `EndpointSecurityRawCallbackEvent`.
    public func handleLiveRawEvent(_ rawEvent: EndpointSecurityRawCallbackEvent) {
        let eventHandler = withStateLock { runtimeEventHandler }
        guard let eventHandler else {
            status = ProtectionEventSourceStatus(
                state: .error,
                detail: "Endpoint Security runtime event arrived before subscriber event handler was set."
            )
            return
        }

        guard dispatch(rawEvent: rawEvent, eventHandler: eventHandler) else {
            status = ProtectionEventSourceStatus(
                state: .error,
                detail: "Endpoint Security raw callback event conversion failed during bridge dispatch."
            )
            return
        }

        status = ProtectionEventSourceStatus(
            state: .ready,
            detail: "Endpoint Security raw callback event converted and dispatched into the process-attributed policy pipeline."
        )
    }

    // This is the runtime callback entrypoint to use once ES client/subscription
    // wiring is enabled in the packaging/runtime lane.
    private func handleMessage(
        _ message: UnsafePointer<es_message_t>,
        eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void
    ) {
        guard let rawEvent = makeRawCallbackEvent(from: message) else {
            status = ProtectionEventSourceStatus(
                state: .error,
                detail: "Endpoint Security callback received an unsupported or incomplete message that could not be converted into a raw callback event."
            )
            return
        }

        guard dispatch(rawEvent: rawEvent, eventHandler: eventHandler) else {
            status = ProtectionEventSourceStatus(
                state: .error,
                detail: "Endpoint Security callback event conversion failed during bridge dispatch."
            )
            return
        }

        markLiveMonitoringReady(
            detail: "Endpoint Security callback event converted and dispatched into the process-attributed policy pipeline."
        )
    }

    private func dispatch(
        rawEvent: EndpointSecurityRawCallbackEvent,
        eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void
    ) -> Bool {
        guard let mapped = callbackBridge.map(rawEvent) else {
            return false
        }
        eventHandler(mapped)
        return true
    }

    private struct EndpointSecurityMessageSnapshot {
        var operation: EndpointSecurityRawOperation
        var targetPath: String?
        var process: EndpointSecurityProcessMetadata
    }

    private func makeRawCallbackEvent(from message: UnsafePointer<es_message_t>) -> EndpointSecurityRawCallbackEvent? {
        guard let snapshot = makeSnapshot(from: message) else {
            return nil
        }
        return makeRawCallbackEvent(from: snapshot)
    }

    private func makeRawCallbackEvent(from snapshot: EndpointSecurityMessageSnapshot) -> EndpointSecurityRawCallbackEvent? {
        guard let targetPath = snapshot.targetPath,
              !targetPath.trimmingCharacters(in: CharacterSet(charactersIn: " \t")).isEmpty else {
            return nil
        }

        return EndpointSecurityRawCallbackEvent(
            operation: snapshot.operation,
            targetPath: targetPath,
            process: snapshot.process
        )
    }

    private func makeSnapshot(from message: UnsafePointer<es_message_t>) -> EndpointSecurityMessageSnapshot? {
        guard let operation = operation(from: message.pointee.event_type) else {
            return nil
        }

        let processMetadata = extractProcessMetadata(from: message)
        let targetPath = extractTargetPath(from: message, operation: operation)
        return EndpointSecurityMessageSnapshot(
            operation: operation,
            targetPath: targetPath,
            process: processMetadata
        )
    }

    private func operation(from eventType: es_event_type_t) -> EndpointSecurityRawOperation? {
        switch eventType {
        case ES_EVENT_TYPE_NOTIFY_CREATE:
            return .create
        case ES_EVENT_TYPE_NOTIFY_RENAME:
            return .rename
        case ES_EVENT_TYPE_NOTIFY_UNLINK:
            return .unlink
        default:
            return nil
        }
    }

    private func extractProcessMetadata(from message: UnsafePointer<es_message_t>) -> EndpointSecurityProcessMetadata {
        let process = message.pointee.process.pointee
        let executablePath = tokenToString(process.executable.pointee.path)
        let fallbackDisplay = executablePath.isEmpty ? "unknown-process" : URL(fileURLWithPath: executablePath).lastPathComponent

        return EndpointSecurityProcessMetadata(
            pid: 0,
            executablePath: executablePath.isEmpty ? "/unknown" : executablePath,
            displayName: fallbackDisplay,
            bundleID: nil,
            signingIdentity: nil
        )
    }

    private func extractTargetPath(from message: UnsafePointer<es_message_t>, operation: EndpointSecurityRawOperation) -> String? {
        switch operation {
        case .create:
            return EndpointSecurityPathBuilder.join(
                directoryPath: tokenToString(message.pointee.event.create.destination.new_path.dir.pointee.path),
                fileName: tokenToString(message.pointee.event.create.destination.new_path.filename)
            )
        case .rename:
            if message.pointee.event.rename.destination_type == ES_DESTINATION_TYPE_NEW_PATH {
                return EndpointSecurityPathBuilder.join(
                    directoryPath: tokenToString(message.pointee.event.rename.destination.new_path.dir.pointee.path),
                    fileName: tokenToString(message.pointee.event.rename.destination.new_path.filename)
                )
            }
            return tokenToString(message.pointee.event.rename.source.pointee.path)
        case .unlink:
            return tokenToString(message.pointee.event.unlink.target.pointee.path)
        }
    }

    private func tokenToString(_ token: es_string_token_t) -> String {
        guard token.length > 0 else {
            return ""
        }
        let bytes = UnsafeRawBufferPointer(start: token.data, count: Int(token.length))
        return String(data: Data(bytes), encoding: .utf8) ?? ""
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    // MARK: - Live ES client integration (copy into app/system-extension target)
    //
    // SwiftPM links this helper without the Endpoint Security dylib; use an Xcode app
    // or system-extension target that links `EndpointSecurity.framework`, has the
    // entitlement, and runs the approval flow. Then replace the preflight-only `start`
    // body with something like:
    //
    // ```swift
    // private var esClient: OpaquePointer?
    //
    // func startLiveClient() {
    //     var newClient: OpaquePointer?
    //     let createResult = es_new_client(&newClient) { [weak self] _, message in
    //         guard let self else { return }
    //         self.handleLiveEndpointSecurityMessage(message)
    //     }
    //     guard createResult == ES_NEW_CLIENT_RESULT_SUCCESS, let client = newClient else {
    //         status = ProtectionEventSourceStatus(state: .error, detail: "es_new_client failed: \(createResult.rawValue)")
    //         return
    //     }
    //     esClient = client
    //
    //     let events: [es_event_type_t] = [
    //         ES_EVENT_TYPE_NOTIFY_CREATE,
    //         ES_EVENT_TYPE_NOTIFY_RENAME,
    //         ES_EVENT_TYPE_NOTIFY_UNLINK
    //     ]
    //     let subResult = events.withUnsafeBufferPointer { buf in
    //         es_subscribe(client, buf.baseAddress!, UInt32(buf.count))
    //     }
    //     guard subResult == ES_RETURN_SUCCESS else {
    //         es_delete_client(client)
    //         esClient = nil
    //         status = ProtectionEventSourceStatus(state: .error, detail: "es_subscribe failed: \(subResult.rawValue)")
    //         return
    //     }
    //     status = ProtectionEventSourceStatus(state: .ready, detail: "Endpoint Security client subscribed; live callbacks will dispatch mapped events.")
    // }
    //
    // func stopLiveClient() {
    //     if let client = esClient {
    //         es_unsubscribe_all(client)
    //         es_delete_client(client)
    //         esClient = nil
    //     }
    // }
    // ```
    //
    // Keep `handleLiveEndpointSecurityMessage` as the ES callback entry for all live messages.
    #endif
}

public enum EndpointSecurityPathBuilder {
    public static func join(directoryPath: String, fileName: String) -> String {
        let trimSet = CharacterSet(charactersIn: " \t")
        let directory = directoryPath.trimmingCharacters(in: trimSet)
        let file = fileName.trimmingCharacters(in: trimSet)
        guard !directory.isEmpty else { return file }
        guard !file.isEmpty else { return directory }
        if directory.hasSuffix("/") {
            return directory + file
        }
        return directory + "/" + file
    }
}
