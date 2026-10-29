import XCTest
@testable import CryptoResearch
final class StrategyProfileTests:XCTestCase {
 func testClassicGolden()throws{let e=try StrategyCore.backtest(StrategyCore.syntheticRows(),1000000,5,5);XCTAssertEqual(e.equity,999800.1998501,accuracy:0.000001);XCTAssertEqual(e.profile,.classic)}
 func testDefensiveAllocation()throws{let e=try StrategyCore(1000000,5,5,.defensive);e.pending=1;e.open(1,100);XCTAssertEqual(e.cash,950000,accuracy:0.000001);XCTAssertEqual(e.qty*100*1.0005*1.0005,50000,accuracy:0.000001)}
 func testCooldown()throws{let e=try StrategyCore(1000000,5,5,.defensive);e.pending=1;e.open(1,100);e.sell(2,100,"test");e.pending=1;e.open(3,100);XCTAssertEqual(e.buys,1);for i in 0..<3{try e.close(StrategyBar(t:100+Int64(i),o:100,h:100,l:100,c:100,v:0))};e.pending=1;e.open(104,100);XCTAssertEqual(e.buys,2)}
 func testSmallCrossFiltered()throws{let e=try StrategyCore(1000000,5,5,.defensive);for i in 0..<30{try e.process(StrategyBar(t:100+Int64(i),o:100,h:100,l:100,c:100,v:0))};try e.close(StrategyBar(t:131,o:100,h:100.1,l:100,c:100.1,v:0));XCTAssertGreaterThan(e.ema9,e.ema21);XCTAssertEqual(e.pending,0)}
 func testReport()throws{let e=try StrategyCore(1000000,5,5,.defensive);let report=try XCTUnwrap(JSONSerialization.jsonObject(with:e.report()) as? [String:Any]);XCTAssertEqual(report["strategy_profile"] as? String,"DEFENSIVE");let p=try XCTUnwrap(report["strategy_parameters"] as? [String:Any]);XCTAssertEqual(p["allocation_pct"] as? Double,5)}
}
