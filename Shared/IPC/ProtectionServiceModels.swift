import Foundation
import DriveIconGuardShared

public enum ProtectionServiceMode: String, Codable, Equatable, Sendable {
    case inactive
    case embedded
    case helperAvailable
    case helperRequired
}

public enum ProtectionEventSourceState: String, Codable, Equatable, Sendable {
    case unavailable
    case bundled
    case needsApproval
    case ready
    case error
}

public enum ProtectionInstallationState: String, Codable, Equatable, Sendable {
    case unavailable
    case bundledOnly
    case installPlanReady
    case installed
    case error
}

public enum ProtectionHelperUpdateStatus: String, Codable, Equatable, Sendable {
    case current
    case outdated
    case unknown
    case mismatch
}

public struct ProtectionHelperBuildInfo: Codable, Equatable, Sendable {
    public var version: String?
    public var buildNumber: String?
    public var releaseTag: String?
    public var gitCommit: String?
    public var executablePath: String?
    public var installedAt: Date?

    public init(
        version: String? = nil,
        buildNumber: String? = nil,
        releaseTag: String? = nil,
        gitCommit: String? = nil,
        executablePath: String? = nil,
        installedAt: Date? = nil
    ) {
        self.version = version
        self.buildNumber = buildNumber
        self.releaseTag = releaseTag
        self.gitCommit = gitCommit
        self.executablePath = executablePath
        self.installedAt = installedAt
    }

    public var versionLine: String? {
        switch (version, buildNumber) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty:
            return "\(version) (\(build))"
        case let (version?, _) where !version.isEmpty:
            return version
        case let (_, build?) where !build.isEmpty:
            return "Build \(build)"
        default:
            return nil
        }
    }

    public var releaseIdentityLine: String? {
        var parts: [String] = []
        if let releaseTag, !releaseTag.isEmpty {
            parts.append("tag \(releaseTag)")
        }
        if let gitCommit, !gitCommit.isEmpty {
            parts.append("commit \(gitCommit)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

public struct ProtectionInstallationStatus: Codable, Equatable, Sendable {
    public var state: ProtectionInstallationState
    public var detail: String

    public init(
        state: ProtectionInstallationState,
        detail: String
    ) {
        self.state = state
        self.detail = detail
    }
}

public struct ProtectionEventSourceStatus: Codable, Equatable, Sendable {
    public var state: ProtectionEventSourceState
    public var detail: String

    public init(
        state: ProtectionEventSourceState,
        detail: String
    ) {
        self.state = state
        self.detail = detail
    }
}

public struct ProtectionServiceConfiguration: Codable, Equatable, Sendable {
    public var liveProtectionEnabled: Bool
    public var scopes: [DriveManagedScope]

    public init(
        liveProtectionEnabled: Bool,
        scopes: [DriveManagedScope]
    ) {
        self.liveProtectionEnabled = liveProtectionEnabled
        self.scopes = scopes
    }
}

public struct ProtectionServiceStatusSnapshot: Codable, Equatable, Sendable {
    public var mode: ProtectionServiceMode
    public var activeProtectedScopeCount: Int
    public var detail: String
    public var helperExecutablePath: String?
    public var eventSourceState: ProtectionEventSourceState
    public var eventSourceDescription: String
    public var installationState: ProtectionInstallationState
    public var installationDescription: String
    public var bundledHelperBuild: ProtectionHelperBuildInfo?
    public var installedHelperBuild: ProtectionHelperBuildInfo?
    public var runningHelperBuild: ProtectionHelperBuildInfo?
    public var helperUpdateStatus: ProtectionHelperUpdateStatus
    public var helperUpdateDescription: String

    public init(
        mode: ProtectionServiceMode,
        activeProtectedScopeCount: Int,
        detail: String,
        helperExecutablePath: String? = nil,
        eventSourceState: ProtectionEventSourceState = .unavailable,
        eventSourceDescription: String = "No process-attributed helper event source is active.",
        installationState: ProtectionInstallationState = .unavailable,
        installationDescription: String = "No helper installation resources are available.",
        bundledHelperBuild: ProtectionHelperBuildInfo? = nil,
        installedHelperBuild: ProtectionHelperBuildInfo? = nil,
        runningHelperBuild: ProtectionHelperBuildInfo? = nil,
        helperUpdateStatus: ProtectionHelperUpdateStatus = .unknown,
        helperUpdateDescription: String = "Helper update status is not available."
    ) {
        self.mode = mode
        self.activeProtectedScopeCount = activeProtectedScopeCount
        self.detail = detail
        self.helperExecutablePath = helperExecutablePath
        self.eventSourceState = eventSourceState
        self.eventSourceDescription = eventSourceDescription
        self.installationState = installationState
        self.installationDescription = installationDescription
        self.bundledHelperBuild = bundledHelperBuild
        self.installedHelperBuild = installedHelperBuild
        self.runningHelperBuild = runningHelperBuild
        self.helperUpdateStatus = helperUpdateStatus
        self.helperUpdateDescription = helperUpdateDescription
    }
}

public enum ProtectionRemediationStatus: String, Codable, Equatable, Sendable {
    case applied
    case partialFailure
    case noCandidates
    case unavailable
    case unreadable
}

public struct ProtectionServiceEventPayload: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var scopeID: UUID
    public var scopePath: String
    public var detectedArtefactCount: Int
    public var detectedBytes: Int
    public var removedCount: Int
    public var removedBytes: Int
    public var status: ProtectionRemediationStatus
    public var message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        scopeID: UUID,
        scopePath: String,
        detectedArtefactCount: Int,
        detectedBytes: Int,
        removedCount: Int,
        removedBytes: Int,
        status: ProtectionRemediationStatus,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.scopeID = scopeID
        self.scopePath = scopePath
        self.detectedArtefactCount = detectedArtefactCount
        self.detectedBytes = detectedBytes
        self.removedCount = removedCount
        self.removedBytes = removedBytes
        self.status = status
        self.message = message
    }
}

public enum ProtectionStatusFactory {
    public static func unavailable() -> ProtectionServiceStatusSnapshot {
        ProtectionServiceStatusSnapshot(
            mode: .inactive,
            activeProtectedScopeCount: 0,
            detail: "Automatic blocking remains in audit mode until a process-aware helper with Endpoint Security events is available.",
            eventSourceState: .unavailable,
            eventSourceDescription: "Current helper support is limited to replay/test scaffolding. Live Google-Drive-only blocking still requires a macOS Endpoint Security event source.",
            installationState: .unavailable,
            installationDescription: "No helper installation resources are available in this build.",
            helperUpdateStatus: .unknown,
            helperUpdateDescription: "No helper build is installed yet."
        )
    }
}
