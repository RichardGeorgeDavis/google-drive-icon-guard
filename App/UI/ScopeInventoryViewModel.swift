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
    @Published private(set) var protectionStatus = ProtectionServiceStatusSnapshot(
        mode: .inactive,
        activeProtectedScopeCount: 0,
        detail: "Automatic blocking remains in audit mode until a process-aware helper with Endpoint Security events is available.",
        eventSourceState: .unavailable,
        eventSourceDescription: "Current helper support is limited to replay/test scaffolding. Live Google-Drive-only blocking still requires a macOS Endpoint Security event source.",
        installationState: .unavailable,
        installationDescription: "No helper installation resources are available in this build."
    )
    @Published private(set) var remediationPreview: ScopeRemediationPreview?
    @Published private(set) var remediationApplyResult: ScopeRemediationApplyResult?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var pendingPermissionRetry = false
    @Published private(set) var liveProtectionEnabled = true

    private let service: ScopeInventoryService
    private let protectionClient: any ProtectionServiceClient
    private var automaticPermissionRetryCount = 0

    init(
        service: ScopeInventoryService = ScopeInventoryService(),
        protectionClient: (any ProtectionServiceClient)? = nil
    ) {
        self.service = service
        let resolvedProtectionClient = protectionClient ?? EmbeddedProtectionServiceClient()
        self.protectionClient = resolvedProtectionClient
        self.storageRootPath = service.storageRootPath()
        self.protectionStatus = resolvedProtectionClient.status

        resolvedProtectionClient.setEventHandler { [weak self] events in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.handleProtectionEvents(events)
            }
        }
        resolvedProtectionClient.start()
    }

    func refresh() {
        performRefresh()
    }

    private func performRefresh() {
        isLoading = true
        errorMessage = nil

        let nextReport = service.generateReport()
        var reportToDisplay = nextReport

        do {
            let persistenceResult = try service.persistReport(nextReport)
            let snapshots = try service.loadRecentSnapshots()
            let comparison = historyComparison(for: reportToDisplay, snapshots: snapshots)
            let nextActivityLog = try updatedActivityLog(for: reportToDisplay, comparison: comparison)

            report = reportToDisplay
            persistedPath = persistenceResult.latestURL.path
            recentSnapshots = snapshots
            historyComparison = comparison
            activityLog = nextActivityLog
            remediationPreview = nil
            pendingPermissionRetry = shouldQueuePermissionRetry(for: reportToDisplay)
            isLoading = false
            updateProtectionConfiguration(for: reportToDisplay)
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
        }
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

        if enabled {
            protectionClient.evaluateNow()
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
        comparison: ScopeInventoryHistoryComparison?
    ) throws -> PersistedActivityLog {
        var activityLog = try service.loadActivityLog()
        var events = activityLog.events

        events.append(
            EventRecord(
                timestamp: report.generatedAt,
                processSignature: refreshProcessSignature(),
                scopeID: nil,
                targetPath: persistedPath ?? "scope-inventory",
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
        var activityLog = try service.loadActivityLog()
        activityLog.events.insert(event, at: 0)
        activityLog.events = Array(activityLog.events.prefix(200))
        try service.persistActivityLog(activityLog)
        self.activityLog = activityLog
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
        protectionClient.updateConfiguration(
            ProtectionServiceConfiguration(
                liveProtectionEnabled: liveProtectionEnabled,
                scopes: report?.scopes ?? []
            )
        )
        protectionStatus = protectionClient.status
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
                status: ScopeRemediationApplyStatus(rawValue: event.status) ?? .partialFailure,
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
                        rawEventType: "live_protection_\(event.status)"
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
