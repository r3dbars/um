import XCTest
@testable import UmCore

final class SessionArchiveTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("um-session-tests-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    func testRoundTrip() throws {
        let original = [
            SessionRecord(durationSeconds: 60, totalCount: 4, counts: ["um": 3, "like": 1], ratePerMinute: 4),
            SessionRecord(durationSeconds: 90, totalCount: 3, counts: ["uh": 3], ratePerMinute: 2)
        ]
        let archive = SessionArchive(fileURL: fileURL)
        try archive.save(original)
        let loaded = try archive.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].totalCount, 4)
        XCTAssertEqual(loaded[1].counts["uh"], 3)
    }

    func testLoadMissingFileIsEmpty() throws {
        XCTAssertEqual(try SessionArchive(fileURL: fileURL).load(), [])
    }

    func testCorruptFileThrowsInsteadOfEmpty() throws {
        try Data("{not-json".utf8).write(to: fileURL)
        XCTAssertThrowsError(try SessionArchive(fileURL: fileURL).load())
    }

    func testAverageAndTotalTime() {
        let sessions = [
            SessionRecord(durationSeconds: 60, totalCount: 6, counts: [:], ratePerMinute: 6),
            SessionRecord(durationSeconds: 120, totalCount: 4, counts: [:], ratePerMinute: 2)
        ]
        XCTAssertEqual(SessionAnalytics.averageRate(of: sessions), 4, accuracy: 0.001)
        XCTAssertEqual(SessionAnalytics.totalTime(of: sessions), 180, accuracy: 0.001)
        XCTAssertEqual(SessionAnalytics.averageRate(of: sessions, last: 1), 2, accuracy: 0.001)
    }

    func testTrendImprovingIsNegative() {
        let sessions = (0..<6).map { index in
            SessionRecord(
                durationSeconds: 60,
                totalCount: 12 - index,
                counts: [:],
                ratePerMinute: Double(12 - index)
            )
        }
        XCTAssertLessThan(SessionAnalytics.trend(of: sessions, last: 6), 0)
    }

    func testTrendNeedsFourSessions() {
        let sessions = [
            SessionRecord(durationSeconds: 60, totalCount: 1, counts: [:], ratePerMinute: 1),
            SessionRecord(durationSeconds: 60, totalCount: 2, counts: [:], ratePerMinute: 2)
        ]
        XCTAssertEqual(SessionAnalytics.trend(of: sessions, last: 6), 0)
    }
}
