import Foundation

public enum ScopeKind: String, Codable, Equatable, Sendable {
    case myDrive
    case backupFolder
    case removableVolume
    case networkVolume
    case photosLibrary
}

public enum DriveMode: String, Codable, Equatable, Sendable {
    case stream
    case mirror
    case backup
}

public enum ScopeSource: String, Codable, Equatable, Sendable {
    case config
    case inferred
    case confirmed
}

public enum VolumeKind: String, Codable, Equatable, Sendable {
    case internalVolume = "internal"
    case external
    case removable
    case network
    case systemManaged
    case unknown
}

public enum FileSystemKind: String, Codable, Equatable, Sendable {
    case apfs
    case hfsplus
    case exfat
    case smb
    case other
    case unknown
}

public enum SupportStatus: String, Codable, Equatable, Sendable {
    case supported
    case auditOnly
    case unsupported
}

public enum EnforcementMode: String, Codable, Equatable, Sendable {
    case off
    case auditOnly
    case blockKnownArtefacts
}

public struct DriveManagedScope: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var accountID: String?
    public var displayName: String
    public var path: String
    public var scopeKind: ScopeKind
    public var driveMode: DriveMode
    public var source: ScopeSource
    public var volumeKind: VolumeKind
    public var fileSystemKind: FileSystemKind
    public var supportStatus: SupportStatus
    public var enforcementMode: EnforcementMode

    public init(
        id: UUID = UUID(),
        accountID: String? = nil,
        displayName: String,
        path: String,
        scopeKind: ScopeKind,
        driveMode: DriveMode,
        source: ScopeSource,
        volumeKind: VolumeKind,
        fileSystemKind: FileSystemKind,
        supportStatus: SupportStatus,
        enforcementMode: EnforcementMode = .auditOnly
    ) {
        self.id = id
        self.accountID = accountID
        self.displayName = displayName
        self.path = path
        self.scopeKind = scopeKind
        self.driveMode = driveMode
        self.source = source
        self.volumeKind = volumeKind
        self.fileSystemKind = fileSystemKind
        self.supportStatus = supportStatus
        self.enforcementMode = enforcementMode
    }
}
