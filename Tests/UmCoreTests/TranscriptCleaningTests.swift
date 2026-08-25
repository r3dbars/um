import XCTest
@testable import UmCore

final class TranscriptCleaningTests: XCTestCase {
    func testStripsBlankAudioToken() {
        XCTAssertEqual(TranscriptCleaning.cleaned("um [BLANK_AUDIO] hello"), "um  hello")
    }

    func testStripsSilenceAndParentheticalHallucinations() {
        let cleaned = TranscriptCleaning.cleaned("(silence) um (cough) uh [music]")
        XCTAssertEqual(cleaned, "um  uh")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(TranscriptCleaning.cleaned("   um   "), "um")
    }

    func testLeavesRealSpeech() {
        XCTAssertEqual(TranscriptCleaning.cleaned("um, like, you know"), "um, like, you know")
    }
}
