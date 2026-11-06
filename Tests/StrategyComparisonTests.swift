import XCTest
@testable import CryptoResearchKit
final class StrategyComparisonTests: XCTestCase {
    func testComparisonPreservesExistingProfileResults() throws {
        let rows = StrategyComparison.sample()
        let report = try StrategyComparison.run(rows,capital:1000000,fee:5,slip:5,synthetic:true)
        XCTAssertTrue(report.synthetic);XCTAssertEqual(report.rows.count,8);XCTAssertEqual(report.splitIndex,126)
        for profile in StrategyProfile.allCases {
            let baseline = try StrategyCore.backtest(rows,1000000,5,5,profile)
            let actual = try XCTUnwrap(report.rows.first { $0.profile == profile.rawValue && $0.segment == "전체 구간" })
            XCTAssertEqual(actual.returnPct,(baseline.equity/1000000-1)*100,accuracy:1e-10)
            XCTAssertEqual(actual.maxDrawdownPct,baseline.maxDD,accuracy:1e-10)
            XCTAssertEqual(actual.trades,baseline.sells)
        }
    }
    func testSplitStartsFreshAndCostsDoubleExactly() throws {
        let rows = StrategyComparison.sample()
        let report = try StrategyComparison.run(rows,capital:10000,fee:7,slip:9,synthetic:false)
        let split = try XCTUnwrap(report.splitIndex)
        let direct = try StrategyCore.backtest(Array(rows[split...]),10000,7,9,.classic)
        let tail = try XCTUnwrap(report.rows.first { $0.profile == "CLASSIC" && $0.segment == "뒤 30% 독립 실행" })
        XCTAssertEqual(tail.returnPct,(direct.equity/10000-1)*100,accuracy:1e-10)
        XCTAssertEqual(tail.bars,54)
        for row in report.rows where row.segment == "비용 2배" { XCTAssertEqual(row.feeBps,14);XCTAssertEqual(row.slipBps,18) }
        XCTAssertFalse(report.synthetic)
    }
    func testBuyHoldIncludesEntryAndExitFeesAndSlippage() throws {
        let rows = (0..<30).map { StrategyBar(t:Int64($0),o:100,h:100,l:100,c:100,v:0) }
        let report = try StrategyComparison.run(rows,capital:10000,fee:10,slip:20,synthetic:true)
        let expected = ((1-0.002)*(1-0.001)/((1+0.002)*(1+0.001))-1)*100
        XCTAssertEqual(report.buyAndHoldReturnPct,expected,accuracy:1e-10)
        XCTAssertNil(report.splitIndex);XCTAssertEqual(report.rows.count,4)
    }
    func testInvalidInputsAreRejectedBeforeEvaluation() throws {
        var rows = StrategyComparison.sample();rows[1].t = rows[0].t
        XCTAssertThrowsError(try StrategyComparison.run(rows,capital:1000,fee:5,slip:5,synthetic:true))
        rows = StrategyComparison.sample();rows[1].l = rows[1].h+1
        XCTAssertThrowsError(try StrategyComparison.run(rows,capital:1000,fee:5,slip:5,synthetic:true))
        XCTAssertThrowsError(try StrategyComparison.run(Array(rows.prefix(10)),capital:1000,fee:5,slip:5,synthetic:true))
        XCTAssertThrowsError(try StrategyComparison.run(StrategyComparison.sample(),capital:1000,fee:Double.nan,slip:5,synthetic:true))
    }
    func testStressAboveEngineLimitIsExplicitlySkipped() throws {
        let report = try StrategyComparison.run(StrategyComparison.sample(),capital:1000,fee:60,slip:5,synthetic:true)
        XCTAssertFalse(report.rows.contains { $0.segment == "비용 2배" })
        XCTAssertTrue(report.notes.contains { $0.contains("상한100bps") })
        XCTAssertNoThrow(try JSONEncoder().encode(report))
    }
}
