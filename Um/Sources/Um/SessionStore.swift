import Combine
import Foundation
import UmCore
import os

private let logger = Logger(subsystem: "com.r3dbars.um", category: "SessionStore")

/// Reads / writes session history to ~/Library/Application Support/Um/sessions.json
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published var sessions: [SessionRecord] = []

    private let archive: SessionArchive
    private var historyUnreadable = false

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        archive = SessionArchive(fileURL: url)
        do {
            sessions = try archive.load()
        } catch {
            historyUnreadable = true
            sessions = []
            logger.error("Session history is unreadable; refusing later overwrites: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let umDir = appSupport.appendingPathComponent("Um", isDirectory: true)
        try? FileManager.default.createDirectory(at: umDir, withIntermediateDirectories: true)
        return umDir.appendingPathComponent("sessions.json")
    }

    func save() {
        guard !historyUnreadable else {
            logger.error("Refusing to overwrite unreadable session history")
            return
        }
        do {
            try archive.save(sessions)
        } catch {
            logger.error("Failed to save sessions: \(error.localizedDescription, privacy: .public)")
        }
    }

    func recordSession(from counter: FillerWordCounter) {
        guard SessionLifecycle.shouldPersist(duration: counter.sessionDuration) else { return }
        let record = SessionRecord(
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

    var averageRate: Double { SessionAnalytics.averageRate(of: sessions) }

    func averageRate(last n: Int) -> Double {
        SessionAnalytics.averageRate(of: sessions, last: n)
    }

    var sessionCount: Int { sessions.count }

    var totalTime: TimeInterval { SessionAnalytics.totalTime(of: sessions) }

    func trend(last n: Int) -> Double {
        SessionAnalytics.trend(of: sessions, last: n)
    }
}
