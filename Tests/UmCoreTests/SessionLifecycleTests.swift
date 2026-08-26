import XCTest
@testable import UmCore

final class SessionLifecycleTests: XCTestCase {
    func testOneStopPersistsWhenDurationAtLeastFive() {
        var session = SessionLifecycle()
        session.startSession()
        XCTAssertTrue(session.stopSession(duration: 5))
        XCTAssertEqual(session.persistedCount, 1)
        XCTAssertFalse(session.isActive)
    }

    func testDoubleStopPersistsOnce() {
        var session = SessionLifecycle()
        session.startSession()
        XCTAssertTrue(session.stopSession(duration: 12))
        XCTAssertFalse(session.stopSession(duration: 12))
        XCTAssertEqual(session.persistedCount, 1)
    }

    func testShortSessionDoesNotPersist() {
        var session = SessionLifecycle()
        session.startSession()
        XCTAssertFalse(session.stopSession(duration: 4.9))
        XCTAssertEqual(session.persistedCount, 0)
        XCTAssertFalse(session.isActive)
    }

    func testStopCaptureDoesNotEndSession() {
        var session = SessionLifecycle()
        session.startSession()
        session.stopCapture()
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.persistedCount, 0)

        session.stopCapture()
        XCTAssertTrue(session.isActive)
        XCTAssertTrue(session.stopSession(duration: 8))
        XCTAssertEqual(session.persistedCount, 1)
    }
}
