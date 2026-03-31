import Foundation
import DriveIconGuardShared

public enum ProtectionServiceMode: String, Codable, Equatable, Sendable {
    case inactive
    case embedded
    case helperAvailable
    case helperRequired
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
    public var eventSourceDescription: String

    public init(
        mode: ProtectionServiceMode,
        activeProtectedScopeCount: Int,
        detail: String,
        helperExecutablePath: String? = nil,
        eventSourceDescription: String = "No process-attributed helper event source is active."
    ) {
        self.mode = mode
        self.activeProtectedScopeCount = activeProtectedScopeCount
        self.detail = detail
        self.helperExecutablePath = helperExecutablePath
        self.eventSourceDescription = eventSourceDescription
    }
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
    public var status: String
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
        status: String,
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
