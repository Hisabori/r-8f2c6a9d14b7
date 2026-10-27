import XCTest
@testable import CryptoResearch
final class ResearchFeaturesTests:XCTestCase {
 func testBoundedDrafts(){XCTAssertEqual(ResearchSupport.boundedDraft(""),"");XCTAssertEqual(ResearchSupport.boundedDraft(String(repeating:"1",count:60)).count,32);XCTAssertEqual(ResearchSupport.boundedDraft("2500000.5"),"2500000.5")}
 func testOriginalServerReportBytesPreserved()throws{let data=Data(" {\"mode\":\"SERVER_PAPER_EMA_SPOT_V2\",\"report_schema_version\":2,\"position_quantity\":2}\n".utf8);XCTAssertEqual(try ResearchSupport.serverReport(data),data)}
 func testInvalidReportRejected(){for raw in ["{}","{\"mode\":\"LIVE\",\"report_schema_version\":2}","{\"mode\":\"SERVER_PAPER_EMA_SPOT_V2\",\"report_schema_version\":1}"]{XCTAssertThrowsError(try ResearchSupport.serverReport(Data(raw.utf8)))};XCTAssertThrowsError(try ResearchSupport.serverReport(Data(repeating:0,count:8*1024*1024+1)))}
 func testAccountOverviewUsesMarkedBook()throws{let p=try LivePaper("BTC",1000000,5,5);p.engine.cash=900000;p.engine.qty=2;p.engine.lastPrice=100;p.engine.halted=true;let view=PaperAccountOverview(p);XCTAssertEqual(view.equity,900200);XCTAssertEqual(view.cash,900000);XCTAssertEqual(view.quantity,2);XCTAssertTrue(view.state.contains("신규 진입 중지"));XCTAssertEqual(p.engine.buys,0)}
}
