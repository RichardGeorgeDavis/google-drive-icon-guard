import Foundation
import DriveIconGuardIPC

public struct ReplayProcessAttributedEventLoader {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder? = nil) {
        if let decoder {
            self.decoder = decoder
            return
        }

        let resolvedDecoder = JSONDecoder()
        resolvedDecoder.dateDecodingStrategy = .iso8601
        self.decoder = resolvedDecoder
    }

    public func load(from url: URL) throws -> [ProcessAttributedFileEvent] {
        let data = try Data(contentsOf: url)

        if let events = try? decoder.decode([ProcessAttributedFileEvent].self, from: data) {
            return events
        }

        let lines = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !lines.isEmpty else {
            return []
        }

        return try lines.map { line in
            try decoder.decode(ProcessAttributedFileEvent.self, from: Data(line.utf8))
        }
    }
}
