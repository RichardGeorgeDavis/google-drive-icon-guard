import Foundation

public enum PolicyDecision: String, Codable, Equatable, Sendable {
    case allow
    case auditOnly
    case deny
    case stormSuppressed
}

public struct EventRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public var timestamp: Date
    public var processSignature: ProcessSignature
    public var scopeID: UUID?
    public var targetPath: String
    public var artefactType: ArtefactType
    public var decision: PolicyDecision
    public var aggregatedCount: Int
    public var rawEventType: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        processSignature: ProcessSignature,
        scopeID: UUID? = nil,
        targetPath: String,
        artefactType: ArtefactType,
        decision: PolicyDecision,
        aggregatedCount: Int = 1,
        rawEventType: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.processSignature = processSignature
        self.scopeID = scopeID
        self.targetPath = targetPath
        self.artefactType = artefactType
        self.decision = decision
        self.aggregatedCount = aggregatedCount
        self.rawEventType = rawEventType
    }
}
