import Foundation

public final class ProtectionCircuitBreaker: @unchecked Sendable {
    private let threshold: Int
    private let window: TimeInterval
    private var timestampsByKey: [String: [Date]] = [:]

    public init(threshold: Int = 5, window: TimeInterval = 10) {
        self.threshold = threshold
        self.window = window
    }

    public func isStorm(key: String, now: Date = Date()) -> Bool {
        let cutoff = now.addingTimeInterval(-window)
        var timestamps = timestampsByKey[key, default: []].filter { $0 >= cutoff }
        timestamps.append(now)
        timestampsByKey[key] = timestamps
        return timestamps.count >= threshold
    }
}
