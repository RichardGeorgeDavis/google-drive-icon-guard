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

public struct ArtefactTypeSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: ArtefactType { artefactType }

    public var artefactType: ArtefactType
    public var count: Int
    public var totalBytes: Int

    public init(artefactType: ArtefactType, count: Int, totalBytes: Int) {
        self.artefactType = artefactType
        self.count = count
        self.totalBytes = totalBytes
    }
}

public struct ScopeArtefactScanResult: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { scopeID }

    public var scopeID: UUID
    public var scopeDisplayName: String
    public var scopePath: String
    public var scanStatus: ScopeArtefactScanStatus
    public var scannedDirectoryCount: Int
    public var inspectedFileCount: Int
    public var skippedSymbolicLinkCount: Int
    public var matchedArtefactCount: Int
    public var matchedBytes: Int
    public var artefactSummaries: [ArtefactTypeSummary]
    public var sampleMatches: [ArtefactSample]

    public init(
        scopeID: UUID,
        scopeDisplayName: String,
        scopePath: String,
        scanStatus: ScopeArtefactScanStatus,
        scannedDirectoryCount: Int = 0,
        inspectedFileCount: Int = 0,
        skippedSymbolicLinkCount: Int = 0,
        matchedArtefactCount: Int = 0,
        matchedBytes: Int = 0,
        artefactSummaries: [ArtefactTypeSummary] = [],
        sampleMatches: [ArtefactSample] = []
    ) {
        self.scopeID = scopeID
        self.scopeDisplayName = scopeDisplayName
        self.scopePath = scopePath
        self.scanStatus = scanStatus
        self.scannedDirectoryCount = scannedDirectoryCount
        self.inspectedFileCount = inspectedFileCount
        self.skippedSymbolicLinkCount = skippedSymbolicLinkCount
        self.matchedArtefactCount = matchedArtefactCount
        self.matchedBytes = matchedBytes
        self.artefactSummaries = artefactSummaries
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

public struct PersistedScopeInventorySnapshot: Equatable, Sendable {
    public var url: URL
    public var report: ScopeInventoryReport

    public init(url: URL, report: ScopeInventoryReport) {
        self.url = url
        self.report = report
    }
}

public struct ScopeInventoryHistoryDelta: Equatable, Sendable {
    public var scopeCount: Int
    public var artefactCount: Int
    public var matchedScopeCount: Int
    public var totalBytes: Int
    public var warningCount: Int
    public var perScopeChanges: [ScopeHistoryChange]

    public init(
        scopeCount: Int = 0,
        artefactCount: Int = 0,
        matchedScopeCount: Int = 0,
        totalBytes: Int = 0,
        warningCount: Int = 0,
        perScopeChanges: [ScopeHistoryChange] = []
    ) {
        self.scopeCount = scopeCount
        self.artefactCount = artefactCount
        self.matchedScopeCount = matchedScopeCount
        self.totalBytes = totalBytes
        self.warningCount = warningCount
        self.perScopeChanges = perScopeChanges
    }
}

public struct ScopeInventoryHistoryComparison: Equatable, Sendable {
    public var currentGeneratedAt: Date
    public var previousGeneratedAt: Date
    public var delta: ScopeInventoryHistoryDelta

    public init(
        currentGeneratedAt: Date,
        previousGeneratedAt: Date,
        delta: ScopeInventoryHistoryDelta
    ) {
        self.currentGeneratedAt = currentGeneratedAt
        self.previousGeneratedAt = previousGeneratedAt
        self.delta = delta
    }
}

public enum ScopeReviewPriority: String, Codable, Equatable, Sendable {
    case ready
    case attention
    case monitor
    case blocked
}

public struct ScopeReviewPlan: Equatable, Sendable {
    public var scopeID: UUID
    public var priority: ScopeReviewPriority
    public var headline: String
    public var recommendedAction: String
    public var rationale: [String]
    public var operatorNotes: [String]

    public init(
        scopeID: UUID,
        priority: ScopeReviewPriority,
        headline: String,
        recommendedAction: String,
        rationale: [String],
        operatorNotes: [String]
    ) {
        self.scopeID = scopeID
        self.priority = priority
        self.headline = headline
        self.recommendedAction = recommendedAction
        self.rationale = rationale
        self.operatorNotes = operatorNotes
    }
}

public enum ScopeHistoryChangeKind: String, Codable, Equatable, Sendable {
    case added
    case removed
    case changed
}

public struct ScopeHistoryChange: Equatable, Sendable, Identifiable {
    public var id: String { scopePath }

    public var scopePath: String
    public var displayName: String
    public var changeKind: ScopeHistoryChangeKind
    public var artefactDelta: Int
    public var byteDelta: Int
    public var warningDelta: Int

    public init(
        scopePath: String,
        displayName: String,
        changeKind: ScopeHistoryChangeKind,
        artefactDelta: Int,
        byteDelta: Int,
        warningDelta: Int
    ) {
        self.scopePath = scopePath
        self.displayName = displayName
        self.changeKind = changeKind
        self.artefactDelta = artefactDelta
        self.byteDelta = byteDelta
        self.warningDelta = warningDelta
    }
}

public struct PersistedActivityLog: Codable, Equatable, Sendable {
    public var events: [EventRecord]

    public init(events: [EventRecord] = []) {
        self.events = events
    }
}

public enum ScopeRemediationPreviewStatus: String, Equatable, Sendable {
    case ready
    case noCandidates
    case unavailable
    case unreadable
}

public enum ScopeRemediationApplyStatus: String, Equatable, Sendable {
    case applied
    case partialFailure
    case noCandidates
    case unavailable
    case unreadable
}

public struct RemediationCandidate: Equatable, Identifiable, Sendable {
    public var id: String { path }

    public var path: String
    public var relativePath: String
    public var artefactType: ArtefactType
    public var sizeBytes: Int

    public init(path: String, relativePath: String, artefactType: ArtefactType, sizeBytes: Int) {
        self.path = path
        self.relativePath = relativePath
        self.artefactType = artefactType
        self.sizeBytes = sizeBytes
    }
}

public struct ScopeRemediationPreview: Equatable, Sendable {
    public var scopeID: UUID
    public var scopeDisplayName: String
    public var scopePath: String
    public var status: ScopeRemediationPreviewStatus
    public var recommendedAction: String
    public var totalCandidateCount: Int
    public var totalBytes: Int
    public var candidates: [RemediationCandidate]
    public var previewTruncated: Bool
    public var warnings: [DiscoveryWarning]

    public init(
        scopeID: UUID,
        scopeDisplayName: String,
        scopePath: String,
        status: ScopeRemediationPreviewStatus,
        recommendedAction: String,
        totalCandidateCount: Int = 0,
        totalBytes: Int = 0,
        candidates: [RemediationCandidate] = [],
        previewTruncated: Bool = false,
        warnings: [DiscoveryWarning] = []
    ) {
        self.scopeID = scopeID
        self.scopeDisplayName = scopeDisplayName
        self.scopePath = scopePath
        self.status = status
        self.recommendedAction = recommendedAction
        self.totalCandidateCount = totalCandidateCount
        self.totalBytes = totalBytes
        self.candidates = candidates
        self.previewTruncated = previewTruncated
        self.warnings = warnings
    }
}

public struct ScopeRemediationApplyResult: Equatable, Sendable {
    public var scopeID: UUID
    public var scopeDisplayName: String
    public var scopePath: String
    public var status: ScopeRemediationApplyStatus
    public var message: String
    public var removedCount: Int
    public var removedBytes: Int
    public var warnings: [DiscoveryWarning]

    public init(
        scopeID: UUID,
        scopeDisplayName: String,
        scopePath: String,
        status: ScopeRemediationApplyStatus,
        message: String,
        removedCount: Int = 0,
        removedBytes: Int = 0,
        warnings: [DiscoveryWarning] = []
    ) {
        self.scopeID = scopeID
        self.scopeDisplayName = scopeDisplayName
        self.scopePath = scopePath
        self.status = status
        self.message = message
        self.removedCount = removedCount
        self.removedBytes = removedBytes
        self.warnings = warnings
    }
}

public struct AggregateCleanupPreview: Equatable, Sendable {
    public var generatedAt: Date
    public var affectedScopeCount: Int
    public var skippedScopeCount: Int
    public var totalCandidateCount: Int
    public var totalBytes: Int
    public var readyScopePreviews: [ScopeRemediationPreview]
    public var skippedScopeNames: [String]
    public var warnings: [DiscoveryWarning]

    public init(
        generatedAt: Date = Date(),
        affectedScopeCount: Int,
        skippedScopeCount: Int,
        totalCandidateCount: Int,
        totalBytes: Int,
        readyScopePreviews: [ScopeRemediationPreview],
        skippedScopeNames: [String] = [],
        warnings: [DiscoveryWarning] = []
    ) {
        self.generatedAt = generatedAt
        self.affectedScopeCount = affectedScopeCount
        self.skippedScopeCount = skippedScopeCount
        self.totalCandidateCount = totalCandidateCount
        self.totalBytes = totalBytes
        self.readyScopePreviews = readyScopePreviews
        self.skippedScopeNames = skippedScopeNames
        self.warnings = warnings
    }
}

public struct AggregateCleanupApplyResult: Equatable, Sendable {
    public var processedScopeCount: Int
    public var appliedScopeCount: Int
    public var removedCount: Int
    public var removedBytes: Int
    public var results: [ScopeRemediationApplyResult]
    public var warnings: [DiscoveryWarning]

    public init(
        processedScopeCount: Int,
        appliedScopeCount: Int,
        removedCount: Int,
        removedBytes: Int,
        results: [ScopeRemediationApplyResult],
        warnings: [DiscoveryWarning] = []
    ) {
        self.processedScopeCount = processedScopeCount
        self.appliedScopeCount = appliedScopeCount
        self.removedCount = removedCount
        self.removedBytes = removedBytes
        self.results = results
        self.warnings = warnings
    }
}

public struct ScopeEnforcementEvent: Equatable, Sendable {
    public var scope: DriveManagedScope
    public var detectedArtefactCount: Int
    public var detectedBytes: Int
    public var applyResult: ScopeRemediationApplyResult

    public init(
        scope: DriveManagedScope,
        detectedArtefactCount: Int,
        detectedBytes: Int,
        applyResult: ScopeRemediationApplyResult
    ) {
        self.scope = scope
        self.detectedArtefactCount = detectedArtefactCount
        self.detectedBytes = detectedBytes
        self.applyResult = applyResult
    }
}
