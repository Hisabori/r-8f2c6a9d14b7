import XCTest
@testable import CryptoResearchKit

final class TickerResearchTests: XCTestCase {
    let now = Date(timeIntervalSince1970:1_750_000_000)
    func bars(_ count: Int = 90,flat: Bool = false,lastVolume: Double = 100) -> [ResearchBar] {
        (0..<count).map { i in let c = flat ? 100:100+Double(i);return ResearchBar(time:now.addingTimeInterval(Double(i-count)*86400),open:c,high:c+2,low:c-2,close:c,volume:i == count-1 ? lastVolume:100) }
    }
    func report(_ values: [ResearchBar],synthetic: Bool = false,news: [ResearchHeadline] = [],community: [ResearchHeadline] = []) throws -> ResearchReport {
        try TickerResearchMath.report(ticker:ResearchTicker("BTC",asset:.crypto),bars:values,news:news,community:community,now:now,source:"Synthetic test fixture",synthetic:synthetic)
    }
    func testTickerValidationAndNormalization() throws {
        XCTAssertEqual(try ResearchTicker(" btc ",asset:.crypto).symbol,"BTCUSDT")
        XCTAssertEqual(try ResearchTicker("ethusdt",asset:.crypto).symbol,"ETHUSDT")
        XCTAssertEqual(try ResearchTicker("aapl",asset:.stock).symbol,"AAPL")
        XCTAssertThrowsError(try ResearchTicker("005930",asset:.stock))
        for s in ["", "BTC/USDT", "https://evil.test", "USDT", "BTC?apikey=x"] { XCTAssertThrowsError(try ResearchTicker(s,asset:.crypto)) }
    }
    func testWilderRSIGoldenSeed() throws {
        let close = [44.34,44.09,44.15,43.61,44.33,44.83,45.10,45.42,45.84,46.08,45.89,46.03,45.61,46.28,46.28]
        XCTAssertEqual(try XCTUnwrap(TickerResearchMath.rsi(close)),70.464135,accuracy:0.00001)
        XCTAssertEqual(TickerResearchMath.rsi(Array(repeating:100,count:20)),50)
        XCTAssertEqual(TickerResearchMath.rsi((0..<20).map(Double.init)),100)
    }
    func testMACDAndMovingAveragesOnLinearSeries() throws {
        let m = try XCTUnwrap(TickerResearchMath.metrics(bars()))
        XCTAssertEqual(m.sma20,179.5,accuracy:1e-9)
        XCTAssertEqual(m.sma50,164.5,accuracy:1e-9)
        XCTAssertEqual(m.macd,7,accuracy:1e-9)
        XCTAssertEqual(m.macdSignal,7,accuracy:1e-9)
        XCTAssertEqual(m.atr14,4,accuracy:1e-9)
    }
    func testRelativeVolumeExcludesLatestCandle() throws {
        let m = try XCTUnwrap(TickerResearchMath.metrics(bars(lastVolume:200)))
        XCTAssertEqual(try XCTUnwrap(m.relativeVolume),2,accuracy:1e-9)
        XCTAssertNil(m.volumeZ,"Flat reference volume has zero standard deviation, not an infinite anomaly")
    }
    func testFlatSeriesIsNeutralAndFinite() throws {
        let r = try report(bars(flat:true))
        XCTAssertEqual(r.metrics?.rsi14,50)
        XCTAssertEqual(r.metrics?.upperBand,100)
        XCTAssertEqual(r.metrics?.lowerBand,100)
        XCTAssertEqual(r.score,0)
        XCTAssertEqual(r.coverage,90)
        XCTAssertEqual(r.direction,"방향 혼재")
    }
    func testMissingTextDoesNotBecomeNeutralEvidenceOrInflateCoverage() throws {
        let r = try report(bars())
        XCTAssertNil(r.news.direction)
        XCTAssertNil(r.community.direction)
        XCTAssertEqual(r.coverage,90)
        XCTAssertLessThanOrEqual(abs(try XCTUnwrap(r.score)),90)
    }
    func testStaleAndSyntheticReportsCannotProduceCompositeSignal() throws {
        let old = bars().map { ResearchBar(time:$0.time.addingTimeInterval(-10*86400),open:$0.open,high:$0.high,low:$0.low,close:$0.close,volume:$0.volume) }
        XCTAssertNil(try report(old).score)
        XCTAssertNil(try report(bars(),synthetic:true).score)
        XCTAssertNil(try report(Array(bars().suffix(59))).score)
    }
    func testInvalidDuplicateFutureAndUnorderedBarsAreRejected() throws {
        var values = bars();values.append(values.last!)
        XCTAssertThrowsError(try report(values))
        XCTAssertThrowsError(try report(Array(bars().reversed())))
        let invalid = ResearchBar(time:now,open:100,high:99,low:90,close:100,volume:100)
        XCTAssertThrowsError(try report([invalid]))
        let future = ResearchBar(time:now.addingTimeInterval(1),open:100,high:101,low:99,close:100,volume:100)
        XCTAssertThrowsError(try report([future]))
        let overflow = ResearchBar(time:now,open:1e300,high:1e300,low:1e300,close:1e300,volume:1e300)
        XCTAssertFalse(overflow.valid)
    }
    func testHeadlineDeduplicationAgeAndLinkValidation() {
        let items = [
            ResearchHeadline(source:"Fixture",title:"BTC rally",url:"https://example.com/1?a=1",time:now),
            ResearchHeadline(source:"Fixture",title:"BTC rally",url:"https://example.com/2",time:now),
            ResearchHeadline(source:"Fixture",title:"BTC surge",url:"https://example.com/1?a=2",time:now),
            ResearchHeadline(source:"Fixture",title:"BTC loss",url:"https://example.com/3",time:now.addingTimeInterval(-8*86400)),
            ResearchHeadline(source:"Fixture",title:"BTC drop",url:"https://example.com/4",time:now.addingTimeInterval(1)),
            ResearchHeadline(source:"Fixture",title:"BTC beat",url:"http://example.com/5",time:now)]
        let result = TickerResearchMath.textSummary(items,now:now)
        XCTAssertEqual(result.items.count,1)
        XCTAssertNil(result.direction)
        for link in ["http://example.com", "https://u:p@example.com", "https://127.0.0.1/x", "https://server.local/x"] { XCTAssertFalse(TickerResearchMath.safeLink(link)) }
    }
    func testMixedHeadlineExpressionsDoNotVoteTwice() {
        let items = (0..<3).map { ResearchHeadline(source:"Fixture",title:"BTC rally and loss \($0)",url:"https://example.com/\($0)",time:now) }
        let result = TickerResearchMath.textSummary(items,now:now)
        XCTAssertEqual(result.mixed,3)
        XCTAssertEqual(result.positive,0)
        XCTAssertEqual(result.negative,0)
        XCTAssertEqual(result.direction,0)
    }
    func testBinanceFormingBarIsExcluded() throws {
        let closed = (now.timeIntervalSince1970-60)*1000,future = (now.timeIntervalSince1970+60)*1000
        let data = try JSONSerialization.data(withJSONObject:[[0,"100","102","98","101","1000",closed],[0,"101","103","99","102","1000",future]])
        let parsed = try TickerResearchParsing.binance(data,now:now)
        XCTAssertEqual(parsed.count,1)
        XCTAssertEqual(parsed[0].close,101)
    }
    func testStockParserChecksSymbolAndUSSessionClose() throws {
        let input: [String:Any] = ["Meta Data":["2. Symbol":"AAPL","5. Time Zone":"US/Eastern"],"Time Series (Daily)":["2025-06-16":["1. open":"100","2. high":"102","3. low":"98","4. close":"101","5. volume":"1000"]]]
        let data = try JSONSerialization.data(withJSONObject:input)
        let early = ISO8601DateFormatter().date(from:"2025-06-16T19:59:00Z")!
        let closed = ISO8601DateFormatter().date(from:"2025-06-16T20:01:00Z")!
        XCTAssertEqual(try TickerResearchParsing.equities(data,ticker:ResearchTicker("AAPL",asset:.stock),now:early).count,0)
        XCTAssertEqual(try TickerResearchParsing.equities(data,ticker:ResearchTicker("AAPL",asset:.stock),now:closed).count,1)
        XCTAssertThrowsError(try TickerResearchParsing.equities(data,ticker:ResearchTicker("MSFT",asset:.stock),now:closed))
    }
    func testStockDiscontinuitySuppressesCompositeUntilCorporateActionReview() throws {
        var values = bars(flat:true)
        let last = values.removeLast()
        values.append(ResearchBar(time:last.time,open:49,high:52,low:48,close:50,volume:100))
        let r = try TickerResearchMath.report(ticker:ResearchTicker("AAPL",asset:.stock),bars:values,news:[],community:[],now:now,source:"Fixture")
        XCTAssertNotNil(r.metrics)
        XCTAssertNil(r.score)
        XCTAssertTrue(r.notices.contains { $0.contains("기업행사·원본") })
    }
    func testProviderErrorsAndNewsTickerRelevance() throws {
        XCTAssertThrowsError(try TickerResearchParsing.object(Data("{\"Note\":\"limit\"}".utf8)))
        let feed: [String:Any] = ["feed":[["title":"Apple rally","url":"https://example.com/a","source":"Fixture","time_published":"20250616T120000","ticker_sentiment":[["ticker":"AAPL","relevance_score":"0.9"]]],["title":"Other ticker","url":"https://example.com/b","source":"Fixture","time_published":"20250616T120000","ticker_sentiment":[["ticker":"MSFT","relevance_score":"0.9"]]]]]
        let news = try TickerResearchParsing.news(JSONSerialization.data(withJSONObject:feed),ticker:ResearchTicker("AAPL",asset:.stock))
        XCTAssertEqual(news.count,1)
        XCTAssertEqual(news[0].title,"Apple rally")
    }
    func testCommunityIsFilteredByTickerOrKnownCompanyName() throws {
        let aapl = try ResearchTicker("AAPL",asset:.stock)
        XCTAssertTrue(TickerResearchMath.mentions("Apple rally",ticker:aapl))
        XCTAssertTrue(TickerResearchMath.mentions("애플 상승",ticker:aapl))
        XCTAssertFalse(TickerResearchMath.mentions("TSLA rally",ticker:aapl))
        XCTAssertFalse(TickerResearchMath.mentions("pineapple rally",ticker:aapl))
        let posts = (0..<3).map { ResearchHeadline(source:"Fixture",title:"TSLA rally \($0)",url:"https://example.com/\($0)",time:now) }
        let r = try TickerResearchMath.report(ticker:aapl,bars:bars(),news:[],community:posts,now:now,source:"Fixture")
        XCTAssertEqual(r.community.items.count,0)
        XCTAssertEqual(r.coverage,90)
    }
    func testResearchImportRequiresMatchingAssetAndClosedBars() throws {
        let input: [String:Any] = ["research_schema_version":1,"asset":"crypto","symbol":"BTCUSDT","synthetic":false,"bars":[["time":"2025-01-01T00:00:00Z","open":100,"high":102,"low":98,"close":101,"volume":1000,"closed":false]],"news":[],"community":[]]
        let data = try JSONSerialization.data(withJSONObject:input)
        XCTAssertThrowsError(try TickerResearchParsing.imported(data,ticker:ResearchTicker("BTC",asset:.crypto),now:now))
        XCTAssertThrowsError(try TickerResearchParsing.imported(data,ticker:ResearchTicker("ETH",asset:.crypto),now:now))
    }
    func testMalformedMarketDataDoesNotEraseNews() async throws {
        let service = TickerResearchService(fetch:{ url in
            let function = URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first { $0.name == "function" }?.value
            if function == "TIME_SERIES_DAILY" {
                return Data("{\"Meta Data\":{\"2. Symbol\":\"AAPL\",\"5. Time Zone\":\"US/Eastern\"},\"Time Series (Daily)\":{\"2025-06-01\":{\"1. open\":\"100\",\"2. high\":\"50\",\"3. low\":\"90\",\"4. close\":\"100\",\"5. volume\":\"1000\"}}}".utf8)
            }
            let feed = (0..<3).map { ["title":"AAPL rally \($0)","url":"https://example.com/\($0)","source":"Fixture","time_published":"20250614T120000","ticker_sentiment":[["ticker":"AAPL","relevance_score":"0.9"]]] as [String:Any] }
            return try JSONSerialization.data(withJSONObject:["feed":feed])
        })
        let result = try await service.analyze(ResearchTicker("AAPL",asset:.stock),key:"fixture-key",now:now)
        XCTAssertTrue(result.bars.isEmpty)
        XCTAssertNil(result.metrics)
        XCTAssertNil(result.score)
        XCTAssertEqual(result.news.items.count,3)
    }
    func testPartialProviderFailurePreservesOtherEvidence() async throws {
        let now = self.now
        var calls = 0
        let service = TickerResearchService(fetch:{ url in
            calls += 1
            if url.host == "data-api.binance.vision" {
                let rows = (0..<90).map { i -> [Any] in let c = 100+i;return [0,"\(c)","\(c+2)","\(c-2)","\(c)","100",(now.timeIntervalSince1970+Double(i-90)*86400)*1000] }
                return try JSONSerialization.data(withJSONObject:rows)
            }
            throw ResearchFailure.unavailable
        })
        let r = try await service.analyze(ResearchTicker("BTC",asset:.crypto),key:"fixture-key",now:now)
        XCTAssertNotNil(r.metrics)
        XCTAssertEqual(r.news.items.count,0)
        XCTAssertEqual(r.community.items.count,0)
        XCTAssertEqual(calls,3)
        XCTAssertTrue(r.notices.contains { $0.hasPrefix("뉴스:") })
    }
}
