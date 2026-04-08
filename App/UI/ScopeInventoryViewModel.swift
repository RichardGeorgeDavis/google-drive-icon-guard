import DriveIconGuardIPC
import DriveIconGuardScopeInventory
import DriveIconGuardXPCClient
import DriveIconGuardShared
import Foundation

@MainActor
final class ScopeInventoryViewModel: ObservableObject {
    @Published private(set) var report: ScopeInventoryReport?
    @Published private(set) var storageRootPath: String
    @Published private(set) var persistedPath: String?
    @Published private(set) var recentSnapshots: [PersistedScopeInventorySnapshot] = []
    @Published private(set) var historyComparison: ScopeInventoryHistoryComparison?
    @Published private(set) var activityLog = PersistedActivityLog()
    @Published private(set) var protectionStatus = ProtectionStatusFactory.unavailable()
    @Published private(set) var remediationPreview: ScopeRemediationPreview?
    @Published private(set) var remediationApplyResult: ScopeRemediationApplyResult?
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdatingHelperService = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var helperServiceStatus: ProtectionServiceLaunchdStatus?
    @Published private(set) var helperLifecycleMessage: String?
    @Published private(set) var pendingPermissionRetry = false
    @Published private(set) var liveProtectionEnabled = true

    private let service: ScopeInventoryService
    private var protectionClient: any ProtectionServiceClient
    private let installationStatusResolver: ProtectionInstallationStatusResolver
    private let configurationStore: ProtectionServiceConfigurationStore
    private let registrationConfiguration: ProtectionServiceRegistrationConfiguration
    private let usesInjectedProtectionClient: Bool
    private var automaticPermissionRetryCount = 0
    private var refreshInFlight = false
    private var refreshQueued = false

    init(
        service: ScopeInventoryService = ScopeInventoryService(),
        protectionClient: (any ProtectionServiceClient)? = nil,
        installationStatusResolver: ProtectionInstallationStatusResolver = ProtectionInstallationStatusResolver(),
        configurationStore: ProtectionServiceConfigurationStore = ProtectionServiceConfigurationStore(),
        registrationConfiguration: ProtectionServiceRegistrationConfiguration = .beta
    ) {
        self.service = service
        self.installationStatusResolver = installationStatusResolver
        self.configurationStore = configurationStore
        self.registrationConfiguration = registrationConfiguration
        self.usesInjectedProtectionClient = protectionClient != nil
        let resolvedProtectionClient = protectionClient ?? EmbeddedProtectionServiceClient()
        self.protectionClient = resolvedProtectionClient
        self.storageRootPath = service.storageRootPath()
        if protectionClient == nil {
            self.helperServiceStatus = Self.currentHelperServiceStatus()
            self.protectionClient = Self.makeProtectionClient(
                helperServiceStatus: self.helperServiceStatus,
                registrationConfiguration: registrationConfiguration
            )
        }
        bindProtectionClientEventHandler()
        self.protectionStatus = self.protectionClient.status
        syncProtectionClient()
    }

    func refresh() {
        guard !refreshInFlight else {
            refreshQueued = true
            return
        }

        performRefresh()
    }

    private func performRefresh() {
        refreshInFlight = true
        refreshQueued = false
        isLoading = true
        errorMessage = nil

        let nextReport = service.generateReport()
        var reportToDisplay = nextReport

        do {
            let persistenceResult = try service.persistReport(nextReport)
            let snapshots = try service.loadRecentSnapshots()
            let comparison = historyComparison(for: reportToDisplay, snapshots: snapshots)
            let nextActivityLog = try updatedActivityLog(
                for: reportToDisplay,
                comparison: comparison,
                refreshTargetPath: persistenceResult.latestURL.path
            )

            report = reportToDisplay
            persistedPath = persistenceResult.latestURL.path
            recentSnapshots = snapshots
            historyComparison = comparison
            activityLog = nextActivityLog
            remediationPreview = nil
            pendingPermissionRetry = shouldQueuePermissionRetry(for: reportToDisplay)
            isLoading = false
            updateProtectionConfiguration(for: reportToDisplay)
            finishRefreshCycle()
        } catch {
            reportToDisplay.warnings.append(
                DiscoveryWarning(
                    code: "snapshot_persistence_failed",
                    message: "The inventory loaded, but the app could not persist or reload snapshot history: \(error.localizedDescription)"
                )
            )

            report = reportToDisplay
            persistedPath = nil
            recentSnapshots = []
            historyComparison = nil
            activityLog = PersistedActivityLog()
            remediationPreview = nil
            pendingPermissionRetry = shouldQueuePermissionRetry(for: reportToDisplay)
            errorMessage = nil
            isLoading = false
            updateProtectionConfiguration(for: reportToDisplay)
            finishRefreshCycle()
        }
    }

    private func finishRefreshCycle() {
        refreshInFlight = false
        guard refreshQueued else {
            return
        }

        performRefresh()
    }

    func handleAppDidBecomeActive() {
        guard pendingPermissionRetry, !isLoading else {
            return
        }

        pendingPermissionRetry = false
        automaticPermissionRetryCount += 1
        refresh()
    }

    func clearStoredData() throws {
        try service.clearStoredData()
        report = nil
        persistedPath = nil
        recentSnapshots = []
        historyComparison = nil
        activityLog = PersistedActivityLog()
        remediationPreview = nil
        remediationApplyResult = nil
        pendingPermissionRetry = false
        errorMessage = nil
        updateProtectionConfiguration(for: nil)
    }

    func setLiveProtectionEnabled(_ enabled: Bool) {
        liveProtectionEnabled = enabled
        updateProtectionConfiguration(for: report)
    }

    func refreshHelperServiceStatus() {
        guard !usesInjectedProtectionClient else {
            protectionStatus = protectionClient.status
            return
        }

        helperServiceStatus = Self.currentHelperServiceStatus()
        rebuildProtectionClientIfNeeded()
        syncProtectionClient()
    }

    func installAndStartHelperService() {
        guard !usesInjectedProtectionClient, !isUpdatingHelperService else {
            return
        }

        isUpdatingHelperService = true
        helperLifecycleMessage = nil

        do {
            try configurationStore.persist(currentProtectionConfiguration(for: report))
        } catch {
            helperLifecycleMessage = "Failed to persist helper configuration before install: \(error.localizedDescription)"
            isUpdatingHelperService = false
            return
        }

        Task {
            do {
                let deploymentResult = try await Task.detached {
                    try ProtectionServiceDeploymentCoordinator().installAndBootstrap()
                }.value

                helperServiceStatus = deploymentResult.launchdStatus
                helperLifecycleMessage = deploymentResult.receipt.detail
                isUpdatingHelperService = false
                rebuildProtectionClientIfNeeded()
                syncProtectionClient()
            } catch {
                helperLifecycleMessage = "Failed to install or bootstrap the background helper: \(error.localizedDescription)"
                isUpdatingHelperService = false
                refreshHelperServiceStatus()
            }
        }
    }

    func removeInstalledHelperService() {
        guard !usesInjectedProtectionClient, !isUpdatingHelperService else {
            return
        }

        isUpdatingHelperService = true
        helperLifecycleMessage = nil

        Task {
            do {
                let launchdStatus = try await Task.detached {
                    try ProtectionServiceDeploymentCoordinator().bootoutAndUninstall()
                }.value

                helperServiceStatus = launchdStatus
                helperLifecycleMessage = launchdStatus.detail
                isUpdatingHelperService = false
                rebuildProtectionClientIfNeeded()
                syncProtectionClient()
            } catch {
                helperLifecycleMessage = "Failed to remove the installed background helper: \(error.localizedDescription)"
                isUpdatingHelperService = false
                refreshHelperServiceStatus()
            }
        }
    }

    func reviewPlan(for scope: DriveManagedScope) -> ScopeReviewPlan? {
        guard let report else {
            return nil
        }

        return service.reviewPlan(for: scope, report: report)
    }

    func markdownExport() -> String? {
        guard let report else {
            return nil
        }

        return service.exportMarkdownReport(for: report)
    }

    func markdownExport(for scope: DriveManagedScope) -> String? {
        guard let report else {
            return nil
        }

        return service.exportMarkdownReport(for: report, scopeID: scope.id)
    }

    func prepareDryRunRemediation(for scope: DriveManagedScope) {
        let preview = service.dryRunRemediationPreview(for: scope)
        remediationPreview = preview

        do {
            try appendActivityEvent(
                EventRecord(
                    processSignature: refreshProcessSignature(),
                    scopeID: scope.id,
                    targetPath: scope.path,
                    artefactType: preview.candidates.first?.artefactType ?? .unknown,
                    decision: .auditOnly,
                    aggregatedCount: preview.totalCandidateCount,
                    rawEventType: "remediation_preview"
                )
            )
        } catch {
            // Keep preview available even if activity persistence fails.
        }
    }

    func dryRunRemediationScript(for scope: DriveManagedScope) -> String {
        service.dryRunRemediationScript(for: scope)
    }

    func clearRemediationPreview() {
        remediationPreview = nil
    }

    func applyCleanup(for scope: DriveManagedScope) -> ScopeRemediationApplyResult {
        let result = service.applyCleanup(for: scope)
        remediationApplyResult = result
        remediationPreview = nil

        do {
            try appendActivityEvent(
                EventRecord(
                    processSignature: refreshProcessSignature(),
                    scopeID: scope.id,
                    targetPath: scope.path,
                    artefactType: .unknown,
                    decision: .allow,
                    aggregatedCount: max(result.removedCount, 1),
                    rawEventType: "remediation_apply_\(result.status.rawValue)"
                )
            )
        } catch {
            // Keep the cleanup result visible even if activity persistence fails.
        }

        refresh()
        return result
    }

    private func historyComparison(
        for currentReport: ScopeInventoryReport,
        snapshots: [PersistedScopeInventorySnapshot]
    ) -> ScopeInventoryHistoryComparison? {
        guard let previousSnapshot = snapshots.first(where: { $0.report.generatedAt != currentReport.generatedAt }) else {
            return nil
        }

        return service.compare(current: currentReport, previous: previousSnapshot.report)
    }

    private func updatedActivityLog(
        for report: ScopeInventoryReport,
        comparison: ScopeInventoryHistoryComparison?,
        refreshTargetPath: String
    ) throws -> PersistedActivityLog {
        var activityLog = self.activityLog
        if activityLog.events.isEmpty {
            activityLog = try service.loadActivityLog()
        }
        var events = activityLog.events

        events.append(
            EventRecord(
                timestamp: report.generatedAt,
                processSignature: refreshProcessSignature(),
                scopeID: nil,
                targetPath: refreshTargetPath,
                artefactType: .unknown,
                decision: .auditOnly,
                aggregatedCount: report.artefactInventory.totalArtefactCount,
                rawEventType: "inventory_refresh"
            )
        )

        for scanResult in report.artefactInventory.scopeResults where scanResult.matchedArtefactCount > 0 {
            let artefactType = scanResult.artefactSummaries.first?.artefactType ?? .unknown
            events.append(
                EventRecord(
                    timestamp: report.generatedAt,
                    processSignature: refreshProcessSignature(),
                    scopeID: scanResult.scopeID,
                    targetPath: scanResult.scopePath,
                    artefactType: artefactType,
                    decision: .auditOnly,
                    aggregatedCount: scanResult.matchedArtefactCount,
                    rawEventType: "scope_scan_result"
                )
            )
        }

        if let comparison {
            for change in comparison.delta.perScopeChanges.prefix(10) {
                events.append(
                    EventRecord(
                        timestamp: comparison.currentGeneratedAt,
                        processSignature: refreshProcessSignature(),
                        scopeID: report.scopes.first(where: { $0.path == change.scopePath })?.id,
                        targetPath: change.scopePath,
                        artefactType: .unknown,
                        decision: .auditOnly,
                        aggregatedCount: max(abs(change.artefactDelta), 1),
                        rawEventType: "scope_history_\(change.changeKind.rawValue)"
                    )
                )
            }
        }

        activityLog.events = Array(events.sorted { $0.timestamp > $1.timestamp }.prefix(200))
        try service.persistActivityLog(activityLog)
        return activityLog
    }

    private func appendActivityEvent(_ event: EventRecord) throws {
        var nextActivityLog = activityLog
        nextActivityLog.events.insert(event, at: 0)
        nextActivityLog.events = Array(nextActivityLog.events.prefix(200))
        try service.persistActivityLog(nextActivityLog)
        activityLog = nextActivityLog
    }

    private func shouldQueuePermissionRetry(for report: ScopeInventoryReport) -> Bool {
        guard automaticPermissionRetryCount == 0 else {
            return false
        }

        return combinedWarnings(for: report).contains { $0.code.contains("permission_denied") }
    }

    private func combinedWarnings(for report: ScopeInventoryReport) -> [DiscoveryWarning] {
        report.warnings + report.artefactInventory.warnings
    }

    private func updateProtectionConfiguration(for report: ScopeInventoryReport?) {
        syncProtectionClient(report: report)
    }

    private func currentProtectionConfiguration(for report: ScopeInventoryReport?) -> ProtectionServiceConfiguration {
        ProtectionServiceConfiguration(
            liveProtectionEnabled: liveProtectionEnabled,
            scopes: report?.scopes ?? []
        )
    }

    private func syncProtectionClient(report: ScopeInventoryReport? = nil) {
        let protectionConfiguration = currentProtectionConfiguration(for: report ?? self.report)

        do {
            try configurationStore.persist(protectionConfiguration)
        } catch {
            helperLifecycleMessage = "Failed to persist background helper configuration: \(error.localizedDescription)"
        }

        protectionClient.updateConfiguration(protectionConfiguration)
        if protectionConfiguration.liveProtectionEnabled {
            protectionClient.start()
        } else {
            protectionClient.stop()
        }

        if protectionConfiguration.liveProtectionEnabled {
            protectionClient.evaluateNow()
        }

        protectionStatus = protectionClient.status
    }

    private func bindProtectionClientEventHandler() {
        protectionClient.setEventHandler { [weak self] events in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.handleProtectionEvents(events)
            }
        }
    }

    private func rebuildProtectionClientIfNeeded() {
        guard !usesInjectedProtectionClient else {
            return
        }

        let shouldUseInstalledClient = helperServiceStatus?.isLoaded == true
        let isUsingInstalledClient = protectionClient is XPCProtectionServiceClient

        guard shouldUseInstalledClient != isUsingInstalledClient else {
            return
        }

        protectionClient.stop()
        protectionClient = Self.makeProtectionClient(
            helperServiceStatus: helperServiceStatus,
            registrationConfiguration: registrationConfiguration
        )
        bindProtectionClientEventHandler()
    }

    private static func currentHelperServiceStatus() -> ProtectionServiceLaunchdStatus? {
        try? ProtectionServiceDeploymentCoordinator().status()
    }

    private static func makeProtectionClient(
        helperServiceStatus: ProtectionServiceLaunchdStatus?,
        registrationConfiguration: ProtectionServiceRegistrationConfiguration
    ) -> any ProtectionServiceClient {
        if helperServiceStatus?.isLoaded == true {
            return XPCProtectionServiceClient(machServiceName: registrationConfiguration.machServiceName)
        }

        return EmbeddedProtectionServiceClient()
    }

    private func handleProtectionEvents(_ events: [ProtectionServiceEventPayload]) {
        guard !events.isEmpty else {
            return
        }

        var requiresRefresh = false

        for event in events {
            remediationApplyResult = ScopeRemediationApplyResult(
                scopeID: event.scopeID,
                scopeDisplayName: report?.scopes.first(where: { $0.id == event.scopeID })?.displayName ?? URL(fileURLWithPath: event.scopePath).lastPathComponent,
                scopePath: event.scopePath,
                status: ScopeRemediationApplyStatus(rawValue: event.status.rawValue) ?? .partialFailure,
                message: event.message,
                removedCount: event.removedCount,
                removedBytes: event.removedBytes
            )
            requiresRefresh = requiresRefresh || event.removedCount > 0

            do {
                try appendActivityEvent(
                    EventRecord(
                        processSignature: ProcessSignature(
                            bundleID: Bundle.main.bundleIdentifier,
                            executablePath: Bundle.main.executableURL?.path ?? ProcessInfo.processInfo.arguments.first ?? "drive-icon-guard-viewer",
                            signingIdentity: nil,
                            displayName: "Drive Icon Guard Protection Monitor",
                            isGoogleDriveRelated: false
                        ),
                        scopeID: event.scopeID,
                        targetPath: event.scopePath,
                        artefactType: .unknown,
                        decision: event.removedCount > 0 ? .deny : .auditOnly,
                        aggregatedCount: max(event.detectedArtefactCount, 1),
                        rawEventType: "live_protection_\(event.status.rawValue)"
                    )
                )
            } catch {
                // Keep monitoring even if activity persistence fails.
            }
        }

        if requiresRefresh && !isLoading {
            performRefresh()
        }
    }

    private func refreshProcessSignature() -> ProcessSignature {
        ProcessSignature(
            bundleID: Bundle.main.bundleIdentifier,
            executablePath: Bundle.main.executableURL?.path ?? ProcessInfo.processInfo.arguments.first ?? "drive-icon-guard-viewer",
            signingIdentity: nil,
            displayName: "Google Drive Icon Guard",
            isGoogleDriveRelated: false
        )
    }
}
