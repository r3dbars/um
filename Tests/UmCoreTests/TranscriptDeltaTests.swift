import XCTest
@testable import UmCore

final class TranscriptDeltaTests: XCTestCase {
    func testReturnsOnlyNewSuffixWhenTranscriptGrows() {
        let delta = TranscriptDelta.newPortion(
            in: "um I think we should like go",
            previouslyProcessed: "um I think we should"
        )
        XCTAssertEqual(delta, " like go")
    }

    func testReturnsFullTextWhenPreviousIsEmpty() {
        XCTAssertEqual(TranscriptDelta.newPortion(in: "um hello", previouslyProcessed: ""), "um hello")
    }

    func testReturnsEmptyWhenNothingNew() {
        XCTAssertEqual(TranscriptDelta.newPortion(in: "um hello", previouslyProcessed: "um hello"), "")
    }

    func testReplacesWhenRecognizerRewinds() {
        let delta = TranscriptDelta.newPortion(
            in: "uh wait",
            previouslyProcessed: "um I think we should go now"
        )
        XCTAssertEqual(delta, "uh wait")
    }

    func testEmptyTranscript() {
        XCTAssertEqual(TranscriptDelta.newPortion(in: "", previouslyProcessed: "um"), "")
    }
}
