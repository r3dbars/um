import Foundation

/// Strips whisper.cpp hallucinations so they are not counted as speech.
public enum TranscriptCleaning {
    public static func cleaned(_ transcript: String) -> String {
        var cleaned = transcript
            .replacingOccurrences(of: "[BLANK_AUDIO]", with: "")
            .replacingOccurrences(of: "(silence)", with: "")
        if let regex = try? NSRegularExpression(pattern: "\\([^)]*\\)|\\[[^\\]]*\\]") {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
