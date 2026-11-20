import XCTest
@testable import CareSuiteNative

final class CrowdComparisonTests:XCTestCase {
    let headers=["구분","호선","번호","역명","방향","7시00분","7시30분","8시00분","8시30분","9시00분","00시00분","00시30분","1시00분","23시00분","23시30분"]
    let row=["평일","2호선","x","서울역","상선","70","","100","NaN","45","0","20","21","88","77"]
    func testMissingValuesAreExcludedAndLowestStaysWithinWindow(){
        let points=CrowdComparison.points(headers:headers,row:row,selected:16)
        let profile=CrowdComparison(id:0,title:"fixture",selected:16,points:points)
        XCTAssertEqual(points.map(\.slot),[14,15,16,17,18]);XCTAssertNil(points[1].percent);XCTAssertNil(points[3].percent)
        XCTAssertEqual(profile.best?.slot,18);XCTAssertEqual(profile.best?.percent,45)
        let one=CrowdComparison(id:0,title:"fixture",selected:16,points:[CrowdTimePoint(slot:16,percent:100),CrowdTimePoint(slot:17,percent:nil)])
        XCTAssertNil(one.best)
    }
    func testMidnightZeroAndTiesNeverWrapOrInventValues(){
        let start=CrowdComparison(id:0,title:"fixture",selected:0,points:CrowdComparison.points(headers:headers,row:row,selected:0))
        XCTAssertEqual(start.points.map(\.slot),[0,1,2]);XCTAssertEqual(start.best?.percent,0)
        XCTAssertEqual(CrowdComparison.points(headers:headers,row:row,selected:47).map(\.slot),[45,46,47])
        XCTAssertTrue(CrowdComparison.points(headers:headers,row:row,selected:-1).isEmpty)
        let tied=CrowdComparison(id:0,title:"fixture",selected:16,points:[CrowdTimePoint(slot:15,percent:50),CrowdTimePoint(slot:16,percent:50),CrowdTimePoint(slot:17,percent:50)])
        XCTAssertEqual(tied.best?.slot,16)
        XCTAssertTrue(CrowdComparison.points(headers:headers,row:["x"],selected:16).allSatisfy{$0.percent==nil})
    }
    func testComparisonDoesNotMixLinesDirectionsOrWeekdays()throws {
        let other=["일요일","1호선","x","서울","하선","1","1","1","1","1"]
        let data=try JSONSerialization.data(withJSONObject:["headers":headers,"rows":[row,other]])
        let date=ISO8601DateFormatter().date(from:"2026-06-29T23:00:00Z")!
        let profiles=try CrowdComparison.profiles(data,station:"서울",at:date,dayOverride:nil)
        XCTAssertEqual(profiles.count,1);XCTAssertEqual(profiles[0].title,"2호선 · 상선");XCTAssertEqual(profiles[0].best?.slot,18)
    }
}
