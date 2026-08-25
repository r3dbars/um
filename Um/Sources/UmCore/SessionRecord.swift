import Foundation

/// A completed listening session persisted to disk.
public struct SessionRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let durationSeconds: TimeInterval
    public let totalCount: Int
    public let counts: [String: Int]
    public let ratePerMinute: Double

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        durationSeconds: TimeInterval,
        totalCount: Int,
        counts: [String: Int],
        ratePerMinute: Double
    ) {
        self.id = id
        self.date = date
        self.durationSeconds = durationSeconds
        self.totalCount = totalCount
        self.counts = counts
        self.ratePerMinute = ratePerMinute
    }

    public var formattedDate: String {
        Self.dateFormatter.string(from: date)
    }

    public var formattedDuration: String {
        let total = Int(durationSeconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

/// Rate and trend math over session history.
public enum SessionAnalytics {
    public static func averageRate(of sessions: [SessionRecord]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0.0) { $0 + $1.ratePerMinute }
        return total / Double(sessions.count)
    }

    public static func averageRate(of sessions: [SessionRecord], last n: Int) -> Double {
        averageRate(of: Array(sessions.suffix(n)))
    }

    public static func totalTime(of sessions: [SessionRecord]) -> TimeInterval {
        sessions.reduce(0) { $0 + $1.durationSeconds }
    }

    /// Negative means the later half is slower (improving). Needs at least 4 sessions.
    public static func trend(of sessions: [SessionRecord], last n: Int) -> Double {
        let recent = Array(sessions.suffix(n))
        guard recent.count >= 4 else { return 0 }
        let half = recent.count / 2
        let earlier = recent.prefix(half)
        let later = recent.suffix(half)
        let earlierAvg = earlier.reduce(0.0) { $0 + $1.ratePerMinute } / Double(half)
        let laterAvg = later.reduce(0.0) { $0 + $1.ratePerMinute } / Double(half)
        return laterAvg - earlierAvg
    }
}
