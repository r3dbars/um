import Foundation
import Combine
import os

private let logger = Logger(subsystem: "com.um.app", category: "FillerWordCounter")

/// Tracks filler word occurrences across a session.
/// Thread-safe via main-thread publishing.
class FillerWordCounter: ObservableObject {
    static let shared = FillerWordCounter()

    // Words to detect — synced from Preferences
    @Published var trackedWords: [String] = Preferences.defaultWords

    @Published var counts: [String: Int] = [:]
    @Published var totalCount: Int = 0
    @Published var sessionDuration: TimeInterval = 0
    @Published var isActive: Bool = false

    private var sessionStartTime: Date?
    private var sessionTimer: Timer?

    // Track how much of the rolling transcript we've already processed
    // SFSpeechRecognizer gives us cumulative partial results within a segment
    private var lastProcessedTranscript: String = ""

    init() {
        resetCounts()
    }

    // MARK: - Word list sync

    /// Called by Preferences when the tracked word list changes.
    func updateTrackedWords(_ words: [String]) {
        let added = words.filter { !trackedWords.contains($0) }
        let removed = trackedWords.filter { !words.contains($0) }
        if !added.isEmpty { logger.info("Words added to tracking: \(added.joined(separator: ", "), privacy: .public)") }
        if !removed.isEmpty { logger.info("Words removed from tracking: \(removed.joined(separator: ", "), privacy: .public)") }
        trackedWords = words
        // Add any new words to counts without resetting existing counts
        for word in words where counts[word] == nil {
            counts[word] = 0
        }
    }

    // MARK: - Session Control

    func startSession() {
        // Sync word list from preferences before starting
        trackedWords = Preferences.shared.trackedWords
        logger.info("Session starting, tracking \(self.trackedWords.count) words: \(self.trackedWords.joined(separator: ", "), privacy: .public)")
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
        // Save session to history if it was meaningful
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

    /// Called when the recognition segment resets (result.isFinal == true)
    func resetTranscriptTracking() {
        lastProcessedTranscript = ""
    }

    // MARK: - Detection (Whisper — chunk-based)

    /// Process a complete transcript chunk from Whisper.
    /// Each chunk is independent — scan the full text for filler words.
    func processWhisperTranscript(_ transcript: String) {
        guard !transcript.isEmpty else { return }

        let text = transcript.lowercased()
        var added = 0
        var matched: [String] = []
        for word in trackedWords {
            let hits = countOccurrences(of: word, in: text)
            if hits > 0 {
                counts[word, default: 0] += hits
                added += hits
                matched.append(hits == 1 ? "\"\(word)\"" : "\"\(word)\" x\(hits)")
            }
        }
        if added > 0 {
            totalCount += added
            logger.info("Detected: \(matched.joined(separator: ", "), privacy: .public) — total now \(self.totalCount)")
        }
    }

    // MARK: - Detection (SFSpeechRecognizer — cumulative partial results)

    /// Process an incremental transcript from SFSpeechRecognizer.
    /// Only counts words in the *new* portion since last call.
    func processTranscript(_ transcript: String) {
        guard !transcript.isEmpty else { return }

        let newPortion: String
        if transcript.count > lastProcessedTranscript.count {
            let start = transcript.index(transcript.startIndex,
                                         offsetBy: lastProcessedTranscript.count)
            newPortion = String(transcript[start...])
        } else {
            // Transcript was reset by SFSpeechRecognizer starting a new segment
            newPortion = transcript
        }

        lastProcessedTranscript = transcript

        guard !newPortion.isEmpty else { return }

        var added = 0
        var matched: [String] = []
        for word in trackedWords {
            let hits = countOccurrences(of: word, in: newPortion.lowercased())
            if hits > 0 {
                counts[word, default: 0] += hits
                added += hits
                matched.append(hits == 1 ? "\"\(word)\"" : "\"\(word)\" x\(hits)")
            }
        }
        if added > 0 {
            totalCount += added
            logger.info("Detected: \(matched.joined(separator: ", "), privacy: .public) — total now \(self.totalCount)")
        }
    }

    // MARK: - Helpers

    private func countOccurrences(of target: String, in text: String) -> Int {
        // Use word-boundary regex so "like" doesn't match inside "likewise"
        let pattern: String
        if target.contains(" ") {
            // Multi-word phrase — no word boundaries needed between words
            pattern = "(?<![\\w])\(NSRegularExpression.escapedPattern(for: target))(?![\\w])"
        } else {
            pattern = "\\b\(NSRegularExpression.escapedPattern(for: target))\\b"
        }
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                    options: .caseInsensitive) else { return 0 }
        return regex.numberOfMatches(in: text,
                                      range: NSRange(text.startIndex..., in: text))
    }

    // MARK: - Summary

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
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
