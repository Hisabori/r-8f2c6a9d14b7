import XCTest
@testable import CareSuiteNative
final class PublicTransitTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from:value)! }
    private func payload(_ generated: String,station: String = "서울") throws -> Data {
        try JSONSerialization.data(withJSONObject:["realtimeArrivalList":[["statnNm":station,"recptnDt":generated,"trainLineNm":"인천행","updnLine":"하행","arvlMsg2":"전역 출발"]]])
    }
    func testArrivalFreshnessStationAndKoreanTimezone() throws {
        let now = date("2026-06-29T23:00:30Z")
        let raw = try payload("2026-06-30 08:00:00")
        let rows = try PublicTransitData.parse(raw,station:"서울역",now:now)
        XCTAssertEqual(rows.count,1);XCTAssertEqual(rows.first?.message,"전역 출발")
        XCTAssertEqual(try PublicTransitData.parse(raw,station:"강남",now:now).count,0)
        XCTAssertEqual(try PublicTransitData.parse(raw,station:"서울",now:now.addingTimeInterval(91)).count,0)
        XCTAssertEqual(try PublicTransitData.parse(raw,station:"서울",now:now.addingTimeInterval(-61)).count,0)
        XCTAssertFalse(rows[0].isFresh(at:now.addingTimeInterval(91)))
    }
    func testInvalidProviderResponsesAndBounds() throws {
        XCTAssertThrowsError(try PublicTransitData.parse(Data("{\"errorMessage\":{\"code\":\"INFO-100\"}}".utf8),station:"서울",now:Date()))
        XCTAssertThrowsError(try PublicTransitData.parse(Data(repeating:0,count:2_097_153),station:"서울",now:Date()))
        XCTAssertEqual(try PublicTransitData.parse(payload("not a valid timestamp"),station:"서울",now:Date()).count,0)
    }
    func testRequestCannotRedirectKeyToAnotherHost() throws {
        let url = try PublicTransitData.endpoint(station:"서울",key:"fixture123")
        XCTAssertEqual(url.scheme,"https");XCTAssertEqual(url.host,"swopenapi.seoul.go.kr")
        for value in ["", "key/other", "key?token", "key\n"] { XCTAssertThrowsError(try PublicTransitData.endpoint(station:"서울",key:value)) }
        XCTAssertThrowsError(try PublicTransitData.endpoint(station:"https://other.invalid",key:"fixture"))
    }
    func testCrowdUsesExactKoreanHalfHourWithoutMidnightFallback() throws {
        let raw = try JSONSerialization.data(withJSONObject:["headers":["구분","호선","역번호","역명","상하구분","8시00분","00시00분"],"rows":[["평일","1호선","150","서울역","상선","73.8","1.1"]]])
        let morning = try PublicTransitData.crowd(raw,station:"서울",at:date("2026-06-29T23:10:00Z"))
        XCTAssertEqual(morning.count,1);XCTAssertTrue(morning[0].contains("73.8"))
        XCTAssertTrue(try PublicTransitData.crowd(raw,station:"서울",at:date("2026-06-30T00:10:00Z")).isEmpty)
        XCTAssertTrue(try PublicTransitData.crowd(raw,station:"강남",at:date("2026-06-29T23:10:00Z")).isEmpty)
    }
    @MainActor func testNoRequestOnInitializationAndMissingKey() {
        let store = PublicTransitStore()
        XCTAssertFalse(store.busy);XCTAssertTrue(store.arrivals.isEmpty);XCTAssertNil(store.receivedAt)
        store.load(station:"서울",key:"")
        XCTAssertFalse(store.busy);XCTAssertTrue(store.arrivals.isEmpty)
    }
    func testBundledCrowdDataset() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource:"transit-crowd-20260630",withExtension:"json"))
        XCTAssertFalse(try PublicTransitData.crowd(Data(contentsOf:url),station:"서울",at:date("2026-06-29T23:10:00Z")).isEmpty)
    }
}
