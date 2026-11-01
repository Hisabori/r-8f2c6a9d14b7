import XCTest
@testable import CareSuiteNative
final class ProgressLiveTests: XCTestCase {
    @MainActor func testStatesValidateKindSpecificValuesAndClock() throws {
        guard #available(iOS 16.2, *) else { return }
        let now = Date(timeIntervalSince1970: 1800000000)
        XCTAssertNotNil(ProgressLiveStatus.state(kind: .steps, value: 0, goal: 8000, beganAt: now, now: now))
        XCTAssertNil(ProgressLiveStatus.state(kind: .steps, value: -1, goal: 8000, beganAt: now, now: now))
        XCTAssertNil(ProgressLiveStatus.state(kind: .steps, value: 20, goal: 0, beganAt: now, now: now))
        XCTAssertNil(ProgressLiveStatus.state(kind: .sleepSound, value: 10, goal: 0, beganAt: now, now: now.addingTimeInterval(9*3600)))
        XCTAssertNil(ProgressLiveStatus.state(kind: .sleepSound, value: 0, goal: 0, beganAt: now, now: now.addingTimeInterval(-1)))
    }
    @MainActor func testLivePayloadContainsOnlyProgressAndNewRoutesDoNotStartTracking() throws {
        guard #available(iOS 16.2, *) else { return }
        let now = Date(timeIntervalSince1970: 1800000000)
        let state = ProgressLiveStatus.state(kind: .sleepSound, value: 20, goal: 999, beganAt: now, now: now)!
        XCTAssertEqual(state.goal, 0)
        let data = try JSONEncoder().encode(state)
        XCTAssertLessThan(data.count, 512)
        XCTAssertEqual(try JSONDecoder().decode(CareProgressAttributes.ContentState.self, from: data), state)
        XCTAssertEqual(CareDestination.steps.sheet, .steps)
        XCTAssertEqual(CareDestination.sleepSound.sheet, .sleepSound)
        XCTAssertEqual(CareDestination.parse(URL(string: "caresuite-care://open/sleep-sound")!), .sleepSound)
        XCTAssertNil(CareDestination.parse(URL(string: "caresuite-care://open/sleep-sound?start=true")!))
    }
}
