import Foundation
import DriveIconGuardIPC
import DriveIconGuardShared

public struct EndpointSecurityProcessMetadata: Equatable, Sendable {
    public var pid: Int32
    public var executablePath: String
    public var displayName: String
    public var bundleID: String?
    public var signingIdentity: String?

    public init(
        pid: Int32,
        executablePath: String,
        displayName: String,
        bundleID: String? = nil,
        signingIdentity: String? = nil
    ) {
        self.pid = pid
        self.executablePath = executablePath
        self.displayName = displayName
        self.bundleID = bundleID
        self.signingIdentity = signingIdentity
    }
}

public struct EndpointSecurityFileCandidateEvent: Equatable, Sendable {
    public var timestamp: Date
    public var operation: FileEventOperation
    public var targetPath: String
    public var process: EndpointSecurityProcessMetadata

    public init(
        timestamp: Date = Date(),
        operation: FileEventOperation,
        targetPath: String,
        process: EndpointSecurityProcessMetadata
    ) {
        self.timestamp = timestamp
        self.operation = operation
        self.targetPath = targetPath
        self.process = process
    }
}

public struct EndpointSecurityEventMapper {
    private let processClassifier: GoogleDriveProcessClassifier

    public init(processClassifier: GoogleDriveProcessClassifier = GoogleDriveProcessClassifier()) {
        self.processClassifier = processClassifier
    }

    public func map(_ source: EndpointSecurityFileCandidateEvent) -> ProcessAttributedFileEvent {
        let signature = ProcessSignature(
            bundleID: source.process.bundleID,
            executablePath: source.process.executablePath,
            signingIdentity: source.process.signingIdentity,
            displayName: source.process.displayName,
            isGoogleDriveRelated: processClassifier.isGoogleDriveRelated(
                ProcessSignature(
                    bundleID: source.process.bundleID,
                    executablePath: source.process.executablePath,
                    signingIdentity: source.process.signingIdentity,
                    displayName: source.process.displayName,
                    isGoogleDriveRelated: false
                )
            )
        )

        return ProcessAttributedFileEvent(
            timestamp: source.timestamp,
            processSignature: signature,
            targetPath: source.targetPath,
            operation: source.operation
        )
    }
}
