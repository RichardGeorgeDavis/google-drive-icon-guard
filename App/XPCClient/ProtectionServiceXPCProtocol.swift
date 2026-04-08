import Foundation

@objc public protocol ProtectionServiceXPCProtocol {
    func queryStatus(reply: @escaping (NSData) -> Void)
    func subscribeEvents(withListenerEndpoint endpoint: NSXPCListenerEndpoint, reply: @escaping (NSData) -> Void)
    func updateConfigurationData(_ data: NSData, reply: @escaping (NSData) -> Void)
    func startProtection(reply: @escaping (NSData) -> Void)
    func stopProtection(reply: @escaping (NSData) -> Void)
    func evaluateNow(reply: @escaping (NSData) -> Void)
}

@objc public protocol ProtectionServiceXPCEventSinkProtocol {
    func didReceiveEventsData(_ data: NSData)
}
