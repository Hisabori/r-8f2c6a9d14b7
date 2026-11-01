import XCTest
@testable import CareSuiteNative
final class MedicationAgendaTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func testSearchAcrossFieldsAndCaseAndWhitespace() {
        let plan = MedicationPlan(name: "Vitamin Café", instructions: "아침 식후")
        XCTAssertTrue(MedicationAgenda.matches(plan, query: " cafe  아침 "))
        XCTAssertTrue(MedicationAgenda.matches(plan, query: " \n"))
        XCTAssertFalse(MedicationAgenda.matches(plan, query: "아침 저녁"))
    }
    func testNextIsUpcomingUnconfirmedWithStableTies() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 10, minute: 0))!
        var past = MedicationPlan(name: "past", hour: 9), current = MedicationPlan(name: "current", hour: 10), next = MedicationPlan(name: "next", hour: 11), tie = MedicationPlan(name: "tie", hour: 11)
        past.id = "past"; current.id = "current"; next.id = "a"; tie.id = "b"
        let plans = [tie, current, past, next]
        XCTAssertEqual(MedicationAgenda.summary(plans, checked: [], now: now, calendar: calendar).due, 2)
        XCTAssertEqual(MedicationAgenda.summary(plans, checked: [], now: now, calendar: calendar).next?.id, "a")
        XCTAssertEqual(MedicationAgenda.summary(plans, checked: ["a"], now: now, calendar: calendar).next?.id, "b")
        XCTAssertNil(MedicationAgenda.summary(plans, checked: Set(plans.map(\.id)), now: now, calendar: calendar).next)
        XCTAssertEqual(MedicationAgenda.summary([], checked: [], now: now, calendar: calendar).due, 0)
    }
    func testAgendaUsesTodayWeekdayIncludingNotificationsOff() {
        let monday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 0))!
        let plan = MedicationPlan(name: "Monday", hour: 23, weekdays: [2], enabled: false)
        var state = MedicationState(); state.plans = [plan]
        XCTAssertEqual(MedicationAgenda.summary(MedicationInsights.today(state, now: monday, calendar: calendar), checked: [], now: monday, calendar: calendar).next?.id, plan.id)
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        XCTAssertNil(MedicationAgenda.summary(MedicationInsights.today(state, now: tuesday, calendar: calendar), checked: [], now: tuesday, calendar: calendar).next)
    }
    func testOverlapRequiresSameNameTimeAndSharedDay() {
        var a = MedicationPlan(name: "타이 레놀정", hour: 9, weekdays: [2,4])
        var b = MedicationPlan(name: "타이레놀정", hour: 9, weekdays: [4,6])
        a.id = "a"; b.id = "b"
        XCTAssertEqual(MedicationAgenda.overlapping(a, in: [b]).count, 1)
        b.hour = 10; XCTAssertTrue(MedicationAgenda.overlapping(a, in: [b]).isEmpty)
        b.hour = 9; b.weekdays = [3]; XCTAssertTrue(MedicationAgenda.overlapping(a, in: [b]).isEmpty)
    }
    func testOverlapExcludesOwnIDAndDifferentStrength() {
        var a = MedicationPlan(name: "A정 10mg", hour: 9)
        var b = MedicationPlan(name: "A정 20mg", hour: 9)
        a.id = "a"; b.id = "b"
        XCTAssertTrue(MedicationAgenda.overlapping(a, in: [a,b]).isEmpty)
    }
}
