import Foundation
import DriveIconGuardIPC

public enum ProtectionHelperBuildInfoResolver {
    public static func bundled(
        bundle: Bundle = .main,
        helperExecutablePath: String?
    ) -> ProtectionHelperBuildInfo? {
        guard helperExecutablePath != nil || bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") != nil else {
            return nil
        }

        return ProtectionHelperBuildInfo(
            version: infoString("CFBundleShortVersionString", in: bundle),
            buildNumber: infoString("CFBundleVersion", in: bundle),
            releaseTag: infoString("DriveIconGuardReleaseTag", in: bundle),
            gitCommit: infoString("DriveIconGuardGitCommit", in: bundle),
            executablePath: helperExecutablePath
        )
    }

    public static func installed(
        receiptLocator: ProtectionInstallationReceiptLocator = ProtectionInstallationReceiptLocator()
    ) -> ProtectionHelperBuildInfo? {
        guard case .loaded(let receipt) = receiptLocator.loadReceipt() else {
            return nil
        }

        return ProtectionHelperBuildInfo(
            version: receipt.helperVersion,
            buildNumber: receipt.helperBuildNumber,
            releaseTag: receipt.helperReleaseTag,
            gitCommit: receipt.helperGitCommit,
            executablePath: receipt.helperExecutablePath,
            installedAt: receipt.installedAt
        )
    }

    public static func running(
        launchdStatus: ProtectionServiceLaunchdStatus?,
        bundled: ProtectionHelperBuildInfo?,
        installed: ProtectionHelperBuildInfo?
    ) -> ProtectionHelperBuildInfo? {
        guard let runningPath = runningExecutablePath(from: launchdStatus) else {
            return nil
        }

        if let bundled, bundled.executablePath == runningPath {
            return bundled
        }

        if let installed, installed.executablePath == runningPath {
            return installed
        }

        return ProtectionHelperBuildInfo(executablePath: runningPath)
    }

    public static func augment(
        _ snapshot: ProtectionServiceStatusSnapshot,
        launchdStatus: ProtectionServiceLaunchdStatus?,
        receiptLocator: ProtectionInstallationReceiptLocator = ProtectionInstallationReceiptLocator(),
        bundle: Bundle = .main
    ) -> ProtectionServiceStatusSnapshot {
        var updated = snapshot
        let bundled = bundled(bundle: bundle, helperExecutablePath: snapshot.helperExecutablePath)
        let installed = installed(receiptLocator: receiptLocator)
        let running = running(launchdStatus: launchdStatus, bundled: bundled, installed: installed)

        updated.bundledHelperBuild = bundled
        updated.installedHelperBuild = installed
        updated.runningHelperBuild = running

        let versionStatus = resolveStatus(
            bundled: bundled,
            installed: installed,
            running: running,
            installationState: snapshot.installationState
        )
        updated.helperUpdateStatus = versionStatus.status
        updated.helperUpdateDescription = versionStatus.description

        return updated
    }

    private static func resolveStatus(
        bundled: ProtectionHelperBuildInfo?,
        installed: ProtectionHelperBuildInfo?,
        running: ProtectionHelperBuildInfo?,
        installationState: ProtectionInstallationState
    ) -> (status: ProtectionHelperUpdateStatus, description: String) {
        guard installationState == .installed else {
            return (.unknown, "Helper update status will be available after the helper is installed.")
        }

        guard let bundled else {
            return (.unknown, "Bundled helper build metadata is unavailable in the current app bundle.")
        }

        guard let installed else {
            return (.unknown, "Installed helper build metadata could not be loaded from the installation receipt.")
        }

        if installed.executablePath != nil,
           bundled.executablePath != nil,
           installed.executablePath != bundled.executablePath,
           sameBuild(installed, bundled) {
            return (.mismatch, "The installed helper reports the same build as the bundled helper, but it points at a different executable path. Use Update Helper to realign the installed service.")
        }

        if !sameBuild(installed, bundled) {
            return (.outdated, "The installed helper build does not match the bundled helper build. Use Update Helper to install the current bundled helper.")
        }

        if let running,
           let runningPath = running.executablePath,
           let bundledPath = bundled.executablePath,
           runningPath != bundledPath {
            return (.mismatch, "launchd is running a helper from a different executable path than the current bundled helper.")
        }

        if let running,
           running.versionLine == nil,
           running.releaseIdentityLine == nil,
           running.executablePath != nil {
            return (.mismatch, "launchd is running a helper whose build metadata could not be confirmed against the current bundled app.")
        }

        return (.current, "Installed helper matches the bundled helper build.")
    }

    private static func sameBuild(_ lhs: ProtectionHelperBuildInfo, _ rhs: ProtectionHelperBuildInfo) -> Bool {
        if let lhsReleaseTag = lhs.releaseTag,
           let rhsReleaseTag = rhs.releaseTag,
           lhsReleaseTag == rhsReleaseTag {
            return true
        }

        if let lhsCommit = lhs.gitCommit,
           let rhsCommit = rhs.gitCommit,
           lhsCommit == rhsCommit {
            return true
        }

        return lhs.version == rhs.version && lhs.buildNumber == rhs.buildNumber
    }

    private static func runningExecutablePath(from launchdStatus: ProtectionServiceLaunchdStatus?) -> String? {
        guard let detail = launchdStatus?.detail else {
            return nil
        }

        for line in detail.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("program = ") else {
                continue
            }
            return String(trimmed.dropFirst("program = ".count))
        }

        return nil
    }

    private static func infoString(_ key: String, in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) else {
            return nil
        }

        if let string = value as? String, !string.isEmpty {
            return string
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return nil
    }
}
