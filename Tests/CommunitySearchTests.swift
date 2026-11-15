import XCTest
@testable import CryptoResearchKit
final class CommunitySearchTests:XCTestCase {
 let now:Int64=1800000000000
 func post(_ id:String,_ title:String,_ source:String="DCINSIDE",_ hours:Int64=1)->CommunityPost{
  CommunityPost(source:source,id:id,title:title,url:"",published_ms:now-hours*3600000)
 }
 func testAliasesExclusionAndDedup() throws {
  let rows=[post("a","BTC ETF 승인"),post("b","비트코인 ETF 승인","COINPAN",2),post("c","비트코인 ETF 광고")]
  let result=try CommunitySearch.run(rows,query:"BTC ETF -광고",source:"전체",relevant:true,now:now)
  XCTAssertEqual(result.hits.map{$0.post.id},["a"]);XCTAssertEqual(result.duplicates,1)
  let korean=try CommunitySearch.run(rows,query:"비트코인 ETF -광고",source:"전체",relevant:true,now:now)
  XCTAssertEqual(korean.hits.first?.post.id,"b")
  XCTAssertTrue(korean.hits.first!.reasons.contains("비트코인"))
 }
 func testSourceBoundaryUnicodeAndLiteralQuery() throws {
  let rows=[post("a","solution 출시"),post("b","SOL 업그레이드"),post("c","ＢＴＣ ETF 승인","COINPAN")]
  XCTAssertEqual(try CommunitySearch.run(rows,query:"sol",source:"전체",relevant:true,now:now).hits.map{$0.post.id},["b"])
  XCTAssertEqual(try CommunitySearch.run(rows,query:"btc",source:"COINPAN",relevant:true,now:now).hits.count,1)
  XCTAssertTrue(try CommunitySearch.run(rows,query:".*",source:"전체",relevant:true,now:now).hits.isEmpty)
 }
 func testDateBoundsAndInputBounds() throws {
  let rows=[post("a","BTC 현재"),post("b","BTC 미래","DCINSIDE",-1),post("c","BTC 과거","COINPAN",8*24)]
  XCTAssertEqual(try CommunitySearch.run(rows,query:"",source:"전체",relevant:false,now:now).hits.map{$0.post.id},["a"])
  XCTAssertThrowsError(try CommunitySearch.run(rows,query:String(repeating:"a",count:121),source:"전체",relevant:true,now:now))
  XCTAssertThrowsError(try CommunitySearch.run(rows,query:"a b c d e f g h i",source:"전체",relevant:true,now:now))
 }
}
