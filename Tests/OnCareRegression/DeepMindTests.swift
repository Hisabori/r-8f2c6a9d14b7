import XCTest
@testable import CareSuiteNative
final class DeepMindTests: XCTestCase {
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func testDailyLatestExcludesInvalidFutureAndOtherKinds() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 12))!
        let values = [Entry(date: now.addingTimeInterval(-5), kind: "마음", value: 2), Entry(date: now.addingTimeInterval(-10), kind: "마음", value: 5), Entry(date: now.addingTimeInterval(1), kind: "마음", value: 1), Entry(date: now, kind: "마음", value: .nan), Entry(date: now, kind: "운동", value: 5)]
        let s = DeepMind.summarize(values, now: now, calendar: calendar)
        XCTAssertEqual(s.days, 1); XCTAssertEqual(s.average, 2); XCTAssertEqual(s.difficultDays, 1)
    }
    func testWeeksDoNotOverlapAndMissingDaysAreNotZeros() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 12))!
        let boundary = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        let entries = [Entry(date: boundary, kind: "마음", value: 4), Entry(date: boundary.addingTimeInterval(-1), kind: "마음", value: 1)]
        XCTAssertEqual(DeepMind.summarize(entries, now: now, calendar: calendar).average, 4)
        XCTAssertEqual(DeepMind.summarize(entries, now: now, previous: true, calendar: calendar).average, 1)
        XCTAssertNil(DeepMind.summarize([], now: now).average)
    }
    func testExplicitNotificationRequiresBothOptInsAndNeverIncludesDrugName() {
        XCTAssertEqual(DeepMind.notificationTitle(mode: true, explicit: true), "시발 처먹어 ㅋㅋㅋㅋ")
        XCTAssertEqual(DeepMind.notificationTitle(mode: false, explicit: true), "복용 일정을 확인할 시간")
        XCTAssertNotEqual(DeepMind.notificationTitle(mode: true, explicit: false), "시발 처먹어 ㅋㅋㅋㅋ")
        XCTAssertTrue(DeepMind.notificationBody(mode: true).contains("먹었으면 추가로 먹지 마"))
    }
    func testPersonalizationUsesOnlyAllowlistedChoice() {
        XCTAssertTrue(DeepMind.template(0, focus: "외로움").hasPrefix("오늘 살펴볼 마음: 외로움"))
        XCTAssertEqual(DeepMind.template(-5, focus: "unknown"), DeepMind.templates[0])
        XCTAssertEqual(DeepMind.template(100, focus: "unknown"), DeepMind.templates.last!)
    }
}
