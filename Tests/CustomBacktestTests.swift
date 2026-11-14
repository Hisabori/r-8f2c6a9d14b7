import XCTest
@testable import CryptoResearchKit
final class CustomBacktestTests: XCTestCase {
 func testCustomSizingAndExportAreConsistent() throws {
  let risk = try BacktestRisk(allocation:0.25,stop:0.02,target:0.04)
  let normal = try StrategyCore.backtest(StrategyCore.syntheticRows(),10000,5,5)
  let custom = try StrategyCore.backtest(StrategyCore.syntheticRows(),10000,5,5,.classic,risk)
  XCTAssertEqual(custom.buys,normal.buys)
  XCTAssertEqual(try XCTUnwrap(custom.fillRecords.first).quantity,
                 try XCTUnwrap(normal.fillRecords.first).quantity*2.5,accuracy:1e-10)
  let report = try XCTUnwrap(JSONSerialization.jsonObject(with:custom.report()) as? [String:Any])
  XCTAssertEqual(report["custom_risk_enabled"] as? Bool,true)
  XCTAssertEqual(report["mode"] as? String,"MOBILE_PAPER_EMA_CUSTOM_V4")
  let params = try XCTUnwrap(report["strategy_parameters"] as? [String:Double])
  XCTAssertEqual(params["allocation_pct"],25)
 }
 func testBuyHoldChargesBothSidesAndMatchesExcess() throws {
  let result = try StrategyCore.backtest(StrategyCore.syntheticRows(),10000,10,20)
  let expected = 100 * (110 * 0.998 * 0.999 / (100 * 1.002 * 1.001) - 1)
  XCTAssertEqual(try XCTUnwrap(result.buyHoldReturn),expected,accuracy:1e-10)
  let report = try XCTUnwrap(JSONSerialization.jsonObject(with:result.report()) as? [String:Any])
  XCTAssertEqual(try XCTUnwrap(report["excess_return_pp"] as? Double),(result.equity/10000-1)*100-expected,accuracy:1e-10)
 }
 func testInvalidRiskAndEmptyBarsFail() {
  XCTAssertThrowsError(try BacktestRisk(allocation:.nan,stop:0.01,target:0.02))
  XCTAssertThrowsError(try BacktestRisk(allocation:1.1,stop:0.01,target:0.02))
  XCTAssertThrowsError(try BacktestRisk(allocation:0.1,stop:0,target:0.02))
  XCTAssertThrowsError(try StrategyCore.backtest([],10000,5,5))
 }
}
