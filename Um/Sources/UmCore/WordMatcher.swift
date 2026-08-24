import Foundation

/// Word-boundary matcher for filler words and short phrases.
///
/// "like" will not match inside "likewise". Multi-word phrases such as
/// "you know" match as a whole unit.
public enum WordMatcher {
    public static func countOccurrences(of target: String, in text: String) -> Int {
        let needle = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return 0 }

        let pattern: String
        if needle.contains(" ") {
            pattern = "(?<![\\w])\(NSRegularExpression.escapedPattern(for: needle))(?![\\w])"
        } else {
            pattern = "\\b\(NSRegularExpression.escapedPattern(for: needle))\\b"
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return 0
        }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    public static func counts(in text: String, words: [String]) -> [String: Int] {
        var result: [String: Int] = [:]
        let haystack = text.lowercased()
        for word in words {
            let hits = countOccurrences(of: word, in: haystack)
            if hits > 0 {
                result[word] = hits
            }
        }
        return result
    }
}
