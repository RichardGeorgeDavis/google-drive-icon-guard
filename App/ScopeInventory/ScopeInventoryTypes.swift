import Foundation
import DriveIconGuardShared

public struct DiscoveryWarning: Codable, Equatable, Hashable, Sendable {
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
    public var artefactInventory: ArtefactInventorySummary

    public init(
        generatedAt: Date = Date(),
        configLocations: [String],
        scopes: [DriveManagedScope],
        warnings: [DiscoveryWarning],
        artefactInventory: ArtefactInventorySummary = ArtefactInventorySummary()
    ) {
        self.generatedAt = generatedAt
        self.configLocations = configLocations
        self.scopes = scopes
        self.warnings = warnings
        self.artefactInventory = artefactInventory
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

public enum ScopeArtefactScanStatus: String, Codable, Equatable, Sendable {
    case scanned
    case skippedUnsupported
    case missingPath
    case unreadable
}

public struct ArtefactSample: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        "\(relativePath)|\(artefactType.rawValue)|\(ruleID)"
    }

    public var relativePath: String
    public var artefactType: ArtefactType
    public var ruleID: String
    public var ruleName: String
    public var sizeBytes: Int

    public init(
        relativePath: String,
        artefactType: ArtefactType,
        ruleID: String,
        ruleName: String,
        sizeBytes: Int
    ) {
        self.relativePath = relativePath
        self.artefactType = artefactType
        self.ruleID = ruleID
        self.ruleName = ruleName
        self.sizeBytes = sizeBytes
    }
}

public struct ScopeArtefactScanResult: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { scopeID }

    public var scopeID: UUID
    public var scopeDisplayName: String
    public var scopePath: String
    public var scanStatus: ScopeArtefactScanStatus
    public var matchedArtefactCount: Int
    public var matchedBytes: Int
    public var sampleMatches: [ArtefactSample]

    public init(
        scopeID: UUID,
        scopeDisplayName: String,
        scopePath: String,
        scanStatus: ScopeArtefactScanStatus,
        matchedArtefactCount: Int = 0,
        matchedBytes: Int = 0,
        sampleMatches: [ArtefactSample] = []
    ) {
        self.scopeID = scopeID
        self.scopeDisplayName = scopeDisplayName
        self.scopePath = scopePath
        self.scanStatus = scanStatus
        self.matchedArtefactCount = matchedArtefactCount
        self.matchedBytes = matchedBytes
        self.sampleMatches = sampleMatches
    }
}

public struct ArtefactInventorySummary: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var scannedScopeCount: Int
    public var matchedScopeCount: Int
    public var totalArtefactCount: Int
    public var totalBytes: Int
    public var scopeResults: [ScopeArtefactScanResult]
    public var warnings: [DiscoveryWarning]

    public init(
        generatedAt: Date = Date(),
        scannedScopeCount: Int = 0,
        matchedScopeCount: Int = 0,
        totalArtefactCount: Int = 0,
        totalBytes: Int = 0,
        scopeResults: [ScopeArtefactScanResult] = [],
        warnings: [DiscoveryWarning] = []
    ) {
        self.generatedAt = generatedAt
        self.scannedScopeCount = scannedScopeCount
        self.matchedScopeCount = matchedScopeCount
        self.totalArtefactCount = totalArtefactCount
        self.totalBytes = totalBytes
        self.scopeResults = scopeResults
        self.warnings = warnings
    }
}
