import XCTest
@testable import CryptoResearchKit
@MainActor final class InvestmentWorkflowTests: XCTestCase {
    private func session() -> NativeInvestmentSession {
        let name = "workflow-test-"+UUID().uuidString
        return NativeInvestmentSession(defaults:UserDefaults(suiteName:name)!)
    }
    func testHandoffPreservesActualBarsCurrencyAndSyntheticLabel() throws {
        let session = session();session.research.sample(try ResearchTicker("BTC",asset:.crypto))
        let original = try XCTUnwrap(session.research.report)
        try session.prepareComparison()
        let input = try XCTUnwrap(session.comparison.researchInput)
        XCTAssertTrue(input.synthetic);XCTAssertEqual(input.bars.count,original.bars.count)
        XCTAssertEqual(input.bars[0].o,original.bars[0].open)
        XCTAssertEqual(input.bars[0].v,original.bars[0].volume)
        XCTAssertEqual(input.bars[0].t,Int64((original.bars[0].time.timeIntervalSince1970*1000).rounded()))
        XCTAssertTrue(input.label.contains("BTC/USDT"));XCTAssertEqual(input.marketSymbol(in:session.market.symbols),"BTC")
        XCTAssertFalse(session.market.connected)
    }
    func testStockCannotSilentlyBecomeCryptoMarket() throws {
        let session = session();session.research.sample(try ResearchTicker("AAPL",asset:.stock));try session.prepareComparison()
        let input = try XCTUnwrap(session.comparison.researchInput)
        XCTAssertTrue(input.label.contains("USD"));XCTAssertNil(input.marketSymbol(in:session.market.symbols))
        session.research.sample(try ResearchTicker("AVAX",asset:.crypto));try session.prepareComparison()
        XCTAssertNil(session.comparison.researchInput?.marketSymbol(in:session.market.symbols))
    }
    func testHandoffIsSnapshotAndDoesNotChangeWhenTickerChanges() throws {
        let session = session();session.comparison.capital = "250000"
        session.research.sample(try ResearchTicker("BTC",asset:.crypto));try session.prepareComparison()
        let original = try XCTUnwrap(session.comparison.researchInput)
        session.research.sample(try ResearchTicker("ETH",asset:.crypto))
        XCTAssertEqual(session.comparison.researchInput?.ticker.base,"BTC")
        XCTAssertEqual(session.comparison.researchInput?.bars.first?.c,original.bars.first?.c)
        XCTAssertEqual(session.comparison.capital,"250000")
    }
    func testMissingReportDoesNotCreateComparisonInput() {
        let session = session();XCTAssertThrowsError(try session.prepareComparison())
        XCTAssertNil(session.comparison.researchInput);XCTAssertNil(session.comparison.report)
    }
    func testHandoffRunsPassedBarsRatherThanDefaultSample() async throws {
        let session = session();session.research.sample(try ResearchTicker("AAPL",asset:.stock));try session.prepareComparison()
        let input = try XCTUnwrap(session.comparison.researchInput)
        session.comparison.start(url:nil,capital:10000,fee:5,slip:5,researchInput:input)
        let end = Date().addingTimeInterval(10)
        while session.comparison.busy && Date() < end { try await Task.sleep(nanoseconds:50_000_000) }
        XCTAssertFalse(session.comparison.busy)
        let report = try XCTUnwrap(session.comparison.report)
        XCTAssertEqual(report.rows.first?.bars,input.bars.count)
        XCTAssertTrue(report.synthetic);XCTAssertEqual(report.inputLabel,input.label)
        XCTAssertTrue(session.comparisonSummary.contains("AAPL"))
        session.comparison.cancel();XCTAssertNotNil(session.comparison.report)
    }
    func testOlderComparisonJSONCanDecodeWithoutSourceMetadata() throws {
        let report = try StrategyComparison.run(StrategyComparison.sample(),capital:10000,fee:5,slip:5,synthetic:true)
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with:JSONEncoder().encode(report)) as? [String:Any])
        json.removeValue(forKey:"inputLabel")
        let decoded = try JSONDecoder().decode(StrategyComparisonReport.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertNil(decoded.inputLabel);XCTAssertEqual(decoded.mode,report.mode)
    }
}
