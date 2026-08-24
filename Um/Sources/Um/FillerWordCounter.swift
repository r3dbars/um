import Combine
import Foundation
import UmCore
import os

private let logger = Logger(subsystem: "com.r3dbars.um", category: "FillerWordCounter")

/// Tracks filler word occurrences across a session.
final class FillerWordCounter: ObservableObject {
    static let shared = FillerWordCounter()

    @Published var trackedWords: [String] = Preferences.defaultWords
    @Published var counts: [String: Int] = [:]
    @Published var totalCount: Int = 0
    @Published var sessionDuration: TimeInterval = 0
    @Published var isActive: Bool = false

    private var sessionStartTime: Date?
    private var sessionTimer: Timer?
    private var lastProcessedTranscript: String = ""

    init() {
        resetCounts()
    }

    func updateTrackedWords(_ words: [String]) {
        let added = words.filter { !trackedWords.contains($0) }
        let removed = trackedWords.filter { !words.contains($0) }
        if !added.isEmpty { logger.info("Words added: \(added.joined(separator: ", "), privacy: .public)") }
        if !removed.isEmpty { logger.info("Words removed: \(removed.joined(separator: ", "), privacy: .public)") }
        trackedWords = words
        for word in words where counts[word] == nil {
            counts[word] = 0
        }
    }

    func startSession() {
        trackedWords = Preferences.shared.trackedWords
        logger.info("Session starting, tracking \(self.trackedWords.joined(separator: ", "), privacy: .public)")
        resetCounts()
        isActive = true
        sessionStartTime = Date()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStartTime else { return }
            self.sessionDuration = Date().timeIntervalSince(start)
        }
        NotificationManager.shared.resetTracking()
    }

    func stopSession() {
        isActive = false
        sessionTimer?.invalidate()
        sessionTimer = nil
        SessionStore.shared.recordSession(from: self)
    }

    func resetCounts() {
        counts = Dictionary(uniqueKeysWithValues: trackedWords.map { ($0, 0) })
        totalCount = 0
        sessionDuration = 0
        sessionStartTime = nil
        sessionTimer?.invalidate()
        lastProcessedTranscript = ""
    }

    func resetTranscriptTracking() {
        lastProcessedTranscript = ""
    }

    func processWhisperTranscript(_ transcript: String) {
        applyHits(WordMatcher.counts(in: transcript, words: trackedWords))
    }

    func processTranscript(_ transcript: String) {
        guard !transcript.isEmpty else { return }

        let newPortion: String
        if transcript.count > lastProcessedTranscript.count {
            let start = transcript.index(transcript.startIndex, offsetBy: lastProcessedTranscript.count)
            newPortion = String(transcript[start...])
        } else {
            newPortion = transcript
        }
        lastProcessedTranscript = transcript
        guard !newPortion.isEmpty else { return }
        applyHits(WordMatcher.counts(in: newPortion, words: trackedWords))
    }

    private func applyHits(_ hits: [String: Int]) {
        guard !hits.isEmpty else { return }
        var added = 0
        var matched: [String] = []
        for (word, count) in hits {
            counts[word, default: 0] += count
            added += count
            matched.append(count == 1 ? "\"\(word)\"" : "\"\(word)\" x\(count)")
        }
        totalCount += added
        logger.info("Detected: \(matched.joined(separator: ", "), privacy: .public) — total now \(self.totalCount)")
    }

    var sortedCounts: [(word: String, count: Int)] {
        counts
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { (word: $0.key, count: $0.value) }
    }

    var ratePerMinute: Double {
        guard sessionDuration > 0 else { return 0 }
        return Double(totalCount) / (sessionDuration / 60)
    }

    var formattedDuration: String {
        let total = Int(sessionDuration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
