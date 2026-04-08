import Foundation
import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardShared

public enum ProtectionServiceBoundaryFailureReason: String, Codable, Equatable, Sendable {
    case missingAuditToken
    case callerIdentityUntrusted
    case invalidConfiguration
    case installationNotReady
}

public struct ProtectionServiceCommandOutcome: Codable, Equatable, Sendable {
    public var command: ProtectionServiceCommand
    public var accepted: Bool
    public var detail: String
    public var failureReason: ProtectionServiceBoundaryFailureReason?
    public var status: ProtectionServiceStatusSnapshot

    public init(
        command: ProtectionServiceCommand,
        accepted: Bool,
        detail: String,
        failureReason: ProtectionServiceBoundaryFailureReason? = nil,
        status: ProtectionServiceStatusSnapshot
    ) {
        self.command = command
        self.accepted = accepted
        self.detail = detail
        self.failureReason = failureReason
        self.status = status
    }
}

public final class LocalProtectionServiceEndpoint: @unchecked Sendable {
    public typealias EventHandler = @Sendable ([ProtectionServiceEventPayload]) -> Void

    private let service: HelperProtectionService
    private let authorizer: ProtectionServiceAuthorizer
    private let installationStatusResolver: ProtectionInstallationStatusResolver
    private let queue: DispatchQueue

    private var configuration = ProtectionServiceConfiguration(liveProtectionEnabled: false, scopes: [])
    private var eventHandler: EventHandler?
    private var isStarted = false

    public init(
        service: HelperProtectionService = HelperProtectionService(),
        authorizer: ProtectionServiceAuthorizer = ProtectionServiceAuthorizer(),
        installationStatusResolver: ProtectionInstallationStatusResolver = ProtectionInstallationStatusResolver(),
        queue: DispatchQueue = DispatchQueue(label: "DriveIconGuard.LocalProtectionServiceEndpoint")
    ) {
        self.service = service
        self.authorizer = authorizer
        self.installationStatusResolver = installationStatusResolver
        self.queue = queue
    }

    deinit {
        service.stop()
    }

    public var helperExecutablePath: String? {
        installationStatusResolver.helperExecutablePath
    }

    public func queryStatus(context: ProtectionServiceAuthorizationContext) -> ProtectionServiceCommandOutcome {
        queue.sync {
            guard let denied = authorizationFailureOutcome(for: .queryStatus, context: context) else {
                return acceptedOutcome(
                    command: .queryStatus,
                    detail: currentStatus().detail,
                    status: currentStatus()
                )
            }
            return denied
        }
    }

    public func subscribeEvents(
        context: ProtectionServiceAuthorizationContext,
        handler: @escaping EventHandler
    ) -> ProtectionServiceCommandOutcome {
        queue.sync {
            guard let denied = authorizationFailureOutcome(for: .subscribeEvents, context: context) else {
                let installStatus = installationStatusResolver.resolve()
                guard installStatus.state == .installed else {
                    return installationFailureOutcome(for: .subscribeEvents, installationStatus: installStatus)
                }

                eventHandler = handler
                let status = currentStatus()
                return acceptedOutcome(
                    command: .subscribeEvents,
                    detail: "Event delivery subscription is armed for the helper service boundary.",
                    status: status
                )
            }
            return denied
        }
    }

    public func start(context: ProtectionServiceAuthorizationContext) -> ProtectionServiceCommandOutcome {
        queue.sync {
            guard let denied = authorizationFailureOutcome(for: .startProtection, context: context) else {
                let installStatus = installationStatusResolver.resolve()
                guard installStatus.state == .installed else {
                    return installationFailureOutcome(for: .startProtection, installationStatus: installStatus)
                }

                if !isStarted {
                    service.start { [weak self] evaluation in
                        self?.queue.sync {
                            self?.eventHandler?([Self.makePayload(from: evaluation)])
                        }
                    }
                    isStarted = true
                }

                service.updateScopes(protectedScopes(from: configuration))
                let status = currentStatus()
                return acceptedOutcome(
                    command: .startProtection,
                    detail: status.detail,
                    status: status
                )
            }
            return denied
        }
    }

    public func stop(context: ProtectionServiceAuthorizationContext) -> ProtectionServiceCommandOutcome {
        queue.sync {
            guard let denied = authorizationFailureOutcome(for: .stopProtection, context: context) else {
                service.stop()
                service.updateScopes([])
                isStarted = false
                let status = currentStatus()
                return acceptedOutcome(
                    command: .stopProtection,
                    detail: "Helper service boundary is stopped.",
                    status: status
                )
            }
            return denied
        }
    }

    public func updateConfiguration(
        _ configuration: ProtectionServiceConfiguration,
        context: ProtectionServiceAuthorizationContext
    ) -> ProtectionServiceCommandOutcome {
        queue.sync {
            guard let denied = authorizationFailureOutcome(for: .updateConfiguration, context: context) else {
                if let validationFailure = validate(configuration: configuration) {
                    return validationFailureOutcome(for: .updateConfiguration, detail: validationFailure)
                }

                let installStatus = installationStatusResolver.resolve()
                guard installStatus.state == .installed else {
                    return installationFailureOutcome(for: .updateConfiguration, installationStatus: installStatus)
                }

                self.configuration = configuration
                if isStarted {
                    service.updateScopes(protectedScopes(from: configuration))
                }

                let status = currentStatus()
                return acceptedOutcome(
                    command: .updateConfiguration,
                    detail: status.detail,
                    status: status
                )
            }
            return denied
        }
    }

    public func evaluateNow(context: ProtectionServiceAuthorizationContext) -> ProtectionServiceCommandOutcome {
        queue.sync {
            guard let denied = authorizationFailureOutcome(for: .evaluateNow, context: context) else {
                let installStatus = installationStatusResolver.resolve()
                guard installStatus.state == .installed else {
                    return installationFailureOutcome(for: .evaluateNow, installationStatus: installStatus)
                }

                guard isStarted else {
                    let status = currentStatus(detail: "Helper service boundary is not started, so there is nothing to evaluate yet.")
                    return acceptedOutcome(
                        command: .evaluateNow,
                        detail: status.detail,
                        status: status
                    )
                }

                guard configuration.liveProtectionEnabled else {
                    let status = currentStatus(detail: "Live protection is disabled, so helper-side evaluation remains idle.")
                    return acceptedOutcome(
                        command: .evaluateNow,
                        detail: status.detail,
                        status: status
                    )
                }

                let status = currentStatus()
                return acceptedOutcome(
                    command: .evaluateNow,
                    detail: "Helper service boundary is event-driven. There is no queued replay batch to evaluate synchronously.",
                    status: status
                )
            }
            return denied
        }
    }

    private func validate(configuration: ProtectionServiceConfiguration) -> String? {
        if configuration.scopes.count > 256 {
            return "Protection configuration exceeds the beta boundary limit of 256 scopes."
        }

        var seenPaths = Set<String>()
        for scope in configuration.scopes {
            let trimmedDisplayName = scope.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedDisplayName.isEmpty {
                return "Protection configuration contains a scope with an empty display name."
            }

            let trimmedPath = scope.path.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedPath.isEmpty || !trimmedPath.hasPrefix("/") {
                return "Protection configuration contains a non-absolute scope path: \(scope.path)"
            }

            if !seenPaths.insert(trimmedPath).inserted {
                return "Protection configuration contains duplicate scope path entries for \(trimmedPath)."
            }
        }

        return nil
    }

    private func protectedScopes(from configuration: ProtectionServiceConfiguration) -> [DriveManagedScope] {
        guard configuration.liveProtectionEnabled else {
            return []
        }

        return configuration.scopes.filter {
            $0.supportStatus == .supported && $0.enforcementMode == .blockKnownArtefacts
        }
    }

    private func currentStatus(detail overrideDetail: String? = nil) -> ProtectionServiceStatusSnapshot {
        let helperPath = installationStatusResolver.helperExecutablePath
        let installationStatus = installationStatusResolver.resolve(helperPath: helperPath)
        let eventSourceStatus = service.runtimeStatus()
        let protectedScopeCount = protectedScopes(from: configuration).count

        let detail: String
        let mode: ProtectionServiceMode

        if let overrideDetail {
            detail = overrideDetail
            mode = resolvedMode(helperPath: helperPath, installationStatus: installationStatus)
        } else if helperPath == nil {
            detail = "No packaged helper executable is available for the protected service boundary."
            mode = .helperRequired
        } else if installationStatus.state == .error {
            detail = "Helper service boundary is blocked by an installation error: \(installationStatus.detail)"
            mode = .helperAvailable
        } else if installationStatus.state != .installed {
            detail = "Helper service boundary is present, but high-risk commands remain blocked until installation is verified as installed."
            mode = .helperAvailable
        } else if !isStarted || !configuration.liveProtectionEnabled {
            detail = "Helper service boundary is idle. Live protection is disabled or not started."
            mode = .inactive
        } else if protectedScopeCount == 0 {
            detail = "Helper service boundary is started, but no supported blocking scopes are configured."
            mode = .helperAvailable
        } else {
            detail = "Helper service boundary is armed for \(protectedScopeCount) supported blocking scope(s)."
            mode = .helperAvailable
        }

        return ProtectionServiceStatusSnapshot(
            mode: mode,
            activeProtectedScopeCount: protectedScopeCount,
            detail: detail,
            helperExecutablePath: helperPath,
            eventSourceState: eventSourceStatus.state,
            eventSourceDescription: eventSourceStatus.detail,
            installationState: installationStatus.state,
            installationDescription: installationStatus.detail
        )
    }

    private func resolvedMode(
        helperPath: String?,
        installationStatus: ProtectionInstallationStatus
    ) -> ProtectionServiceMode {
        if helperPath == nil {
            return .helperRequired
        }

        if installationStatus.state == .installed && isStarted && configuration.liveProtectionEnabled {
            return .helperAvailable
        }

        if installationStatus.state == .installed {
            return .inactive
        }

        return .helperAvailable
    }

    private func authorizationFailureOutcome(
        for command: ProtectionServiceCommand,
        context: ProtectionServiceAuthorizationContext
    ) -> ProtectionServiceCommandOutcome? {
        let result = authorizer.authorize(command: command, context: context)
        guard result.isAuthorized == false else {
            return nil
        }

        return ProtectionServiceCommandOutcome(
            command: command,
            accepted: false,
            detail: result.detail,
            failureReason: mapFailureReason(result.failureReason),
            status: currentStatus(detail: result.detail)
        )
    }

    private func installationFailureOutcome(
        for command: ProtectionServiceCommand,
        installationStatus: ProtectionInstallationStatus
    ) -> ProtectionServiceCommandOutcome {
        let detail = "Helper service command \(command.rawValue) is blocked until installation is verified as installed. Current state: \(installationStatus.state.rawValue). \(installationStatus.detail)"
        return ProtectionServiceCommandOutcome(
            command: command,
            accepted: false,
            detail: detail,
            failureReason: .installationNotReady,
            status: currentStatus(detail: detail)
        )
    }

    private func validationFailureOutcome(
        for command: ProtectionServiceCommand,
        detail: String
    ) -> ProtectionServiceCommandOutcome {
        ProtectionServiceCommandOutcome(
            command: command,
            accepted: false,
            detail: detail,
            failureReason: .invalidConfiguration,
            status: currentStatus(detail: detail)
        )
    }

    private func acceptedOutcome(
        command: ProtectionServiceCommand,
        detail: String,
        status: ProtectionServiceStatusSnapshot
    ) -> ProtectionServiceCommandOutcome {
        ProtectionServiceCommandOutcome(
            command: command,
            accepted: true,
            detail: detail,
            status: status
        )
    }

    private func mapFailureReason(
        _ reason: ProtectionAuthorizationFailureReason?
    ) -> ProtectionServiceBoundaryFailureReason? {
        switch reason {
        case .missingAuditToken:
            return .missingAuditToken
        case .callerIdentityUntrusted:
            return .callerIdentityUntrusted
        case .commandNotPermitted:
            return .callerIdentityUntrusted
        case nil:
            return nil
        }
    }

    private static func makePayload(from evaluation: HelperProtectionEvaluation) -> ProtectionServiceEventPayload {
        ProtectionServiceEventPayload(
            scopeID: evaluation.matchedScopeID ?? UUID(),
            scopePath: evaluation.event.targetPath,
            detectedArtefactCount: evaluation.matchedArtefactType == nil ? 0 : 1,
            detectedBytes: 0,
            removedCount: evaluation.decision == .deny ? 1 : 0,
            removedBytes: 0,
            status: evaluation.decision == .deny ? .applied : .unavailable,
            message: evaluation.reason
        )
    }
}

@MainActor
public final class BoundaryProtectionServiceClient: ProtectionServiceClient {
    public var helperExecutablePath: String? {
        endpoint.helperExecutablePath
    }

    public private(set) var status = ProtectionStatusFactory.unavailable()

    private let endpoint: LocalProtectionServiceEndpoint
    private let context: ProtectionServiceAuthorizationContext
    private var eventHandler: (@Sendable ([ProtectionServiceEventPayload]) -> Void)?

    public init(
        endpoint: LocalProtectionServiceEndpoint = LocalProtectionServiceEndpoint(),
        context: ProtectionServiceAuthorizationContext = ProtectionServiceAuthorizationContext(
            callerBundleID: Bundle.main.bundleIdentifier ?? "com.richardgeorgedavis.google-drive-icon-guard.beta",
            hasAuditToken: true
        )
    ) {
        self.endpoint = endpoint
        self.context = context
        self.status = endpoint.queryStatus(context: context).status
    }

    public func start() {
        let handler = eventHandler ?? { _ in }
        status = endpoint.subscribeEvents(context: context, handler: handler).status
        status = endpoint.start(context: context).status
    }

    public func stop() {
        status = endpoint.stop(context: context).status
    }

    public func updateConfiguration(_ configuration: ProtectionServiceConfiguration) {
        status = endpoint.updateConfiguration(configuration, context: context).status
    }

    public func evaluateNow() {
        status = endpoint.evaluateNow(context: context).status
    }

    public func setEventHandler(_ handler: @escaping @Sendable ([ProtectionServiceEventPayload]) -> Void) {
        eventHandler = handler
        status = endpoint.subscribeEvents(context: context, handler: handler).status
    }
}
