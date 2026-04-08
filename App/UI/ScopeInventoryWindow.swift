import DriveIconGuardIPC
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import AppKit
import SwiftUI

private enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case history
    case logs
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .history:
            return "History"
        case .logs:
            return "Logs"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "externaldrive.connected.to.line.below"
        case .history:
            return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .logs:
            return "text.justify.left"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

private struct ActivityItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let timestamp: Date?
    let category: ActivityCategory
    let severity: ActivitySeverity
    let scopePath: String?
}

private enum ActivityFilter: String, CaseIterable, Identifiable {
    case all
    case helper
    case cleanup
    case protection
    case warnings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .helper:
            return "Helper"
        case .cleanup:
            return "Cleanup"
        case .protection:
            return "Protection"
        case .warnings:
            return "Warnings"
        }
    }

    var category: ActivityCategory? {
        switch self {
        case .all:
            return nil
        case .helper:
            return .helper
        case .cleanup:
            return .cleanup
        case .protection:
            return .protection
        case .warnings:
            return .warning
        }
    }
}

struct ScopeInventoryWindow: View {
    @AppStorage("scopeInventory.historyLimit") private var historyLimit = 6
    @AppStorage("scopeInventory.showSampleMatches") private var showSampleMatches = true
    @AppStorage("scopeInventory.liveProtectionEnabled") private var liveProtectionEnabled = true

    private let supportDiagnostics = AppSupportDiagnostics.current()
    @StateObject private var viewModel = ScopeInventoryViewModel()
    @State private var selection: AppSection? = .dashboard
    @State private var selectedScopeID: UUID?
    @State private var exportMessage: String?
    @State private var supportMessage: String?
    @State private var activityFilter: ActivityFilter = .all

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 1120, minHeight: 700)
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.refresh()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
            }

            ToolbarItem {
                Button {
                    exportFindings()
                } label: {
                    Label("Export Findings", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.report == nil)
            }
        }
        .task {
            viewModel.setLiveProtectionEnabled(liveProtectionEnabled)
            if viewModel.report == nil {
                viewModel.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.handleAppDidBecomeActive()
        }
        .onChange(of: liveProtectionEnabled) { enabled in
            viewModel.setLiveProtectionEnabled(enabled)
        }
        .onChange(of: viewModel.report?.generatedAt) { _ in
            ensureSelectedScope()
        }
    }

    private var sidebar: some View {
        List(AppSection.allCases, selection: $selection) { section in
            Label(section.title, systemImage: section.systemImage)
                .tag(section)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .dashboard {
        case .dashboard:
            dashboardSection
        case .history:
            historySection
        case .logs:
            logsSection
        case .settings:
            settingsSection
        }
    }

    private var dashboardSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: "Google Drive Icon Guard",
                    subtitle: "Confirm the detected locations, review current artefacts, and take action from one place."
                )

                buildSupportPanel
                liveProtectionPanel
                stats
                journeySection
                recentActivitySection
                aggregateCleanupSection
                permissionRetryNotice
                inventoryReviewSection
                warningsSection
                historyComparisonSection
                privacyGuidancePanel

                if let exportMessage {
                    inlineNotice(title: "Export", systemImage: "square.and.arrow.up", message: exportMessage)
                }

                if let supportMessage {
                    inlineNotice(title: "Support", systemImage: "lifepreserver", message: supportMessage)
                }

                if let persistedPath = viewModel.persistedPath {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Latest persisted snapshot")
                            .font(.headline)
                        Text(persistedPath)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Dashboard")
    }

    private var historySection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: "Snapshot History",
                    subtitle: "Recent persisted inventory snapshots and the current delta against the last snapshot."
                )

                historyComparisonSection
                historyChangeSection
                recentHistorySection(limit: historyLimit)
            }
            .padding(20)
        }
        .navigationTitle("History")
    }

    private var logsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: "Logs",
                    subtitle: "Review-oriented activity feed derived from scans, warnings, and snapshot history."
                )
                activityFilterSection
                activityFeedSection
            }
            .padding(20)
        }
        .navigationTitle("Logs")
    }

    private var settingsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: "Settings",
                    subtitle: "Viewer preferences for review workflows in the current beta app."
                )

                privacyGuidancePanel
                liveProtectionPanel
                settingsPanel
            }
            .padding(20)
        }
        .navigationTitle("Settings")
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private var buildSupportPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Build and Support", systemImage: "hammer")
                .font(.headline)

            Text("Running from \(buildSourceLabel). Use this summary when reporting beta issues or helper startup failures.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                badge(supportDiagnostics.versionLine, tint: .blue)
                if let releaseTag = supportDiagnostics.releaseTag {
                    badge("tag \(releaseTag)", tint: .teal)
                }
                if let gitCommit = supportDiagnostics.gitCommit {
                    badge("commit \(gitCommit)", tint: .gray)
                }
                badge(supportDiagnostics.signingStatus.lowercased(), tint: signingTintColor)
                badge(supportDiagnostics.notarizationStatus.lowercased(), tint: notarizationTintColor)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                metadataLabel("Running From", value: buildSourceLabel)
                metadataLabel("Last Refresh", value: lastRefreshLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(supportDiagnostics.bundlePath)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            supportActionButtons(includeLoginItems: liveProtectionNeedsAttention)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var stats: some View {
        let report = viewModel.report
        let scopes = report?.scopes ?? []
        let artefactInventory = report?.artefactInventory

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                statCard(title: "Scopes", value: "\(scopes.count)")
                statCard(title: "Supported", value: "\(scopes.filter { $0.supportStatus == .supported }.count)")
                statCard(title: "Audit Only", value: "\(scopes.filter { $0.supportStatus == .auditOnly }.count)")
                statCard(title: "Artefacts", value: "\(artefactInventory?.totalArtefactCount ?? 0)")
                statCard(title: "Disk Impact", value: formattedByteCount(artefactInventory?.totalBytes ?? 0))
            }

            Text("Last refreshed: \(lastRefreshLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Current review path")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                journeyStep(
                    title: "1. Confirm locations",
                    detail: "\(detectedScopeSummary) detected from Google Drive state.",
                    status: viewModel.report == nil ? "Loading" : "Ready"
                )
                journeyStep(
                    title: "2. Review findings",
                    detail: findingsSummary,
                    status: findingsStatus
                )
                journeyStep(
                    title: "3. Take action",
                    detail: actionSummary,
                    status: actionStatus
                )
            }

            HStack(spacing: 12) {
                Button("Refresh Scan") {
                    viewModel.refresh()
                }

                Button("Export Findings") {
                    exportFindings()
                }
                .disabled(viewModel.report == nil)

                Button(aggregateCleanupButtonTitle) {
                    startAggregateCleanupJourney()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasSupportedCleanupCandidates)

                Button("Reveal App Data") {
                    revealStorageRoot()
                }
            }

            Text(aggregateCleanupHelperText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Button("Open Logs") {
                    selection = .logs
                }
            }

            if !recentActivityItems.isEmpty {
                VStack(spacing: 10) {
                    ForEach(recentActivityItems) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Label(item.title, systemImage: item.systemImage)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(item.tint)
                                Spacer()
                                if let timestamp = item.timestamp {
                                    Text(formattedTimestamp(timestamp))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 12) {
                                Button("Open Logs") {
                                    selection = .logs
                                }
                                .buttonStyle(.link)

                                if let scopePath = item.scopePath {
                                    Button("Review Scope") {
                                        reviewScope(atPath: scopePath)
                                    }
                                    .buttonStyle(.link)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else {
                emptyState(
                    title: "No recent activity",
                    systemImage: "clock.badge.exclamationmark",
                    description: "Helper, cleanup, and protection activity will appear here once the app has refreshed or taken action."
                )
            }
        }
    }

    private var aggregateCleanupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supported Cleanup")
                .font(.headline)

            if let preview = viewModel.aggregateCleanupPreview {
                aggregateCleanupPreviewPanel(preview)
            } else if let result = viewModel.aggregateCleanupApplyResult {
                aggregateCleanupResultPanel(result)
            } else {
                Text("Use Run Cleanup to prepare one dry-run summary across all supported scopes with current artefacts.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var activityFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filter")
                .font(.headline)

            Picker("Activity Filter", selection: $activityFilter) {
                ForEach(ActivityFilter.allCases) { filter in
                    Text(filter.title)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var scopesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Discovered Scopes")
                .font(.headline)

            if let errorMessage = viewModel.errorMessage {
                emptyState(
                    title: "Load failed",
                    systemImage: "exclamationmark.triangle",
                    description: errorMessage
                )
            } else if let report = viewModel.report, !report.scopes.isEmpty {
                VStack(spacing: 10) {
                    ForEach(report.scopes) { scope in
                        Button {
                            selectedScopeID = scope.id
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center) {
                                Text(scope.displayName)
                                    .font(.headline)

                                Spacer()

                                badge(scope.driveMode.rawValue, tint: driveModeColor(scope.driveMode))
                                badge(scope.supportStatus.rawValue, tint: supportStatusColor(scope.supportStatus))
                                badge(scope.source.rawValue, tint: .gray.opacity(0.7))
                            }

                            Text(scope.path)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)

                            HStack(spacing: 10) {
                                metadataLabel("Scope", value: scope.scopeKind.rawValue)
                                metadataLabel("Volume", value: scope.volumeKind.rawValue)
                                metadataLabel("Filesystem", value: scope.fileSystemKind.rawValue)
                                metadataLabel("Confidence", value: scopeConfidenceLabel(scope.source))
                                if let accountID = scope.accountID, !accountID.isEmpty {
                                    metadataLabel("Account", value: accountID)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let scanResult = artefactScanResult(for: scope) {
                                Divider()

                                HStack(spacing: 10) {
                                    badge(scanStatusLabel(scanResult.scanStatus), tint: scanStatusColor(scanResult.scanStatus))
                                    metadataLabel("Matches", value: "\(scanResult.matchedArtefactCount)")
                                    metadataLabel("Disk Impact", value: formattedByteCount(scanResult.matchedBytes))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                if scanResult.scanStatus == .scanned {
                                    Text(scanCoverageText(for: scanResult))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if showSampleMatches, !scanResult.sampleMatches.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Sample matches")
                                            .font(.caption.weight(.semibold))

                                        ForEach(scanResult.sampleMatches) { sample in
                                            HStack(alignment: .top, spacing: 8) {
                                                Text(sample.relativePath)
                                                    .font(.system(.caption, design: .monospaced))
                                                    .textSelection(.enabled)
                                                Spacer(minLength: 12)
                                                VStack(alignment: .trailing, spacing: 4) {
                                                    Text(sample.ruleName)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)

                                                    Button("Reveal") {
                                                        revealMatchInFinder(scopePath: scope.path, relativePath: sample.relativePath)
                                                    }
                                                    .font(.caption)
                                                    .buttonStyle(.link)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(cardBackground(for: scope), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selectedScopeID == scope.id ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if viewModel.isLoading {
                emptyState(
                    title: "Loading inventory",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                emptyState(
                    title: "No scopes discovered",
                    systemImage: "externaldrive.badge.questionmark"
                )
            }
        }
    }

    private var inventoryReviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            scopesSection

            if let scope = selectedScope, let plan = viewModel.reviewPlan(for: scope) {
                scopeDetailSection(scope: scope, plan: plan)
            } else if let report = viewModel.report, report.scopes.isEmpty == false {
                emptyState(
                    title: "Select a scope",
                    systemImage: "sidebar.left",
                    description: "Choose a discovered scope to review rationale, findings, and the recommended next step."
                )
            }
        }
    }

    private var warningsSection: some View {
        let warnings = combinedWarnings

        return VStack(alignment: .leading, spacing: 10) {
            Text("Warnings")
                .font(.headline)

            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(warnings.enumerated()), id: \.offset) { entry in
                        let warning = entry.element
                        VStack(alignment: .leading, spacing: 4) {
                            Text(warning.code)
                                .font(.subheadline.weight(.semibold))
                            Text(warning.message)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            } else {
                Text("No warnings were returned in the latest report.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scopeDetailSection(scope: DriveManagedScope, plan: ScopeReviewPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scope review")
                        .font(.headline)
                    Text(scope.displayName)
                        .font(.title3.weight(.semibold))
                }

                Spacer()

                badge(plan.priority.rawValue, tint: reviewPriorityColor(plan.priority))
            }

            Text(plan.headline)
                .font(.headline)

            Text(plan.recommendedAction)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                metadataLabel("Source", value: scope.source.rawValue)
                metadataLabel("Confidence", value: scopeConfidenceLabel(scope.source))
                metadataLabel("Support", value: scope.supportStatus.rawValue)
                metadataLabel("Volume", value: scope.volumeKind.rawValue)
                metadataLabel("Filesystem", value: scope.fileSystemKind.rawValue)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            primaryScopeActionBar(scope: scope)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Why this scope is in this bucket")
                    .font(.subheadline.weight(.semibold))

                ForEach(plan.rationale, id: \.self) { reason in
                    Label(reason, systemImage: "checkmark.seal")
                        .foregroundStyle(.secondary)
                }
            }

            if !plan.operatorNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Operator notes")
                        .font(.subheadline.weight(.semibold))

                    ForEach(plan.operatorNotes, id: \.self) { note in
                        Label(note, systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let scanResult = artefactScanResult(for: scope) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scan coverage")
                        .font(.subheadline.weight(.semibold))

                    if scanResult.scanStatus == .scanned {
                        HStack(spacing: 10) {
                            metadataLabel("Directories", value: "\(scanResult.scannedDirectoryCount)")
                            metadataLabel("Files Inspected", value: "\(scanResult.inspectedFileCount)")
                            metadataLabel("Symlinks Skipped", value: "\(scanResult.skippedSymbolicLinkCount)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("This scope was scanned recursively from the displayed root path. Nested subfolders are included; symbolic links are skipped to avoid double-counting or traversing outside the scope boundary.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Coverage details are only available when the latest scan completed successfully.")
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Artefact breakdown")
                        .font(.subheadline.weight(.semibold))

                    if !scanResult.artefactSummaries.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(scanResult.artefactSummaries) { summary in
                                HStack {
                                    Text(artefactTypeLabel(summary.artefactType))
                                    Spacer()
                                    Text("\(summary.count)")
                                        .foregroundStyle(.secondary)
                                    Text(formattedByteCount(summary.totalBytes))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                            }
                        }
                    } else {
                        Text("No type breakdown is available because the latest scan found no artefacts.")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            remediationSection(for: scope)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func primaryScopeActionBar(scope: DriveManagedScope) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actions")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                Button(primaryCleanupButtonTitle(for: scope)) {
                    startCleanupJourney(for: scope)
                }
                .buttonStyle(.borderedProminent)
                .disabled(scope.supportStatus != .supported)

                Button("Preview Dry Run") {
                    viewModel.prepareDryRunRemediation(for: scope)
                }
                .disabled(scope.supportStatus != .supported)

                Button("Reveal Scope") {
                    revealInFinder(path: scope.path)
                }

                Button("Export Scope Findings") {
                    exportScopeFindings(scope)
                }
            }

            HStack(spacing: 12) {
                if let persistedPath = viewModel.persistedPath {
                    Button("Reveal Snapshot") {
                        revealInFinder(path: persistedPath)
                    }
                }

                Button("Export Full Findings") {
                    exportFindings()
                }
            }

            Text(primaryCleanupHelperText(for: scope))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func remediationSection(for scope: DriveManagedScope) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dry-run remediation")
                        .font(.headline)
                    Text("Supported scopes can generate a candidate cleanup preview without touching the filesystem.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if scope.supportStatus == .supported {
                HStack(spacing: 12) {
                    Button("Export Dry-Run Script") {
                        exportDryRunScript(for: scope)
                    }
                }

                if let preview = selectedRemediationPreview(for: scope) {
                    remediationPreviewPanel(preview)
                } else {
                    Text("Use the action bar above to prepare cleanup. The preview will appear here before any deletion is confirmed.")
                        .foregroundStyle(.secondary)
                }

                if let result = selectedRemediationApplyResult(for: scope) {
                    remediationApplyResultPanel(result)
                }
            } else {
                Text("Dry-run remediation is only available for scopes currently marked as supported.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func remediationPreviewPanel(_ preview: ScopeRemediationPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                badge(preview.status.rawValue, tint: remediationStatusColor(preview.status))
                Spacer()
                Text("\(preview.totalCandidateCount) candidate(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(preview.recommendedAction)
                .foregroundStyle(.secondary)

            if preview.totalCandidateCount > 0 {
                HStack(spacing: 10) {
                    metadataLabel("Candidates", value: "\(preview.totalCandidateCount)")
                    metadataLabel("Disk Impact", value: formattedByteCount(preview.totalBytes))
                    if preview.previewTruncated {
                        metadataLabel("Preview", value: "truncated")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if !preview.candidates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview candidates")
                        .font(.subheadline.weight(.semibold))

                    ForEach(preview.candidates.prefix(12)) { candidate in
                        HStack(alignment: .top, spacing: 8) {
                            Text(candidate.relativePath)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(artefactTypeLabel(candidate.artefactType))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button("Reveal") {
                                    revealMatchInFinder(scopePath: preview.scopePath, relativePath: candidate.relativePath)
                                }
                                .font(.caption)
                                .buttonStyle(.link)
                            }
                        }
                    }
                }
            }

            if !preview.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dry-run warnings")
                        .font(.subheadline.weight(.semibold))
                    ForEach(preview.warnings, id: \.code) { warning in
                        Text("\(warning.code): \(warning.message)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func remediationApplyResultPanel(_ result: ScopeRemediationApplyResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                badge(result.status.rawValue, tint: remediationApplyStatusColor(result.status))
                Spacer()
                Text("\(result.removedCount) removed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(result.message)
                .foregroundStyle(.secondary)

            if result.removedCount > 0 {
                HStack(spacing: 10) {
                    metadataLabel("Removed", value: "\(result.removedCount)")
                    metadataLabel("Disk Impact", value: formattedByteCount(result.removedBytes))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cleanup warnings")
                        .font(.subheadline.weight(.semibold))
                    ForEach(result.warnings, id: \.self) { warning in
                        Text("\(warning.code): \(warning.message)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func aggregateCleanupPreviewPanel(_ preview: AggregateCleanupPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                badge("preview ready", tint: .blue)
                Spacer()
                Text("\(preview.totalCandidateCount) candidate(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                metadataLabel("Scopes", value: "\(preview.affectedScopeCount)")
                metadataLabel("Skipped", value: "\(preview.skippedScopeCount)")
                metadataLabel("Disk Impact", value: formattedByteCount(preview.totalBytes))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !preview.readyScopePreviews.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready scopes")
                        .font(.subheadline.weight(.semibold))

                    ForEach(preview.readyScopePreviews, id: \.scopeID) { scopePreview in
                        HStack {
                            Text(scopePreview.scopeDisplayName)
                            Spacer()
                            Text("\(scopePreview.totalCandidateCount) artefact(s)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }

            if !preview.skippedScopeNames.isEmpty {
                Text("Skipped: \(preview.skippedScopeNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !preview.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Warnings")
                        .font(.subheadline.weight(.semibold))

                    ForEach(preview.warnings.prefix(6), id: \.code) { warning in
                        Text("\(warning.code): \(warning.message)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func aggregateCleanupResultPanel(_ result: AggregateCleanupApplyResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                badge(result.removedCount > 0 ? "cleanup applied" : "cleanup completed", tint: result.removedCount > 0 ? .green : .blue)
                Spacer()
                Text("\(result.processedScopeCount) scope(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                metadataLabel("Scopes Applied", value: "\(result.appliedScopeCount)")
                metadataLabel("Removed", value: "\(result.removedCount)")
                metadataLabel("Disk Impact", value: formattedByteCount(result.removedBytes))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !result.results.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Per-scope results")
                        .font(.subheadline.weight(.semibold))

                    ForEach(result.results, id: \.scopeID) { scopeResult in
                        Text("\(scopeResult.scopeDisplayName): \(scopeResult.message)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var historyComparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Snapshot comparison")
                .font(.headline)

            if let comparison = viewModel.historyComparison {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current snapshot versus \(formattedTimestamp(comparison.previousGeneratedAt))")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        comparisonDeltaCard(title: "Artefacts", delta: comparison.delta.artefactCount)
                        comparisonDeltaCard(title: "Disk Impact", deltaText: formattedDeltaBytes(comparison.delta.totalBytes), isPositive: comparison.delta.totalBytes >= 0)
                        comparisonDeltaCard(title: "Scopes", delta: comparison.delta.scopeCount)
                        comparisonDeltaCard(title: "Warnings", delta: comparison.delta.warningCount)
                    }

                    if snapshotComparisonIsStable {
                        Text("No change since the previous snapshot. History is working; this refresh just did not detect any new scope, artefact, or warning delta.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if viewModel.isLoading {
                emptyState(
                    title: "Loading history",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                emptyState(
                    title: "No previous snapshot yet",
                    systemImage: "clock.badge.questionmark",
                    description: "Refresh the inventory more than once to start comparing persisted snapshots."
                )
            }
        }
    }

    private var historyChangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scope-level changes")
                .font(.headline)

            if let comparison = viewModel.historyComparison, !comparison.delta.perScopeChanges.isEmpty {
                VStack(spacing: 10) {
                    ForEach(comparison.delta.perScopeChanges.prefix(10)) { change in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(change.displayName)
                                    .font(.headline)
                                Spacer()
                                badge(change.changeKind.rawValue, tint: historyChangeColor(change.changeKind))
                            }

                            Text(change.scopePath)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            HStack(spacing: 10) {
                                metadataLabel("Artefacts", value: formattedSignedValue(change.artefactDelta))
                                metadataLabel("Disk Impact", value: formattedDeltaBytes(change.byteDelta))
                                metadataLabel("Warnings", value: formattedSignedValue(change.warningDelta))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            HStack(spacing: 12) {
                                Button("Review Scope") {
                                    reviewScope(atPath: change.scopePath)
                                }

                                Button("Reveal in Finder") {
                                    revealInFinder(path: change.scopePath)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else {
                emptyState(
                    title: "No scope-level changes yet",
                    systemImage: "arrow.left.arrow.right",
                    description: "After a second snapshot, this section will show which scopes were added, removed, or changed."
                )
            }
        }
    }

    private func recentHistorySection(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent snapshots")
                .font(.headline)

            if !viewModel.recentSnapshots.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.recentSnapshots.prefix(max(1, limit)).enumerated()), id: \.element.url.path) { entry in
                        let snapshot = entry.element
                        let report = snapshot.report

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(formattedTimestamp(report.generatedAt))
                                    .font(.headline)

                                Spacer()

                                if entry.offset == 0 {
                                    badge("latest", tint: .blue)
                                }
                            }

                            HStack(spacing: 10) {
                                metadataLabel("Scopes", value: "\(report.scopes.count)")
                                metadataLabel("Artefacts", value: "\(report.artefactInventory.totalArtefactCount)")
                                metadataLabel("Disk Impact", value: formattedByteCount(report.artefactInventory.totalBytes))
                                metadataLabel("Warnings", value: "\(combinedWarningCount(for: report))")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Text(snapshot.url.lastPathComponent)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else if viewModel.isLoading {
                emptyState(
                    title: "Loading snapshots",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                emptyState(
                    title: "No snapshots found",
                    systemImage: "clock.badge.exclamationmark",
                    description: "No persisted history snapshots were available in the cache directory."
                )
            }
        }
    }

    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity feed")
                .font(.headline)

            if !filteredActivityItems.isEmpty {
                VStack(spacing: 10) {
                    ForEach(filteredActivityItems) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Label(item.title, systemImage: item.systemImage)
                                    .font(.headline)
                                    .foregroundStyle(item.tint)
                                Spacer()
                                if let timestamp = item.timestamp {
                                    Text(formattedTimestamp(timestamp))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(item.detail)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 12) {
                                if let scopePath = item.scopePath {
                                    Button("Review Scope") {
                                        reviewScope(atPath: scopePath)
                                    }
                                    .buttonStyle(.link)
                                }

                                Button("Reveal Logs Context") {
                                    selection = .logs
                                }
                                .buttonStyle(.link)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else {
                emptyState(
                    title: "No activity yet",
                    systemImage: "text.justify.left",
                    description: "Refresh the inventory to generate activity from the current report and persisted history."
                )
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Show sample match paths in inventory cards", isOn: $showSampleMatches)
            Toggle("Keep future helper protection armed", isOn: $liveProtectionEnabled)

            VStack(alignment: .leading, spacing: 8) {
                Text("Recent snapshot count")
                    .font(.subheadline.weight(.semibold))
                Stepper(value: $historyLimit, in: 3...12) {
                    Text("Show \(historyLimit) snapshots in history views")
                        .foregroundStyle(.secondary)
                }
            }

            if let persistedPath = viewModel.persistedPath {
                Divider()
                Text("Latest snapshot path")
                    .font(.subheadline.weight(.semibold))
                Text(persistedPath)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("App data folder")
                    .font(.subheadline.weight(.semibold))
                Text(viewModel.storageRootPath)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Button("Reveal App Data") {
                        revealStorageRoot()
                    }

                    Button("Reset Stored Data") {
                        confirmAndResetStoredData()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var privacyGuidancePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Privacy & Security", systemImage: "lock.shield")
                .font(.headline)

            if !permissionWarnings.isEmpty {
                Text("The latest refresh hit one or more permission-denied paths. Review the guidance below before assuming the app needs broad system access.")
                    .foregroundStyle(.secondary)
            } else {
                Text("This beta app does not need special permission to save its own snapshots. Privacy prompts only matter when macOS blocks discovery or scanning in protected folders.")
                    .foregroundStyle(.secondary)
            }

            Label("Desktop, Documents, and Downloads scopes may need Files and Folders access.", systemImage: "folder.badge.questionmark")
                .foregroundStyle(.secondary)
            Label("Full Disk Access is optional for this beta app and should only be used if macOS keeps denying multiple protected paths during audit scans.", systemImage: "internaldrive")
                .foregroundStyle(.secondary)
            Label("Google Drive metadata under Library paths may trigger broader access requirements on some systems if macOS blocks discovery.", systemImage: "externaldrive.badge.icloud")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var liveProtectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Live Protection", systemImage: liveProtectionActive ? "shield.lefthalf.filled" : "shield.slash")
                .font(.headline)

            if let liveProtectionAttention {
                statusCallout(
                    title: liveProtectionAttention.title,
                    systemImage: liveProtectionAttention.systemImage,
                    message: liveProtectionAttention.message,
                    tint: liveProtectionAttention.tint
                )
            }

            Text(viewModel.protectionStatus.detail)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                badge(liveProtectionActive ? "active" : "audit only", tint: liveProtectionActive ? .green : .orange)
                metadataLabel("Auto-Blocked Scopes", value: "\(viewModel.protectionStatus.activeProtectedScopeCount)")
                badge(eventSourceStateLabel(viewModel.protectionStatus.eventSourceState), tint: eventSourceStateColor(viewModel.protectionStatus.eventSourceState))
                badge(installationStateLabel(viewModel.protectionStatus.installationState), tint: installationStateColor(viewModel.protectionStatus.installationState))
                badge("helper \(viewModel.protectionStatus.helperUpdateStatus.rawValue)", tint: helperUpdateStatusColor(viewModel.protectionStatus.helperUpdateStatus))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(viewModel.protectionStatus.eventSourceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(viewModel.protectionStatus.installationDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(viewModel.protectionStatus.helperUpdateDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let helperPath = viewModel.protectionStatus.helperExecutablePath {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        metadataLabel("Helper Host", value: "bundled")
                        Button("Reveal Helper") {
                            revealInFinder(path: helperPath)
                        }
                        .buttonStyle(.link)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(helperPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text("No standalone helper host was found in the current build output. The app can still audit and clean up manually, but true Google-Drive-only blocking is not packaged yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let helperServiceStatus = viewModel.helperServiceStatus {
                HStack(spacing: 10) {
                    badge(helperServiceStatus.isLoaded ? "launchd loaded" : "launchd not loaded", tint: helperServiceStatus.isLoaded ? .green : .orange)
                    metadataLabel("LaunchAgent", value: supportDiagnostics.launchdLabel)
                    metadataLabel("Service", value: helperServiceStatus.serviceTarget)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(helperServiceStatus.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            helperVersionSection

            HStack(spacing: 12) {
                Button(primaryHelperInstallButtonTitle) {
                    viewModel.installAndStartHelperService()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isUpdatingHelperService || viewModel.protectionStatus.helperExecutablePath == nil)

                Button("Refresh Helper Status") {
                    viewModel.refreshHelperServiceStatus()
                }
                .disabled(viewModel.isUpdatingHelperService)

                Button(helperRemovalButtonTitle) {
                    viewModel.removeInstalledHelperService()
                }
                .disabled(viewModel.isUpdatingHelperService || viewModel.protectionStatus.installationState != .installed)
            }

            if viewModel.isUpdatingHelperService {
                ProgressView("Updating helper service…")
                    .controlSize(.small)
            }

            if let helperLifecycleMessage = viewModel.helperLifecycleMessage {
                Text(helperLifecycleMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if liveProtectionNeedsAttention {
                HStack(spacing: 10) {
                    Button("Open Login Items") {
                        openLoginItemsSettings()
                    }
                    .buttonStyle(.bordered)

                    Button("Copy Diagnostics") {
                        copySupportDetails()
                    }
                    .buttonStyle(.bordered)

                    Button("Report Issue") {
                        reportIssue()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("Installed helper lifecycle is now handled from the app, but true Google-Drive-only live blocking while the app is closed still depends on the real Endpoint Security host lane becoming ready.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var permissionRetryNotice: some View {
        if viewModel.pendingPermissionRetry {
            inlineNotice(
                title: "Permission Prompt In Progress",
                systemImage: "lock.open.trianglebadge.exclamationmark",
                message: "The first scan hit macOS permission-denied paths before access was fully granted. The app will retry automatically when it becomes active again after you finish the prompt."
            )
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func journeyStep(title: String, detail: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                badge(status.lowercased(), tint: journeyStatusColor(status))
            }

            Text(detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func comparisonDeltaCard(title: String, delta: Int) -> some View {
        comparisonDeltaCard(
            title: title,
            deltaText: formattedSignedValue(delta),
            isPositive: delta >= 0
        )
    }

    private func comparisonDeltaCard(title: String, deltaText: String, isPositive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(deltaText)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isPositive ? .green : .orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func infoCard(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(lines, id: \.self) { line in
                Label(line, systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func inlineNotice(title: String, systemImage: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusCallout(title: String, systemImage: String, message: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(tint)
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func placeholderPanel(title: String, systemImage: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(description)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .padding(18)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metadataLabel(_ title: String, value: String) -> some View {
        Label {
            Text(value)
        } icon: {
            Text("\(title):")
                .foregroundStyle(.tertiary)
        }
    }

    private func emptyState(title: String, systemImage: String, description: String? = nil) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            if let description, !description.isEmpty {
                Text(description)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(20)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
            .foregroundStyle(tint)
    }

    private func supportStatusColor(_ status: SupportStatus) -> Color {
        switch status {
        case .supported:
            return .green
        case .auditOnly:
            return .orange
        case .unsupported:
            return .red
        }
    }

    private func scopeConfidenceLabel(_ source: ScopeSource) -> String {
        switch source {
        case .confirmed:
            return "confirmed"
        case .config:
            return "config-backed"
        case .inferred:
            return "inferred"
        }
    }

    private func driveModeColor(_ mode: DriveMode) -> Color {
        switch mode {
        case .mirror:
            return .blue
        case .stream:
            return .purple
        case .backup:
            return .teal
        }
    }

    private func journeyStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "ready", "protected", "clean":
            return .green
        case "review":
            return .orange
        case "loading":
            return .blue
        default:
            return .secondary
        }
    }

    private func eventSourceStateLabel(_ state: ProtectionEventSourceState) -> String {
        switch state {
        case .unavailable:
            return "unavailable"
        case .bundled:
            return "bundled"
        case .needsApproval:
            return "needs approval"
        case .ready:
            return "ready"
        case .error:
            return "error"
        }
    }

    private func eventSourceStateColor(_ state: ProtectionEventSourceState) -> Color {
        switch state {
        case .unavailable:
            return .secondary
        case .bundled:
            return .blue
        case .needsApproval:
            return .orange
        case .ready:
            return .green
        case .error:
            return .red
        }
    }

    private func installationStateLabel(_ state: ProtectionInstallationState) -> String {
        switch state {
        case .unavailable:
            return "no install path"
        case .bundledOnly:
            return "bundled only"
        case .installPlanReady:
            return "install plan ready"
        case .installed:
            return "installed"
        case .error:
            return "install error"
        }
    }

    private func installationStateColor(_ state: ProtectionInstallationState) -> Color {
        switch state {
        case .unavailable:
            return .secondary
        case .bundledOnly:
            return .blue
        case .installPlanReady:
            return .orange
        case .installed:
            return .green
        case .error:
            return .red
        }
    }

    private var combinedWarnings: [DiscoveryWarning] {
        guard let report = viewModel.report else {
            return []
        }

        return report.warnings + report.artefactInventory.warnings
    }

    private var protectedScopeCount: Int {
        viewModel.protectionStatus.activeProtectedScopeCount
    }

    private var liveProtectionActive: Bool {
        liveProtectionEnabled && protectedScopeCount > 0
    }

    private var detectedScopeSummary: String {
        guard let report = viewModel.report else {
            return "Locations"
        }

        let supported = report.scopes.filter { $0.supportStatus == .supported }.count
        let auditOnly = report.scopes.filter { $0.supportStatus == .auditOnly }.count
        return "\(report.scopes.count) locations (\(supported) supported, \(auditOnly) audit-only)"
    }

    private var findingsSummary: String {
        guard let report = viewModel.report else {
            return "Waiting for the first scan to complete."
        }

        let artefacts = report.artefactInventory.totalArtefactCount
        let matchedScopes = report.artefactInventory.matchedScopeCount
        if artefacts == 0 {
            return "No known icon artefacts are currently matched across the detected locations."
        }

        return "\(artefacts) artefact(s) across \(matchedScopes) location(s), using \(formattedByteCount(report.artefactInventory.totalBytes))."
    }

    private var findingsStatus: String {
        guard let report = viewModel.report else {
            return "Loading"
        }

        return report.artefactInventory.totalArtefactCount == 0 ? "Clean" : "Review"
    }

    private var actionSummary: String {
        guard let report = viewModel.report else {
            return "Refresh will load locations, findings, and actions."
        }

        if report.scopes.isEmpty {
            return "No Drive-managed locations were found yet. Refresh after confirming Google Drive is running."
        }

        if liveProtectionActive {
            return "Live protection is active for \(protectedScopeCount) supported location(s), and each selected location exposes reveal, export, preview, and cleanup actions."
        }

        return "Select a location below for reveal, export, preview, and cleanup actions. Automatic blocking stays in audit mode until process-aware helper support exists."
    }

    private var actionStatus: String {
        guard let report = viewModel.report, !report.scopes.isEmpty else {
            return "Loading"
        }

        if liveProtectionActive {
            return "Protected"
        }

        return "Ready"
    }

    private var permissionWarnings: [DiscoveryWarning] {
        combinedWarnings.filter { $0.code.contains("permission_denied") }
    }

    private var lastRefreshLabel: String {
        guard let generatedAt = viewModel.report?.generatedAt else {
            return viewModel.isLoading ? "Refreshing now" : "Not refreshed yet"
        }
        return formattedTimestamp(generatedAt)
    }

    private var buildSourceLabel: String {
        let path = supportDiagnostics.bundlePath
        if path.hasPrefix("/Applications/") {
            return "Applications folder"
        }
        if path.contains("/dist/") {
            return "Packaged dist build"
        }
        return "Local or repo build"
    }

    private var signingTintColor: Color {
        switch supportDiagnostics.signingStatus {
        case "Unsigned", "Ad hoc signed":
            return .orange
        default:
            return .green
        }
    }

    private var notarizationTintColor: Color {
        supportDiagnostics.notarizationStatus == "Notarized" ? .green : .orange
    }

    private var primaryHelperInstallButtonTitle: String {
        switch viewModel.protectionStatus.helperUpdateStatus {
        case .outdated, .mismatch:
            return "Update Helper"
        case .current where viewModel.protectionStatus.installationState == .installed:
            return "Reinstall + Restart Helper"
        default:
            return viewModel.protectionStatus.installationState == .installed ? "Reinstall + Restart Helper" : "Install Background Helper"
        }
    }

    private var helperRemovalButtonTitle: String {
        liveProtectionNeedsAttention ? "Disable + Remove Helper" : "Remove Installed Helper"
    }

    private var hasSupportedCleanupCandidates: Bool {
        guard let report = viewModel.report else {
            return false
        }

        let supportedScopeIDs = Set(report.scopes.filter { $0.supportStatus == .supported }.map(\.id))
        return report.artefactInventory.scopeResults.contains {
            $0.matchedArtefactCount > 0 && supportedScopeIDs.contains($0.scopeID)
        }
    }

    private var aggregateCleanupButtonTitle: String {
        if viewModel.aggregateCleanupPreview != nil {
            return "Apply Cleanup"
        }

        return "Run Cleanup"
    }

    private var aggregateCleanupHelperText: String {
        if let preview = viewModel.aggregateCleanupPreview {
            return "Prepared aggregate cleanup preview for \(preview.affectedScopeCount) supported scope(s) and \(preview.totalCandidateCount) candidate artefact(s). Press Apply Cleanup to continue."
        }

        if hasSupportedCleanupCandidates {
            return "Run Cleanup prepares a single dry-run summary across all supported scopes with current artefacts."
        }

        return "Run Cleanup becomes available when supported scopes have current cleanup candidates."
    }

    private var liveProtectionNeedsAttention: Bool {
        liveProtectionAttention != nil
    }

    private var liveProtectionAttention: (title: String, message: String, systemImage: String, tint: Color)? {
        if viewModel.protectionStatus.installationState == .error {
            return (
                title: "Helper installation is in an error state",
                message: "\(viewModel.protectionStatus.installationDescription) Remove the installed helper, then reinstall only if you are explicitly testing helper lifecycle behavior.",
                systemImage: "exclamationmark.triangle.fill",
                tint: .red
            )
        }

        if let helperServiceStatus = viewModel.helperServiceStatus,
           !helperServiceStatus.isLoaded,
           viewModel.protectionStatus.installationState == .installed {
            return (
                title: "Installed helper is not responding",
                message: "\(condensedDetail(helperServiceStatus.detail)) Open Login Items if the helper looks enabled there, then use Disable + Remove Helper to clear the stale service before reinstalling.",
                systemImage: "bolt.horizontal.circle.fill",
                tint: .orange
            )
        }

        if let helperLifecycleMessage = viewModel.helperLifecycleMessage,
           helperLifecycleMessage.localizedCaseInsensitiveContains("failed")
            || helperLifecycleMessage.localizedCaseInsensitiveContains("timed out")
            || helperLifecycleMessage.localizedCaseInsensitiveContains("could not find service")
            || helperLifecycleMessage.localizedCaseInsensitiveContains("bad request") {
            return (
                title: "Helper lifecycle action needs attention",
                message: "\(condensedDetail(helperLifecycleMessage)) If the helper was toggled in Login Items, disable it there before trying another install cycle.",
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange
            )
        }

        return nil
    }

    private var helperVersionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bundled = viewModel.protectionStatus.bundledHelperBuild {
                helperBuildRow(title: "Bundled Helper", build: bundled)
            }

            if let installed = viewModel.protectionStatus.installedHelperBuild {
                helperBuildRow(title: "Installed Helper", build: installed)
            }

            if let running = viewModel.protectionStatus.runningHelperBuild {
                helperBuildRow(title: "Running Helper", build: running)
            }
        }
    }

    private func helperBuildRow(title: String, build: ProtectionHelperBuildInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                metadataLabel(title, value: build.versionLine ?? "unknown")
                if let releaseIdentity = build.releaseIdentityLine {
                    Text(releaseIdentity)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let executablePath = build.executablePath {
                Text(executablePath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var snapshotComparisonIsStable: Bool {
        guard let comparison = viewModel.historyComparison else {
            return false
        }

        return comparison.delta.artefactCount == 0
            && comparison.delta.totalBytes == 0
            && comparison.delta.scopeCount == 0
            && comparison.delta.warningCount == 0
            && comparison.delta.perScopeChanges.isEmpty
    }

    private var selectedScope: DriveManagedScope? {
        guard let report = viewModel.report else {
            return nil
        }

        if let selectedScopeID, let selected = report.scopes.first(where: { $0.id == selectedScopeID }) {
            return selected
        }

        return report.scopes.first
    }

    private var allActivityItems: [ActivityItem] {
        let events = viewModel.activityLog.events.prefix(40)

        return events.map { event in
            ActivityItem(
                id: event.id.uuidString,
                title: activityTitle(for: event),
                detail: activityDetail(for: event),
                systemImage: activityIcon(for: event),
                tint: activityTint(for: event),
                timestamp: event.timestamp,
                category: event.category,
                severity: event.severity,
                scopePath: event.scopeID == nil ? nil : event.targetPath
            )
        }
    }

    private var filteredActivityItems: [ActivityItem] {
        guard let category = activityFilter.category else {
            return allActivityItems
        }

        return allActivityItems.filter { $0.category == category }
    }

    private var recentActivityItems: [ActivityItem] {
        Array(
            allActivityItems
                .sorted { lhs, rhs in
                    severityRank(lhs.severity) > severityRank(rhs.severity)
                        || (lhs.timestamp ?? .distantPast) > (rhs.timestamp ?? .distantPast)
                }
                .prefix(5)
        )
    }

    private func artefactScanResult(for scope: DriveManagedScope) -> ScopeArtefactScanResult? {
        viewModel.report?.artefactInventory.scopeResults.first(where: { $0.scopeID == scope.id })
    }

    private func scanStatusLabel(_ status: ScopeArtefactScanStatus) -> String {
        switch status {
        case .scanned:
            return "scanned"
        case .skippedUnsupported:
            return "skipped"
        case .missingPath:
            return "missing"
        case .unreadable:
            return "unreadable"
        }
    }

    private func scanStatusColor(_ status: ScopeArtefactScanStatus) -> Color {
        switch status {
        case .scanned:
            return .blue
        case .skippedUnsupported:
            return .secondary
        case .missingPath:
            return .orange
        case .unreadable:
            return .red
        }
    }

    private func formattedByteCount(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func formattedDeltaBytes(_ bytes: Int) -> String {
        let prefix = bytes >= 0 ? "+" : "-"
        return prefix + ByteCountFormatter.string(fromByteCount: Int64(abs(bytes)), countStyle: .file)
    }

    private func formattedSignedValue(_ value: Int) -> String {
        if value > 0 {
            return "+\(value)"
        }
        return "\(value)"
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func combinedWarningCount(for report: ScopeInventoryReport) -> Int {
        report.warnings.count + report.artefactInventory.warnings.count
    }

    private func selectedRemediationPreview(for scope: DriveManagedScope) -> ScopeRemediationPreview? {
        guard let preview = viewModel.remediationPreview, preview.scopeID == scope.id else {
            return nil
        }

        return preview
    }

    private func selectedRemediationApplyResult(for scope: DriveManagedScope) -> ScopeRemediationApplyResult? {
        guard let result = viewModel.remediationApplyResult, result.scopeID == scope.id else {
            return nil
        }

        return result
    }

    private func artefactTypeLabel(_ type: ArtefactType) -> String {
        switch type {
        case .iconFile:
            return "Finder Icon file"
        case .iconSidecar:
            return "AppleDouble sidecar"
        case .folderMetadata:
            return "Folder metadata"
        case .unknown:
            return "Unknown"
        }
    }

    private func scanCoverageText(for scanResult: ScopeArtefactScanResult) -> String {
        var parts = [
            "\(scanResult.scannedDirectoryCount) director\(scanResult.scannedDirectoryCount == 1 ? "y" : "ies")",
            "\(scanResult.inspectedFileCount) file\(scanResult.inspectedFileCount == 1 ? "" : "s") inspected"
        ]

        if scanResult.skippedSymbolicLinkCount > 0 {
            parts.append("\(scanResult.skippedSymbolicLinkCount) symlink\(scanResult.skippedSymbolicLinkCount == 1 ? "" : "s") skipped")
        }

        return "Recursive coverage: " + parts.joined(separator: ", ")
    }

    private func reviewPriorityColor(_ priority: ScopeReviewPriority) -> Color {
        switch priority {
        case .ready:
            return .green
        case .attention:
            return .orange
        case .monitor:
            return .blue
        case .blocked:
            return .red
        }
    }

    private func remediationStatusColor(_ status: ScopeRemediationPreviewStatus) -> Color {
        switch status {
        case .ready:
            return .green
        case .noCandidates:
            return .blue
        case .unavailable:
            return .orange
        case .unreadable:
            return .red
        }
    }

    private func remediationApplyStatusColor(_ status: ScopeRemediationApplyStatus) -> Color {
        switch status {
        case .applied:
            return .green
        case .partialFailure:
            return .orange
        case .noCandidates:
            return .blue
        case .unavailable:
            return .orange
        case .unreadable:
            return .red
        }
    }

    private func helperUpdateStatusColor(_ status: ProtectionHelperUpdateStatus) -> Color {
        switch status {
        case .current:
            return .green
        case .outdated:
            return .orange
        case .mismatch:
            return .red
        case .unknown:
            return .secondary
        }
    }

    private func severityRank(_ severity: ActivitySeverity) -> Int {
        switch severity {
        case .error:
            return 3
        case .warning:
            return 2
        case .info:
            return 1
        }
    }

    private func primaryCleanupButtonTitle(for scope: DriveManagedScope) -> String {
        guard scope.supportStatus == .supported else {
            return "Cleanup Unavailable"
        }

        if selectedRemediationPreview(for: scope)?.status == .ready {
            return "Apply Cleanup"
        }

        return "Apply Cleanup"
    }

    private func primaryCleanupHelperText(for scope: DriveManagedScope) -> String {
        guard scope.supportStatus == .supported else {
            return "Cleanup stays disabled for audit-only and unsupported locations."
        }

        if selectedRemediationPreview(for: scope)?.status == .ready {
            return "The current preview is ready. Apply Cleanup will confirm deletion of the matched artefacts shown below."
        }

        return "Apply Cleanup starts with a dry-run preview if one is not ready yet, so the user still sees the exact candidates before deletion."
    }

    private func historyChangeColor(_ change: ScopeHistoryChangeKind) -> Color {
        switch change {
        case .added:
            return .green
        case .removed:
            return .red
        case .changed:
            return .blue
        }
    }

    private func cardBackground(for scope: DriveManagedScope) -> some ShapeStyle {
        selectedScopeID == scope.id ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.08)
    }

    private func revealInFinder(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func supportActionButtons(includeLoginItems: Bool) -> some View {
        HStack(spacing: 10) {
            Button("Copy Diagnostics") {
                copySupportDetails()
            }
            .buttonStyle(.bordered)

            Button("Report Issue") {
                reportIssue()
            }
            .buttonStyle(.bordered)

            Button("Reveal App") {
                revealInFinder(path: supportDiagnostics.bundlePath)
            }
            .buttonStyle(.bordered)

            if includeLoginItems {
                Button("Open Login Items") {
                    openLoginItemsSettings()
                }
                .buttonStyle(.bordered)
            } else {
                Link("Open Releases", destination: AppSupportLinks.releases)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func revealStorageRoot() {
        let storageURL = URL(fileURLWithPath: viewModel.storageRootPath, isDirectory: true)
        let targetURL: URL

        if FileManager.default.fileExists(atPath: storageURL.path) {
            targetURL = storageURL
        } else {
            targetURL = storageURL.deletingLastPathComponent()
        }

        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
    }

    private func copySupportDetails() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(dashboardSupportSummary, forType: .string)
        supportMessage = "Copied build, helper, and launchd diagnostics to the clipboard for GitHub support."
    }

    private func reportIssue() {
        supportMessage = "Opening a prefilled GitHub issue with the current build and helper diagnostics."
        NSWorkspace.shared.open(dashboardIssueURL)
    }

    private var dashboardIssueURL: URL {
        var components = URLComponents(url: AppSupportLinks.issues.appendingPathComponent("new"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "title", value: dashboardIssueTitle),
            URLQueryItem(name: "body", value: dashboardIssueBody)
        ]
        return components?.url ?? AppSupportLinks.issues
    }

    private var dashboardIssueTitle: String {
        if let releaseTag = supportDiagnostics.releaseTag {
            return "[\(releaseTag)] Dashboard report"
        }
        if let gitCommit = supportDiagnostics.gitCommit {
            return "[\(gitCommit)] Dashboard report"
        }
        return "Dashboard report"
    }

    private var dashboardIssueBody: String {
        """
        ## Summary

        Describe the issue.

        ## What Happened

        -

        ## Expected

        -

        ## Support Details

        ```text
        \(dashboardSupportSummary)
        ```
        """
    }

    private var dashboardSupportSummary: String {
        """
        App: Google Drive Icon Guard
        Version: \(supportDiagnostics.versionLine)
        Release tag: \(supportDiagnostics.releaseTag ?? "unknown")
        Git commit: \(supportDiagnostics.gitCommit ?? "unknown")
        Git ref: \(supportDiagnostics.gitRef ?? "unknown")
        Bundle ID: \(supportDiagnostics.bundleIdentifier)
        Bundle Path: \(supportDiagnostics.bundlePath)
        Build source: \(buildSourceLabel)
        Executable: \(supportDiagnostics.executableName)
        macOS: \(supportDiagnostics.macosVersion)
        Signing: \(supportDiagnostics.signingStatus)
        Notarization: \(supportDiagnostics.notarizationStatus)
        Signing Identity: \(supportDiagnostics.codesignIdentity ?? "unknown")
        LaunchAgent Label: \(supportDiagnostics.launchdLabel)
        Mach Service: \(supportDiagnostics.machServiceName)
        launchd Service: \(viewModel.helperServiceStatus?.serviceTarget ?? supportDiagnostics.serviceTarget)
        launchd Status: \(viewModel.helperServiceStatus?.isLoaded == true ? "Loaded" : "Not loaded")
        launchd Detail: \(condensedDetail(viewModel.helperServiceStatus?.detail ?? supportDiagnostics.launchdDetail))
        Helper Install State: \(viewModel.protectionStatus.installationState.rawValue)
        Helper Install Detail: \(condensedDetail(viewModel.protectionStatus.installationDescription))
        Helper Executable: \(viewModel.protectionStatus.helperExecutablePath ?? supportDiagnostics.helperExecutablePath ?? "none")
        Protection Detail: \(condensedDetail(viewModel.protectionStatus.detail))
        Event Source: \(viewModel.protectionStatus.eventSourceState.rawValue)
        Event Source Detail: \(condensedDetail(viewModel.protectionStatus.eventSourceDescription))
        Helper Lifecycle Message: \(condensedDetail(viewModel.helperLifecycleMessage ?? "none"))
        Last Refresh: \(lastRefreshLabel)
        GitHub Issues: \(AppSupportLinks.issues.absoluteString)
        """
    }

    private func condensedDetail(_ value: String, maxLength: Int = 220) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
        if collapsed.count <= maxLength {
            return collapsed
        }
        let index = collapsed.index(collapsed.startIndex, offsetBy: maxLength)
        return String(collapsed[..<index]) + "…"
    }

    private func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"),
           NSWorkspace.shared.open(url) {
            return
        }

        _ = NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    private func revealMatchInFinder(scopePath: String, relativePath: String) {
        let rootURL = URL(fileURLWithPath: scopePath, isDirectory: true)
        let targetURL = rootURL.appendingPathComponent(relativePath)
        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
    }

    private func ensureSelectedScope() {
        guard let report = viewModel.report else {
            selectedScopeID = nil
            return
        }

        if let selectedScopeID, report.scopes.contains(where: { $0.id == selectedScopeID }) {
            return
        }

        selectedScopeID = report.scopes.first?.id
    }

    private func reviewScope(atPath path: String) {
        guard let scope = viewModel.report?.scopes.first(where: { $0.path == path }) else {
            selection = .dashboard
            return
        }

        selection = .dashboard
        selectedScopeID = scope.id
    }

    private func startCleanupJourney(for scope: DriveManagedScope) {
        guard scope.supportStatus == .supported else {
            exportMessage = "Cleanup is only available for supported locations."
            return
        }

        if selectedRemediationPreview(for: scope)?.status == .ready {
            confirmAndApplyCleanup(for: scope)
            return
        }

        viewModel.prepareDryRunRemediation(for: scope)
        exportMessage = "Dry-run preview prepared for \(scope.displayName). Review the candidates below, then press Apply Cleanup again."
    }

    private func startAggregateCleanupJourney() {
        guard hasSupportedCleanupCandidates else {
            exportMessage = "No supported cleanup candidates are available yet."
            return
        }

        if viewModel.aggregateCleanupPreview != nil {
            confirmAndApplyAggregateCleanup()
            return
        }

        if let preview = viewModel.prepareAggregateCleanup(), preview.affectedScopeCount > 0 {
            exportMessage = "Prepared cleanup preview for \(preview.affectedScopeCount) supported scope(s). Review the summary below, then press Apply Cleanup."
        } else {
            exportMessage = "No supported cleanup candidates remained after the aggregate dry-run preview."
        }
    }

    private func confirmAndApplyCleanup(for scope: DriveManagedScope) {
        guard let preview = selectedRemediationPreview(for: scope), preview.status == .ready else {
            exportMessage = "Prepare a dry-run preview before applying cleanup."
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Apply cleanup for \(scope.displayName)?"
        alert.informativeText = "This will permanently remove \(preview.totalCandidateCount) matched artefact file(s) using \(formattedByteCount(preview.totalBytes)). The app will not follow symlinks, and it will refresh the inventory after cleanup."
        alert.addButton(withTitle: "Apply Cleanup")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let result = viewModel.applyCleanup(for: scope)
        exportMessage = result.message
    }

    private func confirmAndApplyAggregateCleanup() {
        guard let preview = viewModel.aggregateCleanupPreview else {
            exportMessage = "Prepare an aggregate cleanup preview before applying cleanup."
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Apply cleanup across \(preview.affectedScopeCount) supported scope(s)?"
        alert.informativeText = "This will permanently remove \(preview.totalCandidateCount) matched artefact file(s) using \(formattedByteCount(preview.totalBytes)). \(preview.skippedScopeCount) scope(s) will be skipped."
        alert.addButton(withTitle: "Apply Cleanup")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        if let result = viewModel.applyAggregateCleanup() {
            exportMessage = "Aggregate cleanup processed \(result.processedScopeCount) scope(s) and removed \(result.removedCount) artefact(s)."
        } else {
            exportMessage = "Aggregate cleanup could not be applied."
        }
    }

    private func confirmAndResetStoredData() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reset stored app data?"
        alert.informativeText = "This will remove persisted snapshots and the activity log from \(viewModel.storageRootPath). The app will stay open, but history and logs will be cleared until the next refresh."
        alert.addButton(withTitle: "Reset Data")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            try viewModel.clearStoredData()
            exportMessage = "Cleared persisted snapshots and activity log."
        } catch {
            exportMessage = "Failed to clear stored data: \(error.localizedDescription)"
        }
    }

    private func exportFindings() {
        guard let markdown = viewModel.markdownExport() else {
            exportMessage = "No report is loaded yet."
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = defaultExportFileName()
        panel.title = "Export Findings"
        panel.message = "Save a human-readable findings report for the current inventory snapshot."

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
                exportMessage = "Saved findings report to \(url.path)."
            } catch {
                exportMessage = "Failed to save findings report: \(error.localizedDescription)"
            }
        }
    }

    private func exportScopeFindings(_ scope: DriveManagedScope) {
        guard let markdown = viewModel.markdownExport(for: scope) else {
            exportMessage = "No scope report is available for \(scope.displayName)."
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = defaultScopeExportFileName(for: scope)
        panel.title = "Export Scope Findings"
        panel.message = "Save a human-readable findings report for the selected scope only."

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
                exportMessage = "Saved scope findings report to \(url.path)."
            } catch {
                exportMessage = "Failed to save scope findings report: \(error.localizedDescription)"
            }
        }
    }

    private func defaultExportFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "google-drive-icon-guard-findings-\(formatter.string(from: Date())).md"
    }

    private func defaultScopeExportFileName(for scope: DriveManagedScope) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let safeName = scope.displayName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        return "google-drive-icon-guard-\(safeName)-\(formatter.string(from: Date())).md"
    }

    private func exportDryRunScript(for scope: DriveManagedScope) {
        let script = viewModel.dryRunRemediationScript(for: scope)

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.shellScript]
        panel.nameFieldStringValue = defaultDryRunFileName(for: scope)
        panel.title = "Export Dry-Run Script"
        panel.message = "Save a shell script that prints the candidate cleanup operations without removing files."

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try script.write(to: url, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
                exportMessage = "Saved dry-run script to \(url.path)."
            } catch {
                exportMessage = "Failed to save dry-run script: \(error.localizedDescription)"
            }
        }
    }

    private func defaultDryRunFileName(for scope: DriveManagedScope) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let safeName = scope.displayName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        return "google-drive-icon-guard-dry-run-\(safeName)-\(formatter.string(from: Date())).sh"
    }

    private func activityTitle(for event: EventRecord) -> String {
        switch event.category {
        case .helper:
            return helperActivityTitle(for: event.rawEventType)
        case .cleanup:
            return cleanupActivityTitle(for: event.rawEventType)
        case .protection:
            return "Protection event"
        case .warning:
            return event.rawEventType.replacingOccurrences(of: "warning_", with: "")
        case .inventory:
            break
        }

        switch event.rawEventType {
        case "inventory_refresh":
            return "Inventory refresh completed"
        case "scope_scan_result":
            return URL(fileURLWithPath: event.targetPath).lastPathComponent
        case let value where value.hasPrefix("scope_history_"):
            return "Scope history updated"
        default:
            return event.rawEventType
        }
    }

    private func activityDetail(for event: EventRecord) -> String {
        if let message = event.message, !message.isEmpty {
            return message
        }

        switch event.rawEventType {
        case "inventory_refresh":
            return "Recorded \(event.aggregatedCount) total artefact match(es) in the latest refresh."
        case "scope_scan_result":
            return "Matched \(event.aggregatedCount) artefact(s) at \(event.targetPath)."
        case let value where value.hasPrefix("scope_history_"):
            return "Detected a scope-level history change at \(event.targetPath)."
        default:
            return "\(event.rawEventType) at \(event.targetPath)"
        }
    }

    private func activityIcon(for event: EventRecord) -> String {
        switch event.category {
        case .helper:
            return event.severity == .error ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver"
        case .cleanup:
            return "trash"
        case .protection:
            return "shield.lefthalf.filled"
        case .warning:
            return "exclamationmark.triangle"
        case .inventory:
            break
        }

        switch event.rawEventType {
        case "inventory_refresh":
            return "arrow.clockwise.circle"
        case "scope_scan_result":
            return "doc.text.magnifyingglass"
        case let value where value.hasPrefix("scope_history_"):
            return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        default:
            return "text.justify.left"
        }
    }

    private func activityTint(for event: EventRecord) -> Color {
        switch event.severity {
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            break
        }

        switch event.rawEventType {
        case "inventory_refresh":
            return .blue
        case "scope_scan_result":
            return .red
        case let value where value.hasPrefix("scope_history_"):
            return .purple
        default:
            return .secondary
        }
    }

    private func helperActivityTitle(for rawEventType: String) -> String {
        switch rawEventType {
        case let value where value.contains("install"):
            return "Helper install"
        case let value where value.contains("remove"):
            return "Helper removal"
        case let value where value.contains("transport"):
            return "Helper transport fallback"
        case let value where value.contains("status_refresh"):
            return "Helper status refresh"
        default:
            return "Helper lifecycle"
        }
    }

    private func cleanupActivityTitle(for rawEventType: String) -> String {
        switch rawEventType {
        case "remediation_preview":
            return "Cleanup preview prepared"
        case "remediation_preview_all":
            return "Aggregate cleanup preview prepared"
        case let value where value.hasPrefix("remediation_apply_all_"):
            return "Aggregate cleanup applied"
        case let value where value.hasPrefix("remediation_apply_"):
            return "Cleanup applied"
        default:
            return "Cleanup event"
        }
    }
}
