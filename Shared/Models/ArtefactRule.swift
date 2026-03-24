import Foundation

public enum ArtefactType: String, Codable, Equatable, Sendable {
    case iconFile
    case iconSidecar
    case folderMetadata
    case unknown
}

public enum ArtefactMatchType: String, Codable, Equatable, Sendable {
    case exactPath
    case filename
    case metadataKey
    case regex
}

public enum ArtefactConfidence: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low
}

public enum ArtefactAction: String, Codable, Equatable, Sendable {
    case allow
    case audit
    case deny
}

public struct ArtefactRule: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var artefactType: ArtefactType
    public var matchType: ArtefactMatchType
    public var matchValue: String
    public var confidence: ArtefactConfidence
    public var action: ArtefactAction

    public init(
        id: String,
        name: String,
        artefactType: ArtefactType,
        matchType: ArtefactMatchType,
        matchValue: String,
        confidence: ArtefactConfidence,
        action: ArtefactAction
    ) {
        self.id = id
        self.name = name
        self.artefactType = artefactType
        self.matchType = matchType
        self.matchValue = matchValue
        self.confidence = confidence
        self.action = action
    }
}
