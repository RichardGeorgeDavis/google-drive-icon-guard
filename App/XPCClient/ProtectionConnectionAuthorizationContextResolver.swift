import Foundation
import Security

public protocol ProtectionConnectionAuthorizationContextResolving: Sendable {
    func resolve(connection: NSXPCConnection) -> ProtectionServiceAuthorizationContext
}

public struct PIDProtectionConnectionAuthorizationContextResolver: ProtectionConnectionAuthorizationContextResolving {
    public init() {}

    public func resolve(connection: NSXPCConnection) -> ProtectionServiceAuthorizationContext {
        let pid = connection.processIdentifier
        guard pid > 0 else {
            return ProtectionServiceAuthorizationContext(hasAuditToken: true)
        }

        let attributes = [kSecGuestAttributePid as String: pid] as CFDictionary
        var guestCode: SecCode?
        let guestStatus = SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &guestCode)
        guard guestStatus == errSecSuccess, let guestCode else {
            return ProtectionServiceAuthorizationContext(hasAuditToken: true)
        }

        var staticCode: SecStaticCode?
        let staticCodeStatus = SecCodeCopyStaticCode(guestCode, SecCSFlags(), &staticCode)
        guard staticCodeStatus == errSecSuccess, let staticCode else {
            return ProtectionServiceAuthorizationContext(hasAuditToken: true)
        }

        var signingInfo: CFDictionary?
        let signingStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfo
        )
        guard signingStatus == errSecSuccess,
              let signingDictionary = signingInfo as? [String: Any] else {
            return ProtectionServiceAuthorizationContext(hasAuditToken: true)
        }

        let bundleID = signingDictionary[kSecCodeInfoIdentifier as String] as? String
        let teamIdentifier = signingDictionary[kSecCodeInfoTeamIdentifier as String] as? String
        return ProtectionServiceAuthorizationContext(
            callerBundleID: bundleID,
            callerTeamIdentifier: teamIdentifier,
            hasAuditToken: true
        )
    }
}
