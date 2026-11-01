import XCTest
@testable import CryptoResearch
final class TradeTests:XCTestCase {
 func testPathsAndTLS()throws{XCTAssertTrue(TradeAPI.allowedPath("v1/quote/bithumb/BTC"));XCTAssertTrue(TradeAPI.allowedPath("v1/order/"+String(repeating:"a",count:32)));for p in ["v1/withdraw","v1/quote/other/BTC","v1/order/../secret","v1/balances/binance?token=x"]{XCTAssertFalse(TradeAPI.allowedPath(p))};XCTAssertThrowsError(try TradeAPI.canonical("http://localhost:8090"));XCTAssertThrowsError(try TradeAPI.canonical("https://user@host/"))}
 func testSeparateTokenVault(){XCTAssertNotEqual(TradeVault.service,ServerVault.service)}
 @MainActor func testDecimalAndDraft()throws{for s in ["0","NaN","1e5","-1","1,000",".01"]{XCTAssertFalse(TradeStore.decimal(s))};XCTAssertTrue(TradeStore.decimal("0.000001"));let store=TradeStore();store.amount="0.1";store.price="100";let d=try store.draft();XCTAssertEqual(d["exchange"] as? String,"binance");XCTAssertEqual(d["side"] as? String,"buy");XCTAssertEqual((d["draft_id"] as? String)?.count,32);store.cancel()}
 @MainActor func testNoRequestsWithoutSavedCredentials(){let store=TradeStore();store.savedBase="";store.savedToken="";store.call("v1/capabilities");XCTAssertFalse(store.busy);XCTAssertNil(store.task);XCTAssertNil(store.review)}
}
