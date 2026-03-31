import Foundation
import DriveIconGuardIPC
import DriveIconGuardScopeInventory
import DriveIconGuardShared

@MainActor
public final class EmbeddedProtectionServiceClient: ProtectionServiceClient {
    public var helperExecutablePath: String? {
        helperHostLocator.locate()?.path
    }

    public private(set) var status = ProtectionServiceStatusSnapshot(
        mode: .inactive,
        activeProtectedScopeCount: 0,
        detail: "Automatic blocking remains in audit mode until a process-aware helper with Endpoint Security events is available.",
        eventSourceState: .unavailable,
        eventSourceDescription: "Current helper support is limited to replay/test scaffolding. Live Google-Drive-only blocking still requires a macOS Endpoint Security event source.",
        installationState: .unavailable,
        installationDescription: "No helper installation resources are available in this build."
    )

    private let monitor: ScopeEnforcementMonitor
    private let helperHostLocator: ProtectionHelperHostLocator
    private let installerResourceLocator: ProtectionInstallerResourceLocator
    private var configuration = ProtectionServiceConfiguration(liveProtectionEnabled: false, scopes: [])
    private var eventHandler: (@Sendable ([ProtectionServiceEventPayload]) -> Void)?
    private var isStarted = false

    public init(
        monitor: ScopeEnforcementMonitor = ScopeEnforcementMonitor(),
        helperHostLocator: ProtectionHelperHostLocator = ProtectionHelperHostLocator(),
        installerResourceLocator: ProtectionInstallerResourceLocator = ProtectionInstallerResourceLocator()
    ) {
        self.monitor = monitor
        self.helperHostLocator = helperHostLocator
        self.installerResourceLocator = installerResourceLocator
    }

    deinit {
        monitor.stop()
    }

    public func start() {
        guard !isStarted else {
            return
        }

        isStarted = true
        monitor.start { [weak self] events in
            guard let self else {
                return
            }

            let payloads = events.map {
                ProtectionServiceEventPayload(
                    scopeID: $0.scope.id,
                    scopePath: $0.scope.path,
                    detectedArtefactCount: $0.detectedArtefactCount,
                    detectedBytes: $0.detectedBytes,
                    removedCount: $0.applyResult.removedCount,
                    removedBytes: $0.applyResult.removedBytes,
                    status: $0.applyResult.status.rawValue,
                    message: $0.applyResult.message
                )
            }

            Task { @MainActor in
                self.eventHandler?(payloads)
            }
        }
        applyConfiguration()
    }

    public func stop() {
        isStarted = false
        monitor.stop()
        status = inactiveStatus()
    }

    public func updateConfiguration(_ configuration: ProtectionServiceConfiguration) {
        self.configuration = configuration
        applyConfiguration()
    }

    public func evaluateNow() {
        guard configuration.liveProtectionEnabled else {
            return
        }

        monitor.evaluateNow()
    }

    public func setEventHandler(_ handler: @escaping @Sendable ([ProtectionServiceEventPayload]) -> Void) {
        eventHandler = handler
    }

    private func applyConfiguration() {
        let helperPath = helperExecutablePath
        let protectedScopes = configuration.scopes.filter {
            $0.supportStatus == .supported && $0.enforcementMode == .blockKnownArtefacts
        }
        let eventSourceStatus = helperPath == nil
            ? ProtectionEventSourceStatus(
                state: .unavailable,
                detail: "No standalone helper host is bundled in the current build, so Endpoint Security-backed monitoring cannot even begin setup."
            )
            : ProtectionEventSourceStatus(
                state: .needsApproval,
                detail: "A standalone helper host is bundled, but the Endpoint Security system extension install path, Apple entitlement approval, and user authorization flow are still pending."
            )
        let installationStatus = makeInstallationStatus(helperPath: helperPath)

        if !configuration.liveProtectionEnabled {
            status = ProtectionServiceStatusSnapshot(
                mode: .inactive,
                activeProtectedScopeCount: 0,
                detail: helperPath == nil
                    ? "Helper protection is disabled. A packaged helper host is not currently available in this build."
                    : "Helper protection is disabled. A standalone helper host is bundled, but live blocking remains unarmed.",
                helperExecutablePath: helperPath,
                eventSourceState: eventSourceStatus.state,
                eventSourceDescription: eventSourceStatus.detail,
                installationState: installationStatus.state,
                installationDescription: installationStatus.detail
            )
            monitor.updateScopes([])
            return
        }

        if configuration.liveProtectionEnabled && !protectedScopes.isEmpty {
            status = ProtectionServiceStatusSnapshot(
                mode: .embedded,
                activeProtectedScopeCount: protectedScopes.count,
                detail: "Embedded protection is active for \(protectedScopes.count) process-attributed scope(s).",
                helperExecutablePath: helperPath,
                eventSourceState: .ready,
                eventSourceDescription: "Embedded monitoring is only for developer/test paths. True Google-Drive-only blocking still belongs behind the standalone helper and Endpoint Security event source.",
                installationState: installationStatus.state,
                installationDescription: installationStatus.detail
            )
            monitor.updateScopes(protectedScopes)
            return
        }

        status = ProtectionServiceStatusSnapshot(
            mode: helperPath == nil ? .helperRequired : .helperAvailable,
            activeProtectedScopeCount: 0,
            detail: helperPath == nil
                ? "Automatic blocking remains in audit mode until a packaged helper host is available."
                : "A standalone helper host is bundled with this build, but blocking remains audit-only until process-attributed Endpoint Security events are wired.",
            helperExecutablePath: helperPath,
            eventSourceState: eventSourceStatus.state,
            eventSourceDescription: eventSourceStatus.detail,
            installationState: installationStatus.state,
            installationDescription: installationStatus.detail
        )
        monitor.updateScopes([])
    }

    private func inactiveStatus() -> ProtectionServiceStatusSnapshot {
        ProtectionServiceStatusSnapshot(
            mode: .inactive,
            activeProtectedScopeCount: 0,
            detail: "Automatic blocking remains in audit mode until a process-aware helper with Endpoint Security events is available.",
            helperExecutablePath: helperExecutablePath,
            eventSourceState: helperExecutablePath == nil ? .unavailable : .bundled,
            eventSourceDescription: helperExecutablePath == nil
                ? "No standalone helper host is bundled in the current build."
                : "A standalone helper host is bundled, but the live Endpoint Security install and approval path is still pending.",
            installationState: makeInstallationStatus(helperPath: helperExecutablePath).state,
            installationDescription: makeInstallationStatus(helperPath: helperExecutablePath).detail
        )
    }

    private func makeInstallationStatus(helperPath: String?) -> ProtectionInstallationStatus {
        guard helperPath != nil else {
            return ProtectionInstallationStatus(
                state: .unavailable,
                detail: "No standalone helper host is bundled, so there is nothing to install yet."
            )
        }

        if let installResources = installerResourceLocator.locateServiceRegistrationDirectory() {
            return ProtectionInstallationStatus(
                state: .installPlanReady,
                detail: "Helper installation resources are packaged at \(installResources.path), but the actual install/registration flow is not implemented yet."
            )
        }

        return ProtectionInstallationStatus(
            state: .bundledOnly,
            detail: "A helper host is bundled, but no installation resources were found for service registration or system extension setup."
        )
    }
}
