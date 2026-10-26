import XCTest
@testable import CryptoResearch
final class StrategyTests:XCTestCase {
 func warm()throws->StrategyCore{let e=try StrategyCore(1000000,5,5);for i in 0..<30{try e.process(StrategyBar(t:1800000000000+Int64(i)*60000,o:100,h:100,l:100,c:100,v:0))};return e}
 func testNextOpen()throws{let e=try warm();try e.process(StrategyBar(t:1800001800000,o:100,h:110,l:100,c:110,v:0));XCTAssertEqual(e.buys,0);XCTAssertEqual(e.pending,1);try e.process(StrategyBar(t:1800001860000,o:110,h:110,l:110,c:110,v:0));XCTAssertEqual(e.buys,1);XCTAssertGreaterThan(e.qty,0);XCTAssertLessThan(e.equity,e.start)}
 func testStopFirst()throws{let e=try warm();try e.process(StrategyBar(t:1800001800000,o:100,h:110,l:100,c:110,v:0));try e.process(StrategyBar(t:1800001860000,o:110,h:120,l:90,c:110,v:0));XCTAssertEqual(e.sells,1);XCTAssertTrue(e.fills.last!.contains("손절 우선"))}
 func testCSV()throws{let h="timestamp,open,high,low,close,volume\n",a="2026-10-01T00:00:00Z,100,101,99,100,1\n",b="2026-10-01T00:01:00Z,100,101,99,100,1";XCTAssertEqual(try StrategyCore.csv(h+a+b).count,2);XCTAssertThrowsError(try StrategyCore.csv(h+a+a));XCTAssertThrowsError(try StrategyCore.csv(h+a+b.replacingOccurrences(of:"101",with:"90")))}
 func testInvalidCosts(){XCTAssertThrowsError(try StrategyCore(.nan,5,5));XCTAssertThrowsError(try StrategyCore(1,-1,5))}
 func testLiveGap()throws{let p=try LivePaper("BTC",1000000,5,5);p.tick(1800000000000,1800000000000,1800000000000,100);p.tick(1800000016000,1800000016000,1800000016000,100);XCTAssertFalse(p.running);XCTAssertEqual(p.engine.buys,0)}
 func testPartialBar()throws{let p=try LivePaper("BTC",1000000,5,5);for i in 0...130{let t:Int64=1800000000000+Int64(i)*1000;p.tick(t,t,t,100)};XCTAssertEqual(p.engine.bars,1)}
}
