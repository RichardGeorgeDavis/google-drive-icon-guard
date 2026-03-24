import Foundation
import DriveIconGuardShared

public struct GoogleDriveProbe {
    private let fileManager: FileManager
    private let driveFSRoot: String
    private let volumeClassifier: VolumeClassifier
    private let supportClassifier: ScopeSupportClassifier

    public init(
        fileManager: FileManager = .default,
        driveFSRoot: String = NSString(string: "~/Library/Application Support/Google/DriveFS").expandingTildeInPath,
        volumeClassifier: VolumeClassifier = VolumeClassifier(),
        supportClassifier: ScopeSupportClassifier = ScopeSupportClassifier()
    ) {
        self.fileManager = fileManager
        self.driveFSRoot = driveFSRoot
        self.volumeClassifier = volumeClassifier
        self.supportClassifier = supportClassifier
    }

    public func discover() -> ScopeInventoryReport {
        let configLocations = discoverConfigLocations()
        var warnings: [DiscoveryWarning] = [
            DiscoveryWarning(
                code: "per_account_settings_pending",
                message: "Discovery currently relies on DriveFS root preferences plus CloudStorage fallback; deeper per-account settings parsing is still pending."
            )
        ]
        let configuredScopesResult = discoverConfiguredScopes()
        warnings.append(contentsOf: configuredScopesResult.warnings)

        var scopes = configuredScopesResult.scopes
        let hasConfiguredMyDrive = scopes.contains(where: { $0.scopeKind == .myDrive })

        if !hasConfiguredMyDrive {
            let inferredStreamScopes = discoverStreamScopes()
            scopes.append(contentsOf: inferredStreamScopes)

            if inferredStreamScopes.isEmpty {
                warnings.append(
                    DiscoveryWarning(
                        code: "no_visible_stream_scopes",
                        message: "No visible Google Drive stream scopes were found in ~/Library/CloudStorage."
                    )
                )
            }
        }

        if scopes.isEmpty {
            warnings.append(
                DiscoveryWarning(
                    code: "no_scopes_discovered",
                    message: "No Google Drive-managed scopes were discovered from DriveFS root preferences or CloudStorage."
                )
            )
        }

        return ScopeInventoryReport(
            configLocations: configLocations,
            scopes: scopes.sorted(by: { $0.path < $1.path }),
            warnings: warnings
        )
    }

    private func discoverConfigLocations() -> [String] {
        let accountStore = DriveFSAccountStore(fileManager: fileManager, driveFSRoot: driveFSRoot)
        let rootPreferenceStore = DriveFSRootPreferenceStore(
            fileManager: fileManager,
            driveFSRoot: driveFSRoot,
            volumeClassifier: volumeClassifier,
            supportClassifier: supportClassifier
        )
        var locations = rootPreferenceStore.existingLocations()
        locations.append(contentsOf: accountStore.accountDatabasePaths())
        let legacyDrivePath = NSString(string: "~/Library/Application Support/Google/Drive").expandingTildeInPath

        if fileManager.fileExists(atPath: legacyDrivePath) {
            locations.append(legacyDrivePath)
        }

        return Array(Set(locations)).sorted()
    }

    private func discoverConfiguredScopes() -> (scopes: [DriveManagedScope], warnings: [DiscoveryWarning]) {
        let accountStore = DriveFSAccountStore(fileManager: fileManager, driveFSRoot: driveFSRoot)
        let bareRootPreferenceStore = DriveFSRootPreferenceStore(
            fileManager: fileManager,
            driveFSRoot: driveFSRoot,
            volumeClassifier: volumeClassifier,
            supportClassifier: supportClassifier
        )
        let databasePath = bareRootPreferenceStore.rootPreferenceDatabasePath()

        guard fileManager.fileExists(atPath: databasePath) else {
            return (
                [],
                [
                    DiscoveryWarning(
                        code: "root_preference_database_missing",
                        message: "DriveFS root_preference_sqlite.db was not found, so configured root discovery is unavailable."
                    )
                ]
            )
        }

        do {
            let confirmedRootIDsByAccount = try accountStore.confirmedRootIDsByAccount()
            let rootPreferenceStore = DriveFSRootPreferenceStore(
                fileManager: fileManager,
                driveFSRoot: driveFSRoot,
                volumeClassifier: volumeClassifier,
                supportClassifier: supportClassifier,
                confirmedRootIDsByAccount: confirmedRootIDsByAccount
            )
            let scopes = try rootPreferenceStore.discoverScopes()
            var warnings: [DiscoveryWarning] = []

            if scopes.isEmpty {
                warnings.append(
                    DiscoveryWarning(
                        code: "no_configured_roots_found",
                        message: "DriveFS root preferences were readable, but no active configured roots were found."
                    )
                )
            }

            let confirmedScopes = scopes.filter { $0.source == .confirmed }.count
            if confirmedScopes > 0 {
                warnings.append(
                    DiscoveryWarning(
                        code: "account_root_confirmation_active",
                        message: "Per-account DriveFS mirror databases confirmed \(confirmedScopes) configured root(s) beyond root_preference_sqlite.db."
                    )
                )
            } else {
                warnings.append(
                    DiscoveryWarning(
                        code: "account_root_confirmation_unavailable",
                        message: "Configured roots were loaded, but no per-account DriveFS root confirmations were available."
                    )
                )
            }

            return (scopes, warnings)
        } catch {
            return (
                [],
                [
                    DiscoveryWarning(
                        code: "root_preference_read_failed",
                        message: "DriveFS root preference parsing failed: \(error.localizedDescription)"
                    )
                ]
            )
        }
    }

    private func discoverStreamScopes() -> [DriveManagedScope] {
        let cloudStoragePath = NSString(string: "~/Library/CloudStorage").expandingTildeInPath

        guard fileManager.fileExists(atPath: cloudStoragePath) else {
            return []
        }

        let entries: [String]

        do {
            entries = try fileManager.contentsOfDirectory(atPath: cloudStoragePath)
        } catch {
            return []
        }

        return entries
            .filter { $0.lowercased().hasPrefix("googledrive") }
            .map { entryName in
                let scopePath = (cloudStoragePath as NSString).appendingPathComponent(entryName)
                let volume = volumeClassifier.classify(path: scopePath)
                let scope = DriveManagedScope(
                    displayName: entryName,
                    path: scopePath,
                    scopeKind: .myDrive,
                    driveMode: .stream,
                    source: .inferred,
                    volumeKind: volume.volumeKind,
                    fileSystemKind: volume.fileSystemKind,
                    supportStatus: .auditOnly
                )

                return supportClassifier.applyingAssessment(to: scope)
            }
    }
}
