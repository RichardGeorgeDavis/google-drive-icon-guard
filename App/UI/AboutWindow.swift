import AppKit
import DriveIconGuardIPC
import DriveIconGuardXPCClient
import Foundation
import SwiftUI

enum AppSupportLinks {
    static let repository = URL(string: "https://github.com/RichardGeorgeDavis/google-drive-icon-guard")!
    static let issues = URL(string: "https://github.com/RichardGeorgeDavis/google-drive-icon-guard/issues")!
    static let releases = URL(string: "https://github.com/RichardGeorgeDavis/google-drive-icon-guard/releases")!
}

struct AboutWindow: View {
    @State private var selectedPane: AboutPane = .overview
    private let diagnostics = AppSupportDiagnostics.current()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            panePicker
            ScrollView {
                activePane
            }
        }
        .padding(18)
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 620, minHeight: 420, idealHeight: 520, maxHeight: 620)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Google Drive Icon Guard")
                        .font(.title3.weight(.semibold))

                    Text(diagnostics.versionLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let releaseIdentity = diagnostics.releaseIdentityLine {
                    Text(releaseIdentity)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Text("Audit Google Drive-managed locations for `Icon\\r`, `._*`, and related Finder artefacts before cleanup or protection changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var panePicker: some View {
        Picker("About Section", selection: $selectedPane) {
            ForEach(AboutPane.allCases) { pane in
                Text(pane.title)
                    .tag(pane)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var activePane: some View {
        switch selectedPane {
        case .overview:
            summaryCard
        case .support:
            supportCard
        case .diagnostics:
            diagnosticsCard
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Current Build Boundary", systemImage: "scope")
                .font(.headline)

            Text("This is an active prerelease build. Inventory, findings export, cleanup preview, and helper lifecycle testing are in scope. True Google-Drive-only live blocking while the app is closed is not the shipped claim yet.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                bullet("Use this build to validate scope detection, findings review, markdown export, and helper install or removal behavior.")
                bullet("Treat the background helper as a test path. If install or startup behaves badly, disable it in Login Items and report the exact steps.")
                bullet(diagnostics.gatekeeperExpectation)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Support", systemImage: "lifepreserver")
                .font(.headline)

            Text("Support and bug reports are handled on GitHub.")
                .font(.callout)

            VStack(alignment: .leading, spacing: 6) {
                Link("Repository: github.com/RichardGeorgeDavis/google-drive-icon-guard", destination: AppSupportLinks.repository)
                Link("Issues: github.com/RichardGeorgeDavis/google-drive-icon-guard/issues", destination: AppSupportLinks.issues)
                Link("Releases: github.com/RichardGeorgeDavis/google-drive-icon-guard/releases", destination: AppSupportLinks.releases)
            }
            .font(.callout)

            Text("When filing an issue, include the release tag or commit, macOS version, whether the app ran from `/Applications`, and whether the background helper or Login Item was enabled.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Copy Support Details") {
                    diagnostics.copyToPasteboard()
                }

                Button("Report Issue") {
                    NSWorkspace.shared.open(diagnostics.issueReportURL)
                }

                Link("Open Releases", destination: AppSupportLinks.releases)
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Diagnostics", systemImage: "doc.text.magnifyingglass")
                .font(.headline)

            diagnosticsSection("Build") {
                diagnosticRow("Bundle ID", diagnostics.bundleIdentifier)
                diagnosticRow("Bundle Path", diagnostics.bundlePath)
                diagnosticRow("Executable", diagnostics.executableName)
                diagnosticRow("macOS", diagnostics.macosVersion)
                if let releaseTag = diagnostics.releaseTag {
                    diagnosticRow("Release Tag", releaseTag)
                }
                if let gitCommit = diagnostics.gitCommit {
                    diagnosticRow("Git Commit", gitCommit)
                }
                if let gitRef = diagnostics.gitRef, gitRef != diagnostics.releaseTag {
                    diagnosticRow("Git Ref", gitRef)
                }
            }

            Divider()

            diagnosticsSection("Release Trust") {
                diagnosticRow("Signing", diagnostics.signingStatus)
                diagnosticRow("Notarization", diagnostics.notarizationStatus)
                if let codesignIdentity = diagnostics.codesignIdentity {
                    diagnosticRow("Signing Identity", codesignIdentity)
                }
            }

            Divider()

            diagnosticsSection("Helper Boundary") {
                diagnosticRow("LaunchAgent Label", diagnostics.launchdLabel)
                diagnosticRow("Mach Service", diagnostics.machServiceName)
                diagnosticRow("launchd Service", diagnostics.serviceTarget)
                diagnosticRow("Helper Install State", diagnostics.installationState)
                diagnosticRow("Helper Install Detail", diagnostics.installationDetail)
                diagnosticRow("launchd Status", diagnostics.launchdLoadedStatus)
                diagnosticRow("launchd Detail", diagnostics.launchdDetail)
                if let helperExecutablePath = diagnostics.helperExecutablePath {
                    diagnosticRow("Helper Executable", helperExecutablePath)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func diagnosticsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
        }
        .font(.caption.monospaced())
        .textSelection(.enabled)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .foregroundStyle(.secondary)
                .frame(width: 124, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum AboutPane: String, CaseIterable, Identifiable {
    case overview
    case support
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .support:
            return "Support"
        case .diagnostics:
            return "Diagnostics"
        }
    }
}

struct AppSupportDiagnostics {
    let appName: String
    let shortVersion: String?
    let buildVersion: String?
    let bundleIdentifier: String
    let bundlePath: String
    let executableName: String
    let macosVersion: String
    let releaseTag: String?
    let gitCommit: String?
    let gitRef: String?
    let signingStatus: String
    let notarizationStatus: String
    let codesignIdentity: String?
    let launchdLabel: String
    let machServiceName: String
    let serviceTarget: String
    let launchdLoadedStatus: String
    let launchdDetail: String
    let installationState: String
    let installationDetail: String
    let helperExecutablePath: String?

    var versionLine: String {
        switch (shortVersion, buildVersion) {
        case let (short?, build?) where !short.isEmpty && !build.isEmpty:
            return "\(short) (\(build))"
        case let (short?, _) where !short.isEmpty:
            return short
        case let (_, build?) where !build.isEmpty:
            return "Build \(build)"
        default:
            return executableName
        }
    }

    var releaseIdentityLine: String? {
        var parts: [String] = []
        if let releaseTag {
            parts.append("tag \(releaseTag)")
        }
        if let gitCommit {
            parts.append("commit \(gitCommit)")
        }
        guard !parts.isEmpty else {
            return nil
        }
        return parts.joined(separator: " • ")
    }

    var gatekeeperExpectation: String {
        if notarizationStatus == "Not notarized" || signingStatus == "Unsigned" || signingStatus == "Ad hoc signed" {
            return "Expect Gatekeeper friction on first launch. Right-click → Open may still be required because this build is not fully release-trusted."
        }
        if notarizationStatus == "Notarized" {
            return "This build reports notarization, so Gatekeeper friction should be lower than the default unsigned prerelease path."
        }
        return "If you are testing from `/Applications`, mention that in the issue because helper receipt and LaunchAgent state depend on the installed bundle path."
    }

    var supportSummary: String {
        """
        App: \(appName)
        Version: \(versionLine)
        Release tag: \(releaseTag ?? "unknown")
        Git commit: \(gitCommit ?? "unknown")
        Git ref: \(gitRef ?? "unknown")
        Bundle ID: \(bundleIdentifier)
        Bundle Path: \(bundlePath)
        Executable: \(executableName)
        macOS: \(macosVersion)
        Signing: \(signingStatus)
        Notarization: \(notarizationStatus)
        Signing Identity: \(codesignIdentity ?? "unknown")
        LaunchAgent Label: \(launchdLabel)
        Mach Service: \(machServiceName)
        launchd Service: \(serviceTarget)
        launchd Status: \(launchdLoadedStatus)
        launchd Detail: \(launchdDetail)
        Helper Install State: \(installationState)
        Helper Install Detail: \(installationDetail)
        Helper Executable: \(helperExecutablePath ?? "none")
        GitHub Issues: \(AppSupportLinks.issues.absoluteString)
        """
    }

    var issueReportURL: URL {
        var components = URLComponents(url: AppSupportLinks.issues.appendingPathComponent("new"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "title", value: issueTitle),
            URLQueryItem(name: "body", value: issueBody)
        ]
        return components?.url ?? AppSupportLinks.issues
    }

    private var issueTitle: String {
        if let releaseTag {
            return "[\(releaseTag)] Tester report"
        }
        if let gitCommit {
            return "[\(gitCommit)] Tester report"
        }
        return "Tester report"
    }

    private var issueBody: String {
        """
        ## Summary

        Describe the problem clearly.

        ## What Happened

        -

        ## Expected

        -

        ## Support Details

        ```text
        \(supportSummary)
        ```
        """
    }

    static func current(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        registrationConfiguration: ProtectionServiceRegistrationConfiguration = .beta
    ) -> AppSupportDiagnostics {
        let bundleURL = bundle.bundleURL
        let releaseTag = infoString("DriveIconGuardReleaseTag", in: bundle)
        let embeddedGitCommit = infoString("DriveIconGuardGitCommit", in: bundle)
        let embeddedGitRef = infoString("DriveIconGuardGitRef", in: bundle)
        let localGitContext = LocalGitContext.resolve(startingAt: bundleURL)
        let installationStatusResolver = ProtectionInstallationStatusResolver()
        let installationStatus = installationStatusResolver.resolve()
        let helperExecutablePath = installationStatusResolver.helperExecutablePath
        let launchdManager = ProtectionServiceLaunchdManager(registrationConfiguration: registrationConfiguration)
        let launchdStatus = (try? ProtectionServiceDeploymentCoordinator().status()) ?? ProtectionServiceLaunchdStatus(
            domainTarget: launchdManager.domainTarget,
            serviceTarget: launchdManager.serviceTarget,
            isLoaded: false,
            detail: "launchctl status could not be loaded from the app process."
        )
        let trustInfo = ReleaseTrustInfo.resolve(for: bundle)

        return AppSupportDiagnostics(
            appName: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Google Drive Icon Guard",
            shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildVersion: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
            bundlePath: bundleURL.path,
            executableName: bundle.executableURL?.lastPathComponent ?? processInfo.processName,
            macosVersion: processInfo.operatingSystemVersionString,
            releaseTag: releaseTag,
            gitCommit: embeddedGitCommit ?? localGitContext.commit,
            gitRef: embeddedGitRef ?? localGitContext.ref,
            signingStatus: trustInfo.signingStatus,
            notarizationStatus: trustInfo.notarizationStatus,
            codesignIdentity: trustInfo.codesignIdentity,
            launchdLabel: registrationConfiguration.launchdLabel,
            machServiceName: registrationConfiguration.machServiceName,
            serviceTarget: launchdStatus.serviceTarget,
            launchdLoadedStatus: launchdStatus.isLoaded ? "Loaded" : "Not loaded",
            launchdDetail: condensedDetail(launchdStatus.detail),
            installationState: installationStatus.state.rawValue,
            installationDetail: condensedDetail(installationStatus.detail),
            helperExecutablePath: helperExecutablePath
        )
    }

    func copyToPasteboard(pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(supportSummary, forType: .string)
    }

    private static func infoString(_ key: String, in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) else {
            return nil
        }
        if let string = value as? String, !string.isEmpty {
            return string
        }
        return nil
    }

    private static func condensedDetail(_ value: String, maxLength: Int = 240) -> String {
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
}

private struct LocalGitContext {
    let commit: String?
    let ref: String?

    static func resolve(startingAt bundleURL: URL) -> LocalGitContext {
        let candidates = [
            bundleURL.path,
            bundleURL.deletingLastPathComponent().path,
            FileManager.default.currentDirectoryPath
        ]

        for candidate in candidates {
            guard let repositoryRoot = repositoryRoot(startingAt: URL(fileURLWithPath: candidate, isDirectory: true)) else {
                continue
            }

            let commit = shell("/usr/bin/git", ["-C", repositoryRoot.path, "rev-parse", "--short", "HEAD"])
            let ref = shell("/usr/bin/git", ["-C", repositoryRoot.path, "describe", "--tags", "--always", "--dirty"])
            return LocalGitContext(commit: commit, ref: ref)
        }

        return LocalGitContext(commit: nil, ref: nil)
    }

    private static func repositoryRoot(startingAt url: URL) -> URL? {
        let fileManager = FileManager.default
        var current = url

        while current.path != "/" {
            if fileManager.fileExists(atPath: current.appendingPathComponent(".git", isDirectory: true).path) {
                return current
            }
            current.deleteLastPathComponent()
        }

        return nil
    }

    private static func shell(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }
}

private struct ReleaseTrustInfo {
    let signingStatus: String
    let notarizationStatus: String
    let codesignIdentity: String?

    static func resolve(for bundle: Bundle) -> ReleaseTrustInfo {
        let bundledNotarized = boolInfo("DriveIconGuardNotarized", in: bundle)
        let bundledCodesigned = boolInfo("DriveIconGuardCodesigned", in: bundle)
        let bundledIdentity = stringInfo("DriveIconGuardCodesignIdentity", in: bundle)

        let inspectedSignature = CodeSignatureInspection.inspect(path: bundle.bundleURL.path)
        let signingStatus = inspectedSignature.signingStatus ?? (bundledCodesigned == true ? "Signed" : "Unsigned")
        let notarizationStatus: String
        switch bundledNotarized {
        case true:
            notarizationStatus = "Notarized"
        case false:
            notarizationStatus = "Not notarized"
        case nil:
            notarizationStatus = "Unknown"
        }

        return ReleaseTrustInfo(
            signingStatus: signingStatus,
            notarizationStatus: notarizationStatus,
            codesignIdentity: bundledIdentity ?? inspectedSignature.codesignIdentity
        )
    }

    private static func stringInfo(_ key: String, in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func boolInfo(_ key: String, in bundle: Bundle) -> Bool? {
        if let value = bundle.object(forInfoDictionaryKey: key) as? Bool {
            return value
        }
        if let number = bundle.object(forInfoDictionaryKey: key) as? NSNumber {
            return number.boolValue
        }
        if let string = bundle.object(forInfoDictionaryKey: key) as? String {
            switch string.lowercased() {
            case "true", "yes", "1":
                return true
            case "false", "no", "0":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}

private struct CodeSignatureInspection {
    let signingStatus: String?
    let codesignIdentity: String?

    static func inspect(path: String) -> CodeSignatureInspection {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dv", "--verbose=4", path]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CodeSignatureInspection(signingStatus: nil, codesignIdentity: nil)
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard !output.isEmpty else {
            return CodeSignatureInspection(signingStatus: nil, codesignIdentity: nil)
        }

        var signature: String?
        var teamIdentifier: String?
        var authority: String?

        for line in output.split(separator: "\n") {
            if line.hasPrefix("Signature=") {
                signature = String(line.dropFirst("Signature=".count))
            } else if line.hasPrefix("TeamIdentifier=") {
                let value = String(line.dropFirst("TeamIdentifier=".count))
                teamIdentifier = value == "not set" ? nil : value
            } else if line.hasPrefix("Authority="), authority == nil {
                authority = String(line.dropFirst("Authority=".count))
            }
        }

        let signingStatus: String?
        switch signature?.lowercased() {
        case "adhoc":
            signingStatus = "Ad hoc signed"
        case let value? where !value.isEmpty:
            if let authority, !authority.isEmpty {
                signingStatus = "Signed (\(authority))"
            } else if let teamIdentifier {
                signingStatus = "Signed (team \(teamIdentifier))"
            } else {
                signingStatus = "Signed"
            }
        case nil:
            signingStatus = nil
        default:
            signingStatus = "Unsigned"
        }

        return CodeSignatureInspection(
            signingStatus: signingStatus,
            codesignIdentity: authority ?? teamIdentifier
        )
    }
}
