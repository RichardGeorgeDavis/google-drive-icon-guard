import Foundation

public enum ProtectionServiceCommand: String, Codable, Equatable, CaseIterable, Sendable {
    case queryStatus
    case subscribeEvents
    case updateConfiguration
    case startProtection
    case stopProtection
    case evaluateNow
}

public struct ProtectionServiceAuthorizationContext: Equatable, Sendable {
    public var callerBundleID: String?
    public var callerTeamIdentifier: String?
    public var hasAuditToken: Bool

    public init(
        callerBundleID: String? = nil,
        callerTeamIdentifier: String? = nil,
        hasAuditToken: Bool
    ) {
        self.callerBundleID = callerBundleID
        self.callerTeamIdentifier = callerTeamIdentifier
        self.hasAuditToken = hasAuditToken
    }
}

public enum ProtectionAuthorizationFailureReason: String, Codable, Equatable, Sendable {
    case missingAuditToken
    case callerIdentityUntrusted
    case commandNotPermitted
}

public struct ProtectionAuthorizationResult: Equatable, Sendable {
    public var isAuthorized: Bool
    public var detail: String
    public var failureReason: ProtectionAuthorizationFailureReason?

    public init(
        isAuthorized: Bool,
        detail: String,
        failureReason: ProtectionAuthorizationFailureReason? = nil
    ) {
        self.isAuthorized = isAuthorized
        self.detail = detail
        self.failureReason = failureReason
    }
}

public struct ProtectionServiceAuthorizer: Sendable {
    private let trustedBundleIDs: Set<String>
    private let trustedTeamIdentifiers: Set<String>

    public init(
        trustedBundleIDs: Set<String> = [
            "com.richardgeorgedavis.google-drive-icon-guard",
            "com.richardgeorgedavis.google-drive-icon-guard.beta"
        ],
        trustedTeamIdentifiers: Set<String> = []
    ) {
        self.trustedBundleIDs = trustedBundleIDs
        self.trustedTeamIdentifiers = trustedTeamIdentifiers
    }

    public func authorize(
        command: ProtectionServiceCommand,
        context: ProtectionServiceAuthorizationContext
    ) -> ProtectionAuthorizationResult {
        guard context.hasAuditToken else {
            return ProtectionAuthorizationResult(
                isAuthorized: false,
                detail: "Caller audit token is required before any helper-bound request can be trusted.",
                failureReason: .missingAuditToken
            )
        }

        switch command {
        case .queryStatus:
            return ProtectionAuthorizationResult(
                isAuthorized: true,
                detail: "Status queries are allowed after audit-token verification."
            )
        case .subscribeEvents, .updateConfiguration, .startProtection, .stopProtection, .evaluateNow:
            guard isTrustedCaller(context) else {
                return ProtectionAuthorizationResult(
                    isAuthorized: false,
                    detail: "Caller bundle/team identity is not trusted for high-risk protection commands.",
                    failureReason: .callerIdentityUntrusted
                )
            }

            return ProtectionAuthorizationResult(
                isAuthorized: true,
                detail: "Caller identity and audit token are trusted for \(command.rawValue)."
            )
        }
    }

    private func isTrustedCaller(_ context: ProtectionServiceAuthorizationContext) -> Bool {
        if let teamIdentifier = context.callerTeamIdentifier,
           trustedTeamIdentifiers.contains(teamIdentifier) {
            return true
        }

        if let bundleID = context.callerBundleID,
           trustedBundleIDs.contains(bundleID) {
            return true
        }

        return false
    }
}
