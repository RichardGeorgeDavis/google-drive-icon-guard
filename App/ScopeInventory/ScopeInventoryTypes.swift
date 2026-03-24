import Foundation
import DriveIconGuardShared

public struct DiscoveryWarning: Codable, Equatable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct ScopeAssessment: Codable, Equatable, Sendable {
    public var supportStatus: SupportStatus
    public var rationale: [String]

    public init(supportStatus: SupportStatus, rationale: [String]) {
        self.supportStatus = supportStatus
        self.rationale = rationale
    }
}

public struct ScopeInventoryReport: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var configLocations: [String]
    public var scopes: [DriveManagedScope]
    public var warnings: [DiscoveryWarning]

    public init(
        generatedAt: Date = Date(),
        configLocations: [String],
        scopes: [DriveManagedScope],
        warnings: [DiscoveryWarning]
    ) {
        self.generatedAt = generatedAt
        self.configLocations = configLocations
        self.scopes = scopes
        self.warnings = warnings
    }
}

public struct VolumeClassification: Equatable, Sendable {
    public var volumeKind: VolumeKind
    public var fileSystemKind: FileSystemKind

    public init(volumeKind: VolumeKind, fileSystemKind: FileSystemKind) {
        self.volumeKind = volumeKind
        self.fileSystemKind = fileSystemKind
    }
}
