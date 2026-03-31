import Foundation
import DriveIconGuardShared

public enum FileEventOperation: String, Codable, Equatable, Sendable {
    case create
    case modify
    case rename
    case delete
}

public struct ProcessAttributedFileEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var processSignature: ProcessSignature
    public var targetPath: String
    public var operation: FileEventOperation

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        processSignature: ProcessSignature,
        targetPath: String,
        operation: FileEventOperation
    ) {
        self.id = id
        self.timestamp = timestamp
        self.processSignature = processSignature
        self.targetPath = targetPath
        self.operation = operation
    }
}

public enum HelperProtectionDecision: String, Codable, Equatable, Sendable {
    case allow
    case auditOnly
    case deny
    case stormSuppressed
}

public struct HelperProtectionEvaluation: Codable, Equatable, Sendable {
    public var event: ProcessAttributedFileEvent
    public var matchedScopeID: UUID?
    public var matchedArtefactType: ArtefactType?
    public var decision: HelperProtectionDecision
    public var reason: String

    public init(
        event: ProcessAttributedFileEvent,
        matchedScopeID: UUID? = nil,
        matchedArtefactType: ArtefactType? = nil,
        decision: HelperProtectionDecision,
        reason: String
    ) {
        self.event = event
        self.matchedScopeID = matchedScopeID
        self.matchedArtefactType = matchedArtefactType
        self.decision = decision
        self.reason = reason
    }
}
