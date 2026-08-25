import Foundation

/// Apple Speech returns a cumulative transcript. Whisper returns a chunk.
/// This isolates only the new text so filler words are not counted twice.
public enum TranscriptDelta {
    public static func newPortion(in transcript: String, previouslyProcessed: String) -> String {
        guard !transcript.isEmpty else { return "" }
        if transcript == previouslyProcessed { return "" }
        if transcript.count > previouslyProcessed.count,
           transcript.hasPrefix(previouslyProcessed) {
            let start = transcript.index(transcript.startIndex, offsetBy: previouslyProcessed.count)
            return String(transcript[start...])
        }
        return transcript
    }
}
