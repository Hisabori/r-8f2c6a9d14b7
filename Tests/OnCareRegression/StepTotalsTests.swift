import XCTest
@testable import CareSuiteNative
final class StepTotalsTests: XCTestCase {
    func testMergeKeepsMissingDaysAndAcceptsExplicitZero() {
        let now = Date(), a = dateKey(dayOffset(-1)), b = dateKey(now)
        let rows = StepTotals.merge([StepTotal(day: a, count: 4000), StepTotal(day: b, count: 90)], [StepTotal(day: b, count: 0)], now: now)
        XCTAssertEqual(rows.first { $0.day == a }?.count, 4000)
        XCTAssertEqual(rows.first { $0.day == b }?.count, 0)
        XCTAssertEqual(StepTotals.merge(rows, [], now: now), rows)
    }
    func testBoundsFutureAndGoalClamp() {
        let now = Date(), today = dateKey(now)
        XCTAssertEqual(StepTotals.valid([StepTotal(day: today, count: -1), StepTotal(day: dateKey(dayOffset(1)), count: 30), StepTotal(day: dateKey(dayOffset(-7)), count: 80), StepTotal(day: today, count: 1_000_001)], now: now), [])
        XCTAssertEqual(StepTotals.goal(Int.max), 30000)
        XCTAssertEqual(StepTotals.goal(-100), 1000)
        XCTAssertEqual(StepTotals.goal(8299), 8000)
    }
    func testDailySnapshotsNeverCombineTwoDevices() {
        let now = Date()
        let a = Entry(id: "a", date: now.addingTimeInterval(-10), kind: "걸음", value: 1000, source: "health-connect:one")
        let b = Entry(id: "b", date: now, kind: "걸음", value: 1200, source: "health-connect:one")
        let c = Entry(id: "c", date: now, kind: "걸음", value: 1500, source: "health-connect:two")
        XCTAssertEqual(StepTotals.linked([a,b,c], source: "health-connect:one", now: now).first?.count, 1200)
        XCTAssertEqual(StepTotals.linked([a,b,c], source: "health-connect:two", now: now).first?.count, 1500)
        XCTAssertEqual(StepTotals.linked([c,b,a], source: "health-connect:one", now: now).first?.count, 1200)
    }
    func testDayComparisonNeedsBothDaysAndKeepsExplicitZero() {
        let now = Date(), today = dateKey(now), yesterday = dateKey(dayOffset(-1))
        XCTAssertNil(StepTotals.difference([StepTotal(day: today, count: 100)], now: now))
        XCTAssertEqual(StepTotals.difference([StepTotal(day: today, count: 0), StepTotal(day: yesterday, count: 200)], now: now), -200)
    }
}
