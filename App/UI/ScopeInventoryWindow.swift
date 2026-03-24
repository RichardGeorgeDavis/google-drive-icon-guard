import DriveIconGuardScopeInventory
import DriveIconGuardShared
import SwiftUI

struct ScopeInventoryWindow: View {
    @StateObject private var viewModel = ScopeInventoryViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            stats
            scopesSection
            warningsSection
        }
        .padding(20)
        .frame(minWidth: 940, minHeight: 620)
        .task {
            if viewModel.report == nil {
                viewModel.refresh()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Google Drive Scope Inventory")
                    .font(.system(size: 28, weight: .semibold))

                Text("Current beta viewer for discovered Drive-managed locations, support status, and persisted inventory state.")
                    .foregroundStyle(.secondary)

                if let persistedPath = viewModel.persistedPath {
                    Text(persistedPath)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            Button {
                viewModel.refresh()
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
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
                List(report.scopes) { scope in
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
                    .padding(.vertical, 6)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
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
