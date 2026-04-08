import Foundation
import DriveIconGuardIPC

@MainActor
public final class XPCProtectionServiceClient: NSObject, ProtectionServiceClient {
    public private(set) var status = ProtectionStatusFactory.unavailable()
    public private(set) var helperExecutablePath: String?

    private let connection: NSXPCConnection
    private let callbackListener: NSXPCListener
    private let callbackSink: ProtectionXPCEventSink
    private var eventHandler: (@Sendable ([ProtectionServiceEventPayload]) -> Void)?

    public init(listenerEndpoint: NSXPCListenerEndpoint) {
        self.connection = NSXPCConnection(listenerEndpoint: listenerEndpoint)
        self.callbackListener = NSXPCListener.anonymous()
        self.callbackSink = ProtectionXPCEventSink()
        super.init()
        configureConnection()
        status = requestOutcome(command: .queryStatus) { proxy, reply in
            proxy.queryStatus(reply: reply)
        }.status
        helperExecutablePath = status.helperExecutablePath
    }

    public init(machServiceName: String, options: NSXPCConnection.Options = []) {
        self.connection = NSXPCConnection(machServiceName: machServiceName, options: options)
        self.callbackListener = NSXPCListener.anonymous()
        self.callbackSink = ProtectionXPCEventSink()
        super.init()
        configureConnection()
        status = requestOutcome(command: .queryStatus) { proxy, reply in
            proxy.queryStatus(reply: reply)
        }.status
        helperExecutablePath = status.helperExecutablePath
    }

    private func configureConnection() {

        connection.remoteObjectInterface = NSXPCInterface(with: ProtectionServiceXPCProtocol.self)
        connection.resume()

        callbackSink.owner = self
        callbackListener.delegate = callbackSink
        callbackListener.resume()
    }

    deinit {
        callbackListener.invalidate()
        connection.invalidate()
    }

    public func start() {
        _ = subscribeIfNeeded()
        status = requestOutcome(command: .startProtection) { proxy, reply in
            proxy.startProtection(reply: reply)
        }.status
        helperExecutablePath = status.helperExecutablePath
    }

    public func stop() {
        status = requestOutcome(command: .stopProtection) { proxy, reply in
            proxy.stopProtection(reply: reply)
        }.status
        helperExecutablePath = status.helperExecutablePath
    }

    public func updateConfiguration(_ configuration: ProtectionServiceConfiguration) {
        let payload = ProtectionServiceXPCCodec.encodeConfiguration(configuration)
        status = requestOutcome(command: .updateConfiguration) { proxy, reply in
            proxy.updateConfigurationData(payload, reply: reply)
        }.status
        helperExecutablePath = status.helperExecutablePath
    }

    public func evaluateNow() {
        status = requestOutcome(command: .evaluateNow) { proxy, reply in
            proxy.evaluateNow(reply: reply)
        }.status
        helperExecutablePath = status.helperExecutablePath
    }

    public func setEventHandler(_ handler: @escaping @Sendable ([ProtectionServiceEventPayload]) -> Void) {
        eventHandler = handler
        status = subscribeIfNeeded().status
        helperExecutablePath = status.helperExecutablePath
    }

    fileprivate func receive(events: [ProtectionServiceEventPayload]) {
        eventHandler?(events)
    }

    private func subscribeIfNeeded() -> ProtectionServiceCommandOutcome {
        requestOutcome(command: .subscribeEvents) { proxy, reply in
            proxy.subscribeEvents(withListenerEndpoint: callbackListener.endpoint, reply: reply)
        }
    }

    private func requestOutcome(
        command: ProtectionServiceCommand,
        invoke: (_ proxy: ProtectionServiceXPCProtocol, _ reply: @escaping (NSData) -> Void) -> Void
    ) -> ProtectionServiceCommandOutcome {
        let semaphore = DispatchSemaphore(value: 0)
        var outcome = ProtectionServiceCommandOutcome(
            command: command,
            accepted: false,
            detail: "XPC request for \(command.rawValue) did not complete.",
            failureReason: .invalidConfiguration,
            status: status
        )

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            outcome = ProtectionServiceCommandOutcome(
                command: command,
                accepted: false,
                detail: "XPC request for \(command.rawValue) failed: \(error.localizedDescription)",
                failureReason: .invalidConfiguration,
                status: ProtectionStatusFactory.unavailable()
            )
            semaphore.signal()
        }) as? ProtectionServiceXPCProtocol else {
            return outcome
        }

        invoke(proxy) { data in
            do {
                outcome = try ProtectionServiceXPCCodec.decodeOutcome(data as Data)
            } catch {
                outcome = ProtectionServiceCommandOutcome(
                    command: command,
                    accepted: false,
                    detail: "Failed to decode XPC reply for \(command.rawValue): \(error.localizedDescription)",
                    failureReason: .invalidConfiguration,
                    status: ProtectionStatusFactory.unavailable()
                )
            }
            semaphore.signal()
        }

        semaphore.wait()
        return outcome
    }
}

private final class ProtectionXPCEventSink: NSObject, NSXPCListenerDelegate, ProtectionServiceXPCEventSinkProtocol {
    weak var owner: XPCProtectionServiceClient?

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: ProtectionServiceXPCEventSinkProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func didReceiveEventsData(_ data: NSData) {
        guard let owner else {
            return
        }

        guard let events = try? ProtectionServiceXPCCodec.decodeEvents(data as Data) else {
            return
        }

        Task { @MainActor in
            owner.receive(events: events)
        }
    }
}
