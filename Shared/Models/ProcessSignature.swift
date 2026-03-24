import Foundation

public struct ProcessSignature: Codable, Equatable, Sendable {
    public var bundleID: String?
    public var executablePath: String
    public var signingIdentity: String?
    public var displayName: String
    public var isGoogleDriveRelated: Bool

    public init(
        bundleID: String? = nil,
        executablePath: String,
        signingIdentity: String? = nil,
        displayName: String,
        isGoogleDriveRelated: Bool
    ) {
        self.bundleID = bundleID
        self.executablePath = executablePath
        self.signingIdentity = signingIdentity
        self.displayName = displayName
        self.isGoogleDriveRelated = isGoogleDriveRelated
    }
}
