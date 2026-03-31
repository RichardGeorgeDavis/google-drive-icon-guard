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
        eventSourceDescription: "Current helper support is limited to replay/test scaffolding. Live Google-Drive-only blocking still requires a macOS Endpoint Security event source."
    )

    private let monitor: ScopeEnforcementMonitor
    private let helperHostLocator: ProtectionHelperHostLocator
    private var configuration = ProtectionServiceConfiguration(liveProtectionEnabled: false, scopes: [])
    private var eventHandler: (@Sendable ([ProtectionServiceEventPayload]) -> Void)?
    private var isStarted = false

    public init(
        monitor: ScopeEnforcementMonitor = ScopeEnforcementMonitor(),
        helperHostLocator: ProtectionHelperHostLocator = ProtectionHelperHostLocator()
    ) {
        self.monitor = monitor
        self.helperHostLocator = helperHostLocator
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

        if !configuration.liveProtectionEnabled {
            status = ProtectionServiceStatusSnapshot(
                mode: .inactive,
                activeProtectedScopeCount: 0,
                detail: helperPath == nil
                    ? "Helper protection is disabled. A packaged helper host is not currently available in this build."
                    : "Helper protection is disabled. A standalone helper host is bundled, but live blocking remains unarmed.",
                helperExecutablePath: helperPath,
                eventSourceDescription: "Current helper support is limited to replay/test scaffolding. Live Google-Drive-only blocking still requires a macOS Endpoint Security event source."
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
                eventSourceDescription: "Embedded monitoring is only for developer/test paths. True Google-Drive-only blocking still belongs behind the standalone helper and Endpoint Security event source."
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
            eventSourceDescription: "Current helper support is limited to replay/test scaffolding. Live Google-Drive-only blocking still requires a macOS Endpoint Security event source."
        )
        monitor.updateScopes([])
    }

    private func inactiveStatus() -> ProtectionServiceStatusSnapshot {
        ProtectionServiceStatusSnapshot(
            mode: .inactive,
            activeProtectedScopeCount: 0,
            detail: "Automatic blocking remains in audit mode until a process-aware helper with Endpoint Security events is available.",
            helperExecutablePath: helperExecutablePath,
            eventSourceDescription: "Current helper support is limited to replay/test scaffolding. Live Google-Drive-only blocking still requires a macOS Endpoint Security event source."
        )
    }
}
