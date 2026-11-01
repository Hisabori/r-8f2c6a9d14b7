import XCTest
@testable import CareSuiteNative
final class SleepAudioCoverageTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1800000000)
    func testRecordedAudioAndElapsedAreSeparate() {
        let result = SleepAudioCoverage.analyze(start: start, end: start.addingTimeInterval(600), seconds: Array(repeating: 60, count: 9), recovered: false)!
        XCTAssertEqual(result.recordedSeconds, 540); XCTAssertEqual(result.gapSeconds, 60); XCTAssertEqual(result.fraction, 0.9, accuracy: 0.001)
    }
    func testRecoveredClockReversalAndOverfilledAudioStayUnknown() {
        XCTAssertNil(SleepAudioCoverage.analyze(start: start, end: nil, seconds: [], recovered: false))
        XCTAssertNil(SleepAudioCoverage.analyze(start: start, end: start.addingTimeInterval(60), seconds: [60], recovered: true))
        XCTAssertNil(SleepAudioCoverage.analyze(start: start, end: start.addingTimeInterval(-1), seconds: [], recovered: false))
        XCTAssertNil(SleepAudioCoverage.analyze(start: start, end: start.addingTimeInterval(10), seconds: [60], recovered: false))
    }
    func testPartialBinsAndValidationBounds() {
        XCTAssertEqual(SleepAudioCoverage.analyze(start: start, end: start.addingTimeInterval(2), seconds: [1.5], recovered: false)?.recordedSeconds, 1.5)
        XCTAssertNil(SleepAudioCoverage.analyze(start: start, end: start.addingTimeInterval(60), seconds: [.nan], recovered: false))
        XCTAssertNil(SleepAudioCoverage.analyze(start: start, end: start.addingTimeInterval(36000), seconds: [], recovered: false))
    }
    func testContinuousElapsedTakesPriorityOverChangedWallClock() {
        let result = SleepAudioCoverage.analyze(start: start, end: start.addingTimeInterval(-100), seconds: [60], recovered: false, monotonic: 120)!
        XCTAssertTrue(result.usedMonotonic)
        XCTAssertEqual(result.elapsedSeconds, 120); XCTAssertEqual(result.fraction, 0.5)
        XCTAssertNil(SleepAudioCoverage.analyze(start: start, end: start.addingTimeInterval(120), seconds: [60], recovered: false, monotonic: .nan))
    }
}
