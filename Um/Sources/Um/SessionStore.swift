import Foundation
import Combine

/// A completed session record, persisted to disk.
struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let durationSeconds: TimeInterval
    let totalCount: Int
    let counts: [String: Int]
    let ratePerMinute: Double

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var formattedDate: String {
        Self.dateFormatter.string(from: date)
    }

    var formattedDuration: String {
        let total = Int(durationSeconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Reads / writes session history to ~/Library/Application Support/Um/sessions.json
class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published var sessions: [SessionRecord] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first!
        let umDir = appSupport.appendingPathComponent("Um", isDirectory: true)
        try? FileManager.default.createDirectory(at: umDir,
                                                  withIntermediateDirectories: true)
        fileURL = umDir.appendingPathComponent("sessions.json")
        load()
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            sessions = try decoder.decode([SessionRecord].self, from: data)
        } catch {
            print("SessionStore: failed to load — \(error.localizedDescription)")
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("SessionStore: failed to save — \(error.localizedDescription)")
        }
    }

    // MARK: - Record a completed session

    func recordSession(from counter: FillerWordCounter) {
        guard counter.sessionDuration >= 5 else { return } // skip trivially short sessions
        let record = SessionRecord(
            id: UUID(),
            date: Date(),
            durationSeconds: counter.sessionDuration,
            totalCount: counter.totalCount,
            counts: counter.counts,
            ratePerMinute: counter.ratePerMinute
        )
        sessions.append(record)
        save()
    }

    func deleteSession(_ session: SessionRecord) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    func clearAll() {
        sessions.removeAll()
        save()
    }

    // MARK: - Analytics

    /// Average filler rate across all sessions
    var averageRate: Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0.0) { $0 + $1.ratePerMinute }
        return total / Double(sessions.count)
    }

    /// Average rate for the last N sessions
    func averageRate(last n: Int) -> Double {
        let recent = sessions.suffix(n)
        guard !recent.isEmpty else { return 0 }
        let total = recent.reduce(0.0) { $0 + $1.ratePerMinute }
        return total / Double(recent.count)
    }

    /// Total sessions recorded
    var sessionCount: Int { sessions.count }

    /// Total time tracked across all sessions
    var totalTime: TimeInterval {
        sessions.reduce(0) { $0 + $1.durationSeconds }
    }

    /// Trend in filler rate across the last N sessions (negative = improving, positive = worsening).
    /// Compares first-half vs second-half averages within the window.
    func trend(last n: Int) -> Double {
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
