import Foundation
import DriveIconGuardIPC

enum ProtectionServiceXPCCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func encodeOutcome(_ outcome: ProtectionServiceCommandOutcome) -> NSData {
        encodedData(outcome)
    }

    static func decodeOutcome(_ data: Data) throws -> ProtectionServiceCommandOutcome {
        try decoder.decode(ProtectionServiceCommandOutcome.self, from: data)
    }

    static func encodeConfiguration(_ configuration: ProtectionServiceConfiguration) -> NSData {
        encodedData(configuration)
    }

    static func decodeConfiguration(_ data: Data) throws -> ProtectionServiceConfiguration {
        try decoder.decode(ProtectionServiceConfiguration.self, from: data)
    }

    static func encodeEvents(_ events: [ProtectionServiceEventPayload]) -> NSData {
        encodedData(events)
    }

    static func decodeEvents(_ data: Data) throws -> [ProtectionServiceEventPayload] {
        try decoder.decode([ProtectionServiceEventPayload].self, from: data)
    }

    private static func encodedData<T: Encodable>(_ value: T) -> NSData {
        do {
            return try encoder.encode(value) as NSData
        } catch {
            let fallback = ProtectionServiceCommandOutcome(
                command: .queryStatus,
                accepted: false,
                detail: "Failed to encode XPC payload: \(error.localizedDescription)",
                failureReason: .invalidConfiguration,
                status: ProtectionStatusFactory.unavailable()
            )
            return (try? encoder.encode(fallback) as NSData) ?? NSData()
        }
    }
}
