import DriveIconGuardIPC
import DriveIconGuardXPCClient
import Foundation

private func makeVersioningTempRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("helper-versioning-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeVersionedBundle(
    in root: URL,
    version: String,
    build: String,
    releaseTag: String,
    gitCommit: String
) throws -> Bundle {
    let bundleURL = root
        .appendingPathComponent("Google Drive Icon Guard.app", isDirectory: true)
        .appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

    let info: [String: Any] = [
        "CFBundleIdentifier": "com.richardgeorgedavis.google-drive-icon-guard.beta",
        "CFBundleName": "Google Drive Icon Guard",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build,
        "DriveIconGuardReleaseTag": releaseTag,
        "DriveIconGuardGitCommit": gitCommit
    ]
    let infoURL = bundleURL.appendingPathComponent("Info.plist", isDirectory: false)
    let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try data.write(to: infoURL)

    guard let bundle = Bundle(url: bundleURL.deletingLastPathComponent()) else {
        throw NSError(domain: "ProtectionHelperVersioningTests", code: 1)
    }
    return bundle
}

private func makeReceiptLocator(root: URL) -> ProtectionInstallationReceiptLocator {
    ProtectionInstallationReceiptLocator(
        currentDirectoryPath: root.path,
        registrationPaths: ProtectionServiceRegistrationPaths(
            applicationSupportDirectory: root.appendingPathComponent("ApplicationSupport", isDirectory: true),
            launchAgentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true)
        )
    )
}

private func writeVersionedReceipt(
    in root: URL,
    state: ProtectionInstallationState = .installed,
    helperPath: String,
    version: String,
    build: String,
    releaseTag: String,
    gitCommit: String
) throws {
    let receiptPath = root
        .appendingPathComponent("Installer", isDirectory: true)
        .appendingPathComponent("installation-receipt.json", isDirectory: false)
    try FileManager.default.createDirectory(at: receiptPath.deletingLastPathComponent(), withIntermediateDirectories: true)

    let receipt = ProtectionInstallationReceipt(
        state: state,
        detail: "Helper registration verified by receipt.",
        helperExecutablePath: helperPath,
        helperVersion: version,
        helperBuildNumber: build,
        helperReleaseTag: releaseTag,
        helperGitCommit: gitCommit,
        installedAt: Date(timeIntervalSince1970: 1_711_273_600)
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(receipt).write(to: receiptPath)
}

private func makeBaseSnapshot(helperPath: String) -> ProtectionServiceStatusSnapshot {
    ProtectionServiceStatusSnapshot(
        mode: .helperAvailable,
        activeProtectedScopeCount: 1,
        detail: "Helper is available.",
        helperExecutablePath: helperPath,
        eventSourceState: .bundled,
        eventSourceDescription: "Bundled helper is present.",
        installationState: .installed,
        installationDescription: "Installed."
    )
}

#if canImport(Testing)
import Testing

@Test
func helperUpdateStatusIsCurrentWhenInstalledReceiptMatchesBundledHelper() throws {
    let tempRoot = try makeVersioningTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let helperPath = tempRoot.appendingPathComponent("Helpers/drive-icon-guard-helper", isDirectory: false).path
    let bundle = try makeVersionedBundle(in: tempRoot, version: "0.1.0", build: "3", releaseTag: "beta-0.1.0-beta.3", gitCommit: "abc123")
    try writeVersionedReceipt(in: tempRoot, helperPath: helperPath, version: "0.1.0", build: "3", releaseTag: "beta-0.1.0-beta.3", gitCommit: "abc123")

    let updated = ProtectionHelperBuildInfoResolver.augment(
        makeBaseSnapshot(helperPath: helperPath),
        launchdStatus: nil,
        receiptLocator: makeReceiptLocator(root: tempRoot),
        bundle: bundle
    )

    #expect(updated.helperUpdateStatus == .current)
    #expect(updated.helperUpdateDescription.contains("matches"))
    #expect(updated.installedHelperBuild?.releaseTag == "beta-0.1.0-beta.3")
}

@Test
func helperUpdateStatusIsOutdatedWhenInstalledReceiptDiffersFromBundledHelper() throws {
    let tempRoot = try makeVersioningTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let helperPath = tempRoot.appendingPathComponent("Helpers/drive-icon-guard-helper", isDirectory: false).path
    let bundle = try makeVersionedBundle(in: tempRoot, version: "0.2.0", build: "5", releaseTag: "beta-0.2.0-beta.5", gitCommit: "def456")
    try writeVersionedReceipt(in: tempRoot, helperPath: helperPath, version: "0.1.0", build: "3", releaseTag: "beta-0.1.0-beta.3", gitCommit: "abc123")

    let updated = ProtectionHelperBuildInfoResolver.augment(
        makeBaseSnapshot(helperPath: helperPath),
        launchdStatus: nil,
        receiptLocator: makeReceiptLocator(root: tempRoot),
        bundle: bundle
    )

    #expect(updated.helperUpdateStatus == .outdated)
    #expect(updated.helperUpdateDescription.contains("does not match"))
}

@Test
func helperUpdateStatusIsMismatchWhenLaunchdRunsDifferentExecutablePath() throws {
    let tempRoot = try makeVersioningTempRoot()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let helperPath = tempRoot.appendingPathComponent("Helpers/drive-icon-guard-helper", isDirectory: false).path
    let bundle = try makeVersionedBundle(in: tempRoot, version: "0.1.0", build: "3", releaseTag: "beta-0.1.0-beta.3", gitCommit: "abc123")
    try writeVersionedReceipt(in: tempRoot, helperPath: helperPath, version: "0.1.0", build: "3", releaseTag: "beta-0.1.0-beta.3", gitCommit: "abc123")

    let updated = ProtectionHelperBuildInfoResolver.augment(
        makeBaseSnapshot(helperPath: helperPath),
        launchdStatus: ProtectionServiceLaunchdStatus(
            domainTarget: "gui/501",
            serviceTarget: "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper",
            isLoaded: true,
            detail: "program = /Applications/Old Build.app/Contents/Helpers/drive-icon-guard-helper"
        ),
        receiptLocator: makeReceiptLocator(root: tempRoot),
        bundle: bundle
    )

    #expect(updated.helperUpdateStatus == ProtectionHelperUpdateStatus.mismatch)
    #expect(updated.helperUpdateDescription.contains("different executable path"))
}

#elseif canImport(XCTest)
import XCTest

final class ProtectionHelperVersioningTests: XCTestCase {
    func testHelperUpdateStatusIsCurrentWhenInstalledReceiptMatchesBundledHelper() throws {
        let tempRoot = try makeVersioningTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let helperPath = tempRoot.appendingPathComponent("Helpers/drive-icon-guard-helper", isDirectory: false).path
        let bundle = try makeVersionedBundle(in: tempRoot, version: "0.1.0", build: "3", releaseTag: "beta-0.1.0-beta.3", gitCommit: "abc123")
        try writeVersionedReceipt(in: tempRoot, helperPath: helperPath, version: "0.1.0", build: "3", releaseTag: "beta-0.1.0-beta.3", gitCommit: "abc123")

        let updated = ProtectionHelperBuildInfoResolver.augment(
            makeBaseSnapshot(helperPath: helperPath),
            launchdStatus: nil,
            receiptLocator: makeReceiptLocator(root: tempRoot),
            bundle: bundle
        )

        XCTAssertEqual(updated.helperUpdateStatus, .current)
        XCTAssertTrue(updated.helperUpdateDescription.contains("matches"))
        XCTAssertEqual(updated.installedHelperBuild?.releaseTag, "beta-0.1.0-beta.3")
    }

    func testHelperUpdateStatusIsOutdatedWhenInstalledReceiptDiffersFromBundledHelper() throws {
        let tempRoot = try makeVersioningTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let helperPath = tempRoot.appendingPathComponent("Helpers/drive-icon-guard-helper", isDirectory: false).path
        let bundle = try makeVersionedBundle(in: tempRoot, version: "0.2.0", build: "5", releaseTag: "beta-0.2.0-beta.5", gitCommit: "def456")
        try writeVersionedReceipt(in: tempRoot, helperPath: helperPath, version: "0.1.0", build: "3", releaseTag: "beta-0.1.0-beta.3", gitCommit: "abc123")

        let updated = ProtectionHelperBuildInfoResolver.augment(
            makeBaseSnapshot(helperPath: helperPath),
            launchdStatus: nil,
            receiptLocator: makeReceiptLocator(root: tempRoot),
            bundle: bundle
        )

        XCTAssertEqual(updated.helperUpdateStatus, .outdated)
        XCTAssertTrue(updated.helperUpdateDescription.contains("does not match"))
    }

    func testHelperUpdateStatusIsMismatchWhenLaunchdRunsDifferentExecutablePath() throws {
        let tempRoot = try makeVersioningTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let helperPath = tempRoot.appendingPathComponent("Helpers/drive-icon-guard-helper", isDirectory: false).path
        let bundle = try makeVersionedBundle(in: tempRoot, version: "0.1.0", build: "3", releaseTag: "beta-0.1.0-beta.3", gitCommit: "abc123")
        try writeVersionedReceipt(in: tempRoot, helperPath: helperPath, version: "0.1.0", build: "3", releaseTag: "beta-0.1.0-beta.3", gitCommit: "abc123")

        let updated = ProtectionHelperBuildInfoResolver.augment(
            makeBaseSnapshot(helperPath: helperPath),
            launchdStatus: ProtectionServiceLaunchdStatus(
                domainTarget: "gui/501",
                serviceTarget: "gui/501/com.richardgeorgedavis.google-drive-icon-guard.beta.helper",
                isLoaded: true,
                detail: "program = /Applications/Old Build.app/Contents/Helpers/drive-icon-guard-helper"
            ),
            receiptLocator: makeReceiptLocator(root: tempRoot),
            bundle: bundle
        )

        XCTAssertEqual(updated.helperUpdateStatus, .mismatch)
        XCTAssertTrue(updated.helperUpdateDescription.contains("different executable path"))
    }
}
#endif
