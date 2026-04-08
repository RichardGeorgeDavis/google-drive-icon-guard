import DriveIconGuardIPC
import DriveIconGuardScopeInventory
import DriveIconGuardXPCClient
import DriveIconGuardShared
import Foundation

@MainActor
final class ScopeInventoryViewModel: ObservableObject {
    private struct ProtectionClientResolution {
        let client: any ProtectionServiceClient
        let fallbackDetail: String?
    }

    @Published private(set) var report: ScopeInventoryReport?
    @Published private(set) var storageRootPath: String
    @Published private(set) var persistedPath: String?
    @Published private(set) var recentSnapshots: [PersistedScopeInventorySnapshot] = []
    @Published private(set) var historyComparison: ScopeInventoryHistoryComparison?
    @Published private(set) var activityLog = PersistedActivityLog()
    @Published private(set) var protectionStatus = ProtectionStatusFactory.unavailable()
    @Published private(set) var remediationPreview: ScopeRemediationPreview?
    @Published private(set) var remediationApplyResult: ScopeRemediationApplyResult?
    @Published private(set) var aggregateCleanupPreview: AggregateCleanupPreview?
    @Published private(set) var aggregateCleanupApplyResult: AggregateCleanupApplyResult?
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
            let resolution = Self.makeProtectionClient(
                helperServiceStatus: self.helperServiceStatus,
                registrationConfiguration: registrationConfiguration
            )
            self.protectionClient = resolution.client
            self.helperLifecycleMessage = resolution.fallbackDetail
        }
        bindProtectionClientEventHandler()
        self.protectionStatus = augmentedProtectionStatus(from: self.protectionClient.status)
        syncProtectionClient()
        if let helperLifecycleMessage {
            recordActivityEvent(
                helperEvent(
                    message: helperLifecycleMessage,
                    rawEventType: "helper_startup_notice",
                    severity: .warning
                )
            )
        }
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
            remediationApplyResult = nil
            aggregateCleanupPreview = nil
            aggregateCleanupApplyResult = nil
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
            remediationApplyResult = nil
            aggregateCleanupPreview = nil
            aggregateCleanupApplyResult = nil
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
        aggregateCleanupPreview = nil
        aggregateCleanupApplyResult = nil
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
            protectionStatus = augmentedProtectionStatus(from: protectionClient.status)
            return
        }

        helperServiceStatus = Self.currentHelperServiceStatus()
        rebuildProtectionClientIfNeeded()
        syncProtectionClient()

        if let helperServiceStatus, !helperServiceStatus.isLoaded {
            recordActivityEvent(
                helperEvent(
                    message: helperServiceStatus.detail,
                    rawEventType: "helper_status_refresh_not_loaded",
                    severity: .warning
                )
            )
        }
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
            recordActivityEvent(
                helperEvent(
                    message: helperLifecycleMessage ?? error.localizedDescription,
                    rawEventType: "helper_install_configuration_failed",
                    severity: .error
                )
            )
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
                recordActivityEvent(
                    helperEvent(
                        message: deploymentResult.receipt.detail,
                        rawEventType: deploymentResult.receipt.state == .installed ? "helper_install_completed" : "helper_install_failed",
                        severity: deploymentResult.receipt.state == .installed ? .info : .error
                    )
                )
            } catch {
                helperLifecycleMessage = "Failed to install or bootstrap the background helper: \(error.localizedDescription)"
                isUpdatingHelperService = false
                refreshHelperServiceStatus()
                recordActivityEvent(
                    helperEvent(
                        message: helperLifecycleMessage ?? error.localizedDescription,
                        rawEventType: "helper_install_failed",
                        severity: .error
                    )
                )
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
                recordActivityEvent(
                    helperEvent(
                        message: launchdStatus.detail,
                        rawEventType: "helper_remove_completed",
                        severity: .info
                    )
                )
            } catch {
                helperLifecycleMessage = "Failed to remove the installed background helper: \(error.localizedDescription)"
                isUpdatingHelperService = false
                refreshHelperServiceStatus()
                recordActivityEvent(
                    helperEvent(
                        message: helperLifecycleMessage ?? error.localizedDescription,
                        rawEventType: "helper_remove_failed",
                        severity: .error
                    )
                )
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
        aggregateCleanupPreview = nil
        aggregateCleanupApplyResult = nil

        recordActivityEvent(
            EventRecord(
                processSignature: refreshProcessSignature(),
                scopeID: scope.id,
                targetPath: scope.path,
                artefactType: preview.candidates.first?.artefactType ?? .unknown,
                decision: .auditOnly,
                aggregatedCount: preview.totalCandidateCount,
                rawEventType: "remediation_preview",
                message: preview.recommendedAction,
                category: .cleanup,
                severity: preview.status == .ready ? .info : .warning
            )
        )
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
        aggregateCleanupPreview = nil
        aggregateCleanupApplyResult = nil

        recordActivityEvent(cleanupEvent(for: result, rawEventType: "remediation_apply_\(result.status.rawValue)"))

        refresh()
        return result
    }

    func prepareAggregateCleanup() -> AggregateCleanupPreview? {
        guard let report else {
            return nil
        }

        let candidateScopeIDs = Set(
            report.artefactInventory.scopeResults
                .filter { $0.matchedArtefactCount > 0 }
                .map(\.scopeID)
        )
        let supportedScopes = report.scopes.filter {
            $0.supportStatus == .supported && candidateScopeIDs.contains($0.id)
        }

        var readyPreviews: [ScopeRemediationPreview] = []
        var skippedScopeNames: [String] = []
        var warnings: [DiscoveryWarning] = []

        for scope in supportedScopes {
            let preview = service.dryRunRemediationPreview(for: scope)
            switch preview.status {
            case .ready where preview.totalCandidateCount > 0:
                readyPreviews.append(preview)
            default:
                skippedScopeNames.append(scope.displayName)
                warnings.append(
                    DiscoveryWarning(
                        code: "aggregate_cleanup_skipped_\(preview.status.rawValue)",
                        message: "\(scope.displayName) was skipped during aggregate cleanup preview because its remediation status was \(preview.status.rawValue)."
                    )
                )
            }

            warnings.append(contentsOf: preview.warnings)
        }

        let preview = AggregateCleanupPreview(
            affectedScopeCount: readyPreviews.count,
            skippedScopeCount: skippedScopeNames.count,
            totalCandidateCount: readyPreviews.reduce(0) { $0 + $1.totalCandidateCount },
            totalBytes: readyPreviews.reduce(0) { $0 + $1.totalBytes },
            readyScopePreviews: readyPreviews,
            skippedScopeNames: skippedScopeNames,
            warnings: warnings
        )

        aggregateCleanupPreview = preview
        aggregateCleanupApplyResult = nil
        remediationPreview = nil
        remediationApplyResult = nil

        recordActivityEvent(
            EventRecord(
                processSignature: refreshProcessSignature(),
                scopeID: nil,
                targetPath: persistedPath ?? storageRootPath,
                artefactType: .unknown,
                decision: .auditOnly,
                aggregatedCount: preview.totalCandidateCount,
                rawEventType: "remediation_preview_all",
                message: "Prepared aggregate cleanup preview across \(preview.affectedScopeCount) supported scope(s).",
                category: .cleanup,
                severity: preview.affectedScopeCount > 0 ? .info : .warning
            )
        )

        for warning in warnings {
            recordActivityEvent(warningEvent(warning, timestamp: preview.generatedAt))
        }

        return preview
    }

    func applyAggregateCleanup() -> AggregateCleanupApplyResult? {
        guard let aggregateCleanupPreview, let report else {
            return nil
        }

        let scopesByID = Dictionary(uniqueKeysWithValues: report.scopes.map { ($0.id, $0) })
        var results: [ScopeRemediationApplyResult] = []
        var warnings = aggregateCleanupPreview.warnings

        for preview in aggregateCleanupPreview.readyScopePreviews {
            guard let scope = scopesByID[preview.scopeID] else {
                warnings.append(
                    DiscoveryWarning(
                        code: "aggregate_cleanup_missing_scope",
                        message: "The scope \(preview.scopeDisplayName) was no longer available when aggregate cleanup was applied."
                    )
                )
                continue
            }

            let result = service.applyCleanup(for: scope)
            results.append(result)
            warnings.append(contentsOf: result.warnings)
            recordActivityEvent(cleanupEvent(for: result, rawEventType: "remediation_apply_all_\(result.status.rawValue)"))
        }

        let aggregateResult = AggregateCleanupApplyResult(
            processedScopeCount: aggregateCleanupPreview.readyScopePreviews.count,
            appliedScopeCount: results.filter { $0.status == .applied }.count,
            removedCount: results.reduce(0) { $0 + $1.removedCount },
            removedBytes: results.reduce(0) { $0 + $1.removedBytes },
            results: results,
            warnings: warnings
        )

        aggregateCleanupApplyResult = aggregateResult
        remediationPreview = nil
        remediationApplyResult = results.last
        self.aggregateCleanupPreview = nil

        if aggregateResult.removedCount > 0 && !isLoading {
            refresh()
        }

        return aggregateResult
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
                rawEventType: "inventory_refresh",
                message: "Recorded \(report.artefactInventory.totalArtefactCount) total artefact match(es) in the latest refresh.",
                category: .inventory,
                severity: .info
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
                    rawEventType: "scope_scan_result",
                    message: "Matched \(scanResult.matchedArtefactCount) artefact(s) at \(scanResult.scopePath).",
                    category: .inventory,
                    severity: .warning
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
                        rawEventType: "scope_history_\(change.changeKind.rawValue)",
                        message: "Detected a scope-level history change at \(change.scopePath).",
                        category: .inventory,
                        severity: .info
                    )
                )
            }
        }

        for warning in combinedWarnings(for: report).prefix(12) {
            events.append(warningEvent(warning, timestamp: report.generatedAt))
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
            recordActivityEvent(
                helperEvent(
                    message: helperLifecycleMessage ?? error.localizedDescription,
                    rawEventType: "helper_configuration_persist_failed",
                    severity: .error
                )
            )
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

        protectionStatus = augmentedProtectionStatus(from: protectionClient.status)
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
        let resolution = Self.makeProtectionClient(
            helperServiceStatus: helperServiceStatus,
            registrationConfiguration: registrationConfiguration
        )
        protectionClient = resolution.client
        if let fallbackDetail = resolution.fallbackDetail {
            helperLifecycleMessage = fallbackDetail
            recordActivityEvent(
                helperEvent(
                    message: fallbackDetail,
                    rawEventType: "helper_transport_fallback",
                    severity: .error
                )
            )
        }
        bindProtectionClientEventHandler()
    }

    private static func currentHelperServiceStatus() -> ProtectionServiceLaunchdStatus? {
        try? ProtectionServiceDeploymentCoordinator().status()
    }

    private static func makeProtectionClient(
        helperServiceStatus: ProtectionServiceLaunchdStatus?,
        registrationConfiguration: ProtectionServiceRegistrationConfiguration
    ) -> ProtectionClientResolution {
        if helperServiceStatus?.isLoaded == true {
            let installedClient = XPCProtectionServiceClient(machServiceName: registrationConfiguration.machServiceName)
            if installedClient.isReachable {
                return ProtectionClientResolution(client: installedClient, fallbackDetail: nil)
            }

            let fallbackDetail = installedClient.lastTransportFailureDetail
                ?? "The installed background helper is loaded in launchd, but its XPC service is not responding. Falling back to embedded audit-mode protection."
            return ProtectionClientResolution(
                client: EmbeddedProtectionServiceClient(),
                fallbackDetail: fallbackDetail
            )
        }

        return ProtectionClientResolution(
            client: EmbeddedProtectionServiceClient(),
            fallbackDetail: nil
        )
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
                    rawEventType: "live_protection_\(event.status.rawValue)",
                    message: event.message,
                    category: .protection,
                    severity: event.removedCount > 0 ? .warning : .info
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

    private func augmentedProtectionStatus(from base: ProtectionServiceStatusSnapshot) -> ProtectionServiceStatusSnapshot {
        ProtectionHelperBuildInfoResolver.augment(
            base,
            launchdStatus: helperServiceStatus,
            receiptLocator: installationStatusResolver.installationReceiptLocator
        )
    }

    private func recordActivityEvent(_ event: EventRecord) {
        do {
            try appendActivityEvent(event)
        } catch {
            // Keep UI state responsive even if activity persistence fails.
        }
    }

    private func helperEvent(
        message: String,
        rawEventType: String,
        severity: ActivitySeverity
    ) -> EventRecord {
        EventRecord(
            processSignature: refreshProcessSignature(),
                targetPath: helperServiceStatus?.serviceTarget ?? supportPathForHelperEvent(),
                artefactType: .unknown,
                decision: severity == .error ? .deny : .auditOnly,
                aggregatedCount: 1,
                rawEventType: rawEventType,
                message: message,
                category: .helper,
                severity: severity
        )
    }

    private func warningEvent(_ warning: DiscoveryWarning, timestamp: Date) -> EventRecord {
        EventRecord(
            timestamp: timestamp,
            processSignature: refreshProcessSignature(),
            targetPath: persistedPath ?? storageRootPath,
            artefactType: .unknown,
            decision: .auditOnly,
            aggregatedCount: 1,
            rawEventType: "warning_\(warning.code)",
            message: warning.message,
            category: .warning,
            severity: warning.code.localizedCaseInsensitiveContains("permission") ? .error : .warning
        )
    }

    private func cleanupEvent(
        for result: ScopeRemediationApplyResult,
        rawEventType: String
    ) -> EventRecord {
        EventRecord(
            processSignature: refreshProcessSignature(),
            scopeID: result.scopeID,
            targetPath: result.scopePath,
            artefactType: .unknown,
            decision: result.removedCount > 0 ? .allow : .auditOnly,
            aggregatedCount: max(result.removedCount, 1),
            rawEventType: rawEventType,
            message: result.message,
            category: .cleanup,
            severity: result.status == .partialFailure || result.status == .unreadable ? .warning : .info
        )
    }

    private func supportPathForHelperEvent() -> String {
        helperServiceStatus?.serviceTarget ?? storageRootPath
    }
}
