import Foundation
import DriveIconGuardIPC

public final class ProtectionXPCListenerHost: NSObject {
    public let endpoint: NSXPCListenerEndpoint?

    private let listener: NSXPCListener
    private let serviceEndpoint: LocalProtectionServiceEndpoint
    private let contextResolver: any ProtectionConnectionAuthorizationContextResolving

    public init(
        serviceEndpoint: LocalProtectionServiceEndpoint = LocalProtectionServiceEndpoint(),
        contextResolver: any ProtectionConnectionAuthorizationContextResolving = PIDProtectionConnectionAuthorizationContextResolver()
    ) {
        let listener = NSXPCListener.anonymous()
        self.listener = listener
        self.endpoint = listener.endpoint
        self.serviceEndpoint = serviceEndpoint
        self.contextResolver = contextResolver
        super.init()
        listener.delegate = self
        listener.resume()
    }

    public init(
        machServiceName: String,
        serviceEndpoint: LocalProtectionServiceEndpoint = LocalProtectionServiceEndpoint(),
        contextResolver: any ProtectionConnectionAuthorizationContextResolving = PIDProtectionConnectionAuthorizationContextResolver()
    ) {
        let listener = NSXPCListener(machServiceName: machServiceName)
        self.listener = listener
        self.endpoint = nil
        self.serviceEndpoint = serviceEndpoint
        self.contextResolver = contextResolver
        super.init()
        listener.delegate = self
        listener.resume()
    }

    deinit {
        listener.invalidate()
    }
}

extension ProtectionXPCListenerHost: NSXPCListenerDelegate {
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let exportedInterface = NSXPCInterface(with: ProtectionServiceXPCProtocol.self)
        let remoteInterface = NSXPCInterface(with: ProtectionServiceXPCEventSinkProtocol.self)

        let context = contextResolver.resolve(connection: newConnection)
        let exportedObject = ProtectionXPCService(
            serviceEndpoint: serviceEndpoint,
            context: context
        )

        newConnection.exportedInterface = exportedInterface
        newConnection.exportedObject = exportedObject
        newConnection.remoteObjectInterface = remoteInterface
        newConnection.resume()
        return true
    }
}

private final class ProtectionXPCService: NSObject, ProtectionServiceXPCProtocol {
    private let serviceEndpoint: LocalProtectionServiceEndpoint
    private let context: ProtectionServiceAuthorizationContext

    private var eventConnection: NSXPCConnection?

    init(
        serviceEndpoint: LocalProtectionServiceEndpoint,
        context: ProtectionServiceAuthorizationContext
    ) {
        self.serviceEndpoint = serviceEndpoint
        self.context = context
    }

    deinit {
        eventConnection?.invalidate()
    }

    func queryStatus(reply: @escaping (NSData) -> Void) {
        reply(ProtectionServiceXPCCodec.encodeOutcome(serviceEndpoint.queryStatus(context: context)))
    }

    func subscribeEvents(withListenerEndpoint endpoint: NSXPCListenerEndpoint, reply: @escaping (NSData) -> Void) {
        let connection = NSXPCConnection(listenerEndpoint: endpoint)
        connection.remoteObjectInterface = NSXPCInterface(with: ProtectionServiceXPCEventSinkProtocol.self)
        connection.resume()
        eventConnection?.invalidate()
        eventConnection = connection

        let outcome = serviceEndpoint.subscribeEvents(context: context) { [weak self] events in
            guard let self,
                  let remote = self.eventConnection?.remoteObjectProxy as? ProtectionServiceXPCEventSinkProtocol else {
                return
            }

            remote.didReceiveEventsData(ProtectionServiceXPCCodec.encodeEvents(events))
        }

        reply(ProtectionServiceXPCCodec.encodeOutcome(outcome))
    }

    func updateConfigurationData(_ data: NSData, reply: @escaping (NSData) -> Void) {
        let configuration: ProtectionServiceConfiguration

        do {
            configuration = try ProtectionServiceXPCCodec.decodeConfiguration(data as Data)
        } catch {
            let outcome = ProtectionServiceCommandOutcome(
                command: .updateConfiguration,
                accepted: false,
                detail: "Rejected malformed configuration payload: \(error.localizedDescription)",
                failureReason: .invalidConfiguration,
                status: serviceEndpoint.queryStatus(context: context).status
            )
            reply(ProtectionServiceXPCCodec.encodeOutcome(outcome))
            return
        }

        reply(ProtectionServiceXPCCodec.encodeOutcome(serviceEndpoint.updateConfiguration(configuration, context: context)))
    }

    func startProtection(reply: @escaping (NSData) -> Void) {
        reply(ProtectionServiceXPCCodec.encodeOutcome(serviceEndpoint.start(context: context)))
    }

    func stopProtection(reply: @escaping (NSData) -> Void) {
        reply(ProtectionServiceXPCCodec.encodeOutcome(serviceEndpoint.stop(context: context)))
    }

    func evaluateNow(reply: @escaping (NSData) -> Void) {
        reply(ProtectionServiceXPCCodec.encodeOutcome(serviceEndpoint.evaluateNow(context: context)))
    }
}
