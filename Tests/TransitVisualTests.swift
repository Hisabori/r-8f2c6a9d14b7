import XCTest
@testable import CareSuiteNative
final class TransitVisualTests: XCTestCase {
 func testPhasesNeverInventUnknownPosition() {
  XCTAssertEqual(TrainPhaseStrip.index("5"),0)
  XCTAssertEqual(TrainPhaseStrip.index("0"),1)
  XCTAssertEqual(TrainPhaseStrip.index("1"),2)
  XCTAssertEqual(TrainPhaseStrip.index("2"),3)
  XCTAssertNil(TrainPhaseStrip.index("99"))
  XCTAssertNil(TrainPhaseStrip.index(""))
 }
 func testCrowdScaleRejectsInvalidData() {
  XCTAssertEqual(CrowdBarValue.parse("2호선 · 상선 · 134.2%"),134.2)
  XCTAssertNil(CrowdBarValue.parse("2호선 · 자료 없음"))
  XCTAssertNil(CrowdBarValue.parse("2호선 · NaN%"))
  XCTAssertNil(CrowdBarValue.parse("2호선 · 501%"))
 }
}
