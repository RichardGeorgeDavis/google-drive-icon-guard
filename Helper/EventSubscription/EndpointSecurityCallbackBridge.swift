import Foundation
import DriveIconGuardIPC

public enum EndpointSecurityRawOperation: String, Sendable {
    case create
    case rename
    case unlink
}

public struct EndpointSecurityRawCallbackEvent: Sendable {
    public var timestamp: Date
    public var operation: EndpointSecurityRawOperation
    public var targetPath: String
    public var process: EndpointSecurityProcessMetadata

    public init(
        timestamp: Date = Date(),
        operation: EndpointSecurityRawOperation,
        targetPath: String,
        process: EndpointSecurityProcessMetadata
    ) {
        self.timestamp = timestamp
        self.operation = operation
        self.targetPath = targetPath
        self.process = process
    }
}

public struct EndpointSecurityCallbackBridge {
    private let mapper: EndpointSecurityEventMapper

    public init(mapper: EndpointSecurityEventMapper = EndpointSecurityEventMapper()) {
        self.mapper = mapper
    }

    public func map(_ rawEvent: EndpointSecurityRawCallbackEvent) -> ProcessAttributedFileEvent? {
        let normalizedPath = rawEvent.targetPath.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        guard !normalizedPath.isEmpty else {
            return nil
        }

        let operation: FileEventOperation
        switch rawEvent.operation {
        case .create:
            operation = .create
        case .rename:
            operation = .rename
        case .unlink:
            operation = .delete
        }

        let candidate = EndpointSecurityFileCandidateEvent(
            timestamp: rawEvent.timestamp,
            operation: operation,
            targetPath: rawEvent.targetPath,
            process: rawEvent.process
        )
        return mapper.map(candidate)
    }
}
