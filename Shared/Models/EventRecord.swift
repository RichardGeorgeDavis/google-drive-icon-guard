import Foundation

public enum PolicyDecision: String, Codable, Equatable, Sendable {
    case allow
    case auditOnly
    case deny
    case stormSuppressed
}

public enum ActivityCategory: String, Codable, Equatable, Sendable {
    case helper
    case cleanup
    case protection
    case warning
    case inventory
}

public enum ActivitySeverity: String, Codable, Equatable, Sendable {
    case info
    case warning
    case error
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
    public var message: String?
    public var category: ActivityCategory
    public var severity: ActivitySeverity

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        processSignature: ProcessSignature,
        scopeID: UUID? = nil,
        targetPath: String,
        artefactType: ArtefactType,
        decision: PolicyDecision,
        aggregatedCount: Int = 1,
        rawEventType: String,
        message: String? = nil,
        category: ActivityCategory = .inventory,
        severity: ActivitySeverity = .info
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
        self.message = message
        self.category = category
        self.severity = severity
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case processSignature
        case scopeID
        case targetPath
        case artefactType
        case decision
        case aggregatedCount
        case rawEventType
        case message
        case category
        case severity
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        processSignature = try container.decode(ProcessSignature.self, forKey: .processSignature)
        scopeID = try container.decodeIfPresent(UUID.self, forKey: .scopeID)
        targetPath = try container.decode(String.self, forKey: .targetPath)
        artefactType = try container.decode(ArtefactType.self, forKey: .artefactType)
        decision = try container.decode(PolicyDecision.self, forKey: .decision)
        aggregatedCount = try container.decodeIfPresent(Int.self, forKey: .aggregatedCount) ?? 1
        rawEventType = try container.decode(String.self, forKey: .rawEventType)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        category = try container.decodeIfPresent(ActivityCategory.self, forKey: .category) ?? Self.defaultCategory(for: rawEventType)
        severity = try container.decodeIfPresent(ActivitySeverity.self, forKey: .severity) ?? Self.defaultSeverity(for: rawEventType)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(processSignature, forKey: .processSignature)
        try container.encodeIfPresent(scopeID, forKey: .scopeID)
        try container.encode(targetPath, forKey: .targetPath)
        try container.encode(artefactType, forKey: .artefactType)
        try container.encode(decision, forKey: .decision)
        try container.encode(aggregatedCount, forKey: .aggregatedCount)
        try container.encode(rawEventType, forKey: .rawEventType)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encode(category, forKey: .category)
        try container.encode(severity, forKey: .severity)
    }

    private static func defaultCategory(for rawEventType: String) -> ActivityCategory {
        switch rawEventType {
        case let value where value.hasPrefix("helper_"):
            return .helper
        case let value where value.hasPrefix("remediation_"):
            return .cleanup
        case let value where value.hasPrefix("live_protection_"):
            return .protection
        case let value where value.hasPrefix("warning_"):
            return .warning
        default:
            return .inventory
        }
    }

    private static func defaultSeverity(for rawEventType: String) -> ActivitySeverity {
        switch rawEventType {
        case let value where value.contains("failed") || value.contains("error"):
            return .error
        case let value where value.hasPrefix("warning_"):
            return .warning
        default:
            return .info
        }
    }
}
