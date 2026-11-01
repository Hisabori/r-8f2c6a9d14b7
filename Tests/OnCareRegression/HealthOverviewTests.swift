import XCTest
@testable import CareSuiteNative
final class HealthOverviewTests: XCTestCase {
    func testManualOnlyTodayAndMissingStayUnknown() {
        let now = Date()
        let rows = HealthOverviewMetrics.rows([Entry(date: now, kind: "물", value: 200), Entry(date: now, kind: "물", value: 300), Entry(id: "hc:x", date: now, kind: "물", value: 999), Entry(date: now, kind: "수면", value: 8, source: "health-connect:test")], focus: "물", now: now)
        XCTAssertEqual(rows[0].value, 500)
        XCTAssertNil(rows.first { $0.kind == "수면" }?.value)
        XCTAssertEqual(rows.filter { $0.value != nil }.count, 1)
    }
    func testLatestMoodAndSleepAreNotAddedAndFutureIgnored() {
        let now = Date()
        let rows = HealthOverviewMetrics.rows([Entry(id: "a", date: now.addingTimeInterval(-2), kind: "마음", value: 1), Entry(id: "b", date: now, kind: "마음", value: 4), Entry(date: now.addingTimeInterval(20), kind: "마음", value: 5), Entry(date: now, kind: "수면", value: .nan)], focus: "마음", now: now)
        XCTAssertEqual(rows.first?.kind, "마음"); XCTAssertEqual(rows.first?.value, 4)
        XCTAssertNil(rows.first { $0.kind == "수면" }?.value)
    }
    func testCalendarWindowCountsDaysNotNumberOfRecords() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        let rows = HealthOverviewMetrics.rows([Entry(date: start, kind: "운동", value: 20), Entry(date: start.addingTimeInterval(1), kind: "운동", value: 30), Entry(date: start.addingTimeInterval(-1), kind: "운동", value: 60)], focus: "unknown", now: now, calendar: calendar)
        XCTAssertEqual(rows.first?.kind, "물")
        XCTAssertEqual(rows.first { $0.kind == "운동" }?.recordedDays, 1)
        XCTAssertNil(rows.first { $0.kind == "운동" }?.value)
    }
    func testSelectedDayClampsAndFollowsCalendarAcrossDST() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!
        XCTAssertEqual(HealthOverviewMetrics.snapshotDate(offset: -9, now: now, calendar: calendar), now)
        let selected = HealthOverviewMetrics.snapshotDate(offset: 1, now: now, calendar: calendar)
        let start = calendar.startOfDay(for: selected), next = calendar.date(byAdding: .day, value: 1, to: start)!
        XCTAssertEqual(next.timeIntervalSince(start), 25 * 3600, accuracy: 0.001)
        XCTAssertEqual(calendar.component(.day, from: selected), 1)
        XCTAssertEqual(HealthOverviewMetrics.snapshotDate(offset: Int.max, now: now, calendar: calendar), HealthOverviewMetrics.snapshotDate(offset: 6, now: now, calendar: calendar))
    }
    func testPastSnapshotIncludesLastFractionAndExcludesNextDay() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
        let boundary = calendar.startOfDay(for: now)
        let records = [Entry(date: boundary.addingTimeInterval(-0.0005), kind: "물", value: 200), Entry(date: boundary, kind: "물", value: 300)]
        let snapshot = HealthOverviewMetrics.snapshotDate(offset: 1, now: now, calendar: calendar)
        XCTAssertEqual(HealthOverviewMetrics.rows(records, focus: "물", now: snapshot, calendar: calendar).first?.value, 200)
    }
}
