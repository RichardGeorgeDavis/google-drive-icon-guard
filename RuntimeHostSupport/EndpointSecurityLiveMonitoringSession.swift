import Foundation
import DriveIconGuardHelper

public protocol EndpointSecurityLiveMonitoringSession: Sendable {
    func start(with subscriber: EndpointSecurityProcessAttributedEventSubscriber) throws
    func stop()
}

public enum EndpointSecurityLiveMonitoringError: LocalizedError {
    case unavailableBuildEnvironment
    case frameworkLoadFailed(path: String)
    case symbolLoadFailed(name: String)
    case clientCreationFailed(resultCode: Int32)
    case subscriptionFailed(resultCode: Int32)

    public var errorDescription: String? {
        switch self {
        case .unavailableBuildEnvironment:
            return "Endpoint Security live monitoring is unavailable in the current build environment."
        case .frameworkLoadFailed(let path):
            return "Endpoint Security framework could not be loaded from \(path)."
        case .symbolLoadFailed(let name):
            return "Endpoint Security symbol \(name) could not be loaded at runtime."
        case .clientCreationFailed(let resultCode):
            return "Endpoint Security client creation failed with result code \(resultCode)."
        case .subscriptionFailed(let resultCode):
            return "Endpoint Security subscription failed with result code \(resultCode)."
        }
    }
}

#if os(macOS) && canImport(EndpointSecurity)
import Darwin
import EndpointSecurity

public final class SystemEndpointSecurityLiveMonitoringSession: EndpointSecurityLiveMonitoringSession, @unchecked Sendable {
    private let subscribedEvents: [es_event_type_t]
    private var api: EndpointSecurityDynamicAPI?
    private var client: OpaquePointer?
    private var clientHandler: EndpointSecurityHandlerBlock?

    public init(
        subscribedEvents: [es_event_type_t] = [
            ES_EVENT_TYPE_NOTIFY_CREATE,
            ES_EVENT_TYPE_NOTIFY_RENAME,
            ES_EVENT_TYPE_NOTIFY_UNLINK
        ]
    ) {
        self.subscribedEvents = subscribedEvents
    }

    deinit {
        stop()
    }

    public func start(with subscriber: EndpointSecurityProcessAttributedEventSubscriber) throws {
        guard client == nil else {
            subscriber.markLiveMonitoringReady(
                detail: "Endpoint Security client is already subscribed for live monitoring."
            )
            return
        }

        let api = try EndpointSecurityDynamicAPI()
        var newClient: OpaquePointer?
        let clientHandler: EndpointSecurityHandlerBlock = { _, message in
            subscriber.handleLiveEndpointSecurityMessage(message)
        }
        let createResult = api.esNewClient(&newClient, clientHandler)

        guard createResult == ES_NEW_CLIENT_RESULT_SUCCESS, let client = newClient else {
            throw EndpointSecurityLiveMonitoringError.clientCreationFailed(resultCode: Int32(createResult.rawValue))
        }

        let subscribeResult = subscribedEvents.withUnsafeBufferPointer { buffer in
            api.esSubscribe(client, buffer.baseAddress!, UInt32(buffer.count))
        }

        guard subscribeResult == ES_RETURN_SUCCESS else {
            _ = api.esDeleteClient(client)
            throw EndpointSecurityLiveMonitoringError.subscriptionFailed(resultCode: Int32(subscribeResult.rawValue))
        }

        self.api = api
        self.client = client
        self.clientHandler = clientHandler
        subscriber.markLiveMonitoringReady(
            detail: "Endpoint Security client subscribed for create, rename, and unlink events."
        )
    }

    public func stop() {
        guard let client, let api else {
            return
        }

        _ = api.esUnsubscribeAll(client)
        _ = api.esDeleteClient(client)
        self.clientHandler = nil
        self.client = nil
        self.api = nil
    }
}

private typealias EndpointSecurityHandlerBlock = @convention(block) (OpaquePointer, UnsafePointer<es_message_t>) -> Void
private typealias EndpointSecurityNewClientFunction = @convention(c) (
    UnsafeMutablePointer<OpaquePointer?>,
    EndpointSecurityHandlerBlock
) -> es_new_client_result_t
private typealias EndpointSecuritySubscribeFunction = @convention(c) (
    OpaquePointer,
    UnsafePointer<es_event_type_t>,
    UInt32
) -> es_return_t
private typealias EndpointSecurityUnsubscribeAllFunction = @convention(c) (OpaquePointer) -> es_return_t
private typealias EndpointSecurityDeleteClientFunction = @convention(c) (OpaquePointer?) -> es_return_t

private final class EndpointSecurityDynamicAPI {
    private static let frameworkPath = "/System/Library/Frameworks/EndpointSecurity.framework/EndpointSecurity"

    let esNewClient: EndpointSecurityNewClientFunction
    let esSubscribe: EndpointSecuritySubscribeFunction
    let esUnsubscribeAll: EndpointSecurityUnsubscribeAllFunction
    let esDeleteClient: EndpointSecurityDeleteClientFunction

    private let handle: UnsafeMutableRawPointer

    init() throws {
        guard let handle = dlopen(Self.frameworkPath, RTLD_NOW) else {
            throw EndpointSecurityLiveMonitoringError.frameworkLoadFailed(path: Self.frameworkPath)
        }

        self.handle = handle
        do {
            self.esNewClient = try Self.loadSymbol("es_new_client", from: handle)
            self.esSubscribe = try Self.loadSymbol("es_subscribe", from: handle)
            self.esUnsubscribeAll = try Self.loadSymbol("es_unsubscribe_all", from: handle)
            self.esDeleteClient = try Self.loadSymbol("es_delete_client", from: handle)
        } catch {
            dlclose(handle)
            throw error
        }
    }

    deinit {
        dlclose(handle)
    }

    private static func loadSymbol<T>(_ name: String, from handle: UnsafeMutableRawPointer) throws -> T {
        guard let symbol = dlsym(handle, name) else {
            throw EndpointSecurityLiveMonitoringError.symbolLoadFailed(name: name)
        }
        return unsafeBitCast(symbol, to: T.self)
    }
}
#else
public final class SystemEndpointSecurityLiveMonitoringSession: EndpointSecurityLiveMonitoringSession, @unchecked Sendable {
    public init() {}

    public func start(with subscriber: EndpointSecurityProcessAttributedEventSubscriber) throws {
        throw EndpointSecurityLiveMonitoringError.unavailableBuildEnvironment
    }

    public func stop() {}
}
#endif
