import XCTest
@testable import UmCore

final class WordMatcherTests: XCTestCase {
    func testCountsStandaloneFiller() {
        XCTAssertEqual(WordMatcher.countOccurrences(of: "um", in: "um, I think um we should"), 2)
    }

    func testDoesNotMatchInsideLargerWord() {
        XCTAssertEqual(WordMatcher.countOccurrences(of: "like", in: "I likewise agree"), 0)
        XCTAssertEqual(WordMatcher.countOccurrences(of: "like", in: "I like this"), 1)
    }

    func testMatchesPhrase() {
        XCTAssertEqual(WordMatcher.countOccurrences(of: "you know", in: "it's, you know, fine"), 1)
        XCTAssertEqual(WordMatcher.countOccurrences(of: "you know", in: "you knowledgeable"), 0)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(WordMatcher.countOccurrences(of: "uh", in: "UH, wait, Uh"), 2)
    }

    func testIgnoresEmptyTarget() {
        XCTAssertEqual(WordMatcher.countOccurrences(of: "   ", in: "um uh"), 0)
    }

    func testCountsDictionary() {
        let result = WordMatcher.counts(
            in: "Um, like, you know, like basically",
            words: ["um", "like", "you know", "basically", "literally"]
        )
        XCTAssertEqual(result["um"], 1)
        XCTAssertEqual(result["like"], 2)
        XCTAssertEqual(result["you know"], 1)
        XCTAssertEqual(result["basically"], 1)
        XCTAssertNil(result["literally"])
    }
}
