import DriveIconGuardScopeInventory
import DriveIconGuardShared
import SwiftUI

private enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case inventory
    case logs
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .inventory:
            return "Inventory"
        case .logs:
            return "Logs"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "rectangle.3.group.bubble.left"
        case .inventory:
            return "externaldrive.connected.to.line.below"
        case .logs:
            return "text.justify.left"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

struct ScopeInventoryWindow: View {
    @StateObject private var viewModel = ScopeInventoryViewModel()
    @State private var selection: AppSection? = .overview

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
        }
        .task {
            if viewModel.report == nil {
                viewModel.refresh()
            }
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
        switch selection ?? .overview {
        case .overview:
            overviewSection
        case .inventory:
            inventorySection
        case .logs:
            logsSection
        case .settings:
            settingsSection
        }
    }

    private var overviewSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: "Google Drive Icon Guard",
                    subtitle: "Current beta app shell for scope discovery, audit visibility, and the next stage of the macOS app."
                )

                stats

                VStack(alignment: .leading, spacing: 12) {
                    Text("Current status")
                        .font(.headline)

                    infoCard(
                        title: "What works now",
                        lines: [
                            "DriveFS root preference discovery",
                            "Scope classification and support status",
                            "Latest plus historical inventory persistence",
                            "Minimal SwiftUI viewer for review"
                        ]
                    )

                    infoCard(
                        title: "Next app milestones",
                        lines: [
                            "Deeper DriveFS parsing beyond root preferences",
                            "Richer control-plane flows for logs and settings",
                            "Beta release packaging for a downloadable app"
                        ]
                    )
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
        .navigationTitle("Overview")
    }

    private var inventorySection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: "Scope Inventory",
                    subtitle: "Discovered Drive-managed locations, support status, and the current persisted inventory state."
                )
                stats
                scopesSection
                warningsSection
            }
            .padding(20)
        }
        .navigationTitle("Inventory")
    }

    private var logsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: "Logs",
                    subtitle: "Reserved for audit events, incidents, and later helper-driven activity."
                )

                placeholderPanel(
                    title: "Not implemented yet",
                    systemImage: "text.justify.left",
                    description: "The current beta app shell does not yet persist or present event logs. This section exists so the app structure is ready for later audit and incident views."
                )
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
                    subtitle: "Reserved for future app preferences, per-scope policy controls, and environment guidance."
                )

                placeholderPanel(
                    title: "Not implemented yet",
                    systemImage: "slider.horizontal.3",
                    description: "The current beta app shell does not yet expose configurable policies or settings. This section is the intended home for later per-scope controls and app preferences."
                )
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

    private var stats: some View {
        let report = viewModel.report
        let scopes = report?.scopes ?? []

        return HStack(spacing: 12) {
            statCard(title: "Scopes", value: "\(scopes.count)")
            statCard(title: "Supported", value: "\(scopes.filter { $0.supportStatus == .supported }.count)")
            statCard(title: "Audit Only", value: "\(scopes.filter { $0.supportStatus == .auditOnly }.count)")
            statCard(title: "Warnings", value: "\(report?.warnings.count ?? 0)")
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
                                if let accountID = scope.accountID, !accountID.isEmpty {
                                    metadataLabel("Account", value: accountID)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Warnings")
                .font(.headline)

            if let report = viewModel.report, !report.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(report.warnings, id: \.code) { warning in
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
}
