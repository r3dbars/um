import Foundation
import Combine

/// Tracks filler word occurrences across a session.
/// Thread-safe via main-thread publishing.
class FillerWordCounter: ObservableObject {
    static let shared = FillerWordCounter()

    // Words to detect — user can customise via Settings
    @Published var trackedWords: [String] = [
        "um", "uh", "like", "you know", "basically",
        "literally", "sort of", "kind of", "right", "so"
    ]

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

    // MARK: - Session Control

    func startSession() {
        resetCounts()
        isActive = true
        sessionStartTime = Date()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStartTime else { return }
            self.sessionDuration = Date().timeIntervalSince(start)
        }
    }

    func stopSession() {
        isActive = false
        sessionTimer?.invalidate()
        sessionTimer = nil
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

    // MARK: - Detection

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
        for word in trackedWords {
            let hits = countOccurrences(of: word, in: newPortion.lowercased())
            if hits > 0 {
                counts[word, default: 0] += hits
                added += hits
            }
        }
        if added > 0 {
            totalCount += added
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
