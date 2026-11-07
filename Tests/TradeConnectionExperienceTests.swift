import XCTest
@testable import CryptoResearchKit
private final class ConnectionMockProtocol: URLProtocol {
 private static let lock = NSLock()
 private static var status = 200
 private static var body = Data("{\"status\":\"ok\"}".utf8)
 private static var headers = ["Content-Type":"application/json"]
 private static var requests: [URLRequest] = []
 static func reset(status: Int = 200,body: String = "{\"status\":\"ok\"}",length: String? = nil) {
  lock.lock();defer{lock.unlock()};self.status=status;self.body=Data(body.utf8);self.headers=["Content-Type":"application/json"];if let length{self.headers["Content-Length"]=length};requests=[]
 }
 static func seen() -> [URLRequest] { lock.lock();defer{lock.unlock()};return requests }
 override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.invalid" }
 override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
 override func startLoading() {
  Self.lock.lock();Self.requests.append(request);let code=Self.status,data=Self.body,fields=Self.headers;Self.lock.unlock()
  let response=HTTPURLResponse(url:request.url!,statusCode:code,httpVersion:"HTTP/1.1",headerFields:fields)!
  client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
 }
 override func stopLoading() {}
}
final class TradeConnectionExperienceTests: XCTestCase {
 private func session() -> URLSession {let configuration=URLSessionConfiguration.ephemeral;configuration.protocolClasses=[ConnectionMockProtocol.self];return URLSession(configuration:configuration)}
 func testTokenPasteValidationWithoutEcho() throws {
  let value=String(repeating:"x",count:48)
  XCTAssertEqual(try TradeAPI.validateToken("  "+value+"\n"),value)
  for bad in ["TRADE_READ_TOKEN="+value,"TRADE_CONTROL_TOKEN="+value,"Bearer "+value,"short",value+" x",value+"中",String(repeating:"x",count:513)] {
   XCTAssertThrowsError(try TradeAPI.validateToken(bad)) { error in XCTAssertFalse(error.localizedDescription.contains(value)) }
  }
 }
 func testRoleAndLiveStateRemainSeparate() throws {
  let read=try TradeConnectionAccess(["mode":"MANUAL_SPOT_TRADE_BRIDGE","live_enabled":true,"can_configure":false,"can_trade":false])
  XCTAssertFalse(read.canTrade);XCTAssertTrue(read.summary.contains("조회 토큰"))
  let disabled=try TradeConnectionAccess(["mode":"MANUAL_SPOT_TRADE_BRIDGE","live_enabled":false,"can_configure":true,"can_trade":false])
  XCTAssertFalse(disabled.canTrade);XCTAssertTrue(disabled.summary.contains("실주문 꺼짐"))
  let control=try TradeConnectionAccess(["mode":"MANUAL_SPOT_TRADE_BRIDGE","live_enabled":true,"can_configure":true,"can_trade":true]);XCTAssertTrue(control.canTrade)
  let malformed=try TradeConnectionAccess(["mode":"MANUAL_SPOT_TRADE_BRIDGE","live_enabled":1,"can_trade":true]);XCTAssertFalse(malformed.canTrade)
  XCTAssertThrowsError(try TradeConnectionAccess(["mode":"OTHER"]))
 }
 func testErrorsExplainOperationWithoutIrrelevantOrderWarning() {
  XCTAssertTrue(TradeAPI.failureMessage(401,path:"v1/capabilities").contains("토큰"))
  XCTAssertFalse(TradeAPI.failureMessage(401,path:"v1/capabilities").contains("검토 ID"))
  XCTAssertTrue(TradeAPI.failureMessage(403,path:"v1/capabilities").contains("권한"))
  XCTAssertTrue(TradeAPI.failureMessage(404,path:"v1/capabilities").contains("주소"))
  XCTAssertTrue(TradeAPI.failureMessage(503,path:"v1/submit").contains("검토 ID"))
  XCTAssertFalse(TradeAPI.transportFailure("health").contains("검토 ID"))
 }
 func testHealthRequestContainsNoCredentials() throws {
  let request=try TradeAPI.healthRequest("https://fixture.invalid:8443")
  XCTAssertEqual(request.url?.path,"/health");XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"));XCTAssertNil(request.httpBody)
  XCTAssertEqual(request.value(forHTTPHeaderField:"Cache-Control"),"no-store")
  XCTAssertThrowsError(try TradeAPI.healthRequest("http://fixture.invalid"))
 }
 func testHealthProbeUsesFakeTransportWithoutToken() async throws {
  ConnectionMockProtocol.reset();let session=session();defer{session.invalidateAndCancel()}
  try await TradeAPI.probe(base:"https://fixture.invalid",session:session)
  let requests=ConnectionMockProtocol.seen();XCTAssertEqual(requests.count,1);XCTAssertNil(requests.first?.value(forHTTPHeaderField:"Authorization"))
 }
 func testUnauthorizedIsNotRetriedAndDoesNotExposeToken() async throws {
  ConnectionMockProtocol.reset(status:401,body:"DO_NOT_DISPLAY_RESPONSE_BODY");let session=session();defer{session.invalidateAndCancel()}
  let secret=String(repeating:"x",count:48)
  do{_ = try await TradeAPI.request(base:"https://fixture.invalid",token:secret,path:"v1/capabilities",session:session);XCTFail("401 accepted")}
  catch{XCTAssertEqual((error as? TradeHTTPFailure)?.status,401);XCTAssertFalse(error.localizedDescription.contains(secret));XCTAssertFalse(error.localizedDescription.contains("DO_NOT_DISPLAY_RESPONSE_BODY"))}
  XCTAssertEqual(ConnectionMockProtocol.seen().count,1)
 }
 func testOversizedHealthResponseIsRejectedBeforeConsumption() async throws {
  ConnectionMockProtocol.reset(body:String(repeating:"x",count:2_097_152),length:"2097152");let session=session();defer{session.invalidateAndCancel()}
  do{try await TradeAPI.probe(base:"https://fixture.invalid",session:session);XCTFail("oversize accepted")}
  catch{XCTAssertTrue(error.localizedDescription.contains("1MB"))}
 }
 @MainActor func testReadRoleCannotDispatchOrderAndChangedInputInvalidatesPermission() throws {
  let store=TradeStore(),secret=String(repeating:"x",count:48)
  store.address="https://fixture.invalid";store.savedBase=store.address;store.token=secret;store.savedToken=secret;store.amount="1";store.price="100"
  try store.render(["mode":"MANUAL_SPOT_TRADE_BRIDGE","live_enabled":true,"can_configure":false,"can_trade":false],"capabilities","")
  XCTAssertFalse(store.canSubmit);store.preview();XCTAssertNil(store.task);XCTAssertNil(store.review)
  try store.render(["mode":"MANUAL_SPOT_TRADE_BRIDGE","live_enabled":true,"can_configure":true,"can_trade":true],"capabilities","")
  XCTAssertTrue(store.canSubmit);store.address="https://other.invalid";XCTAssertFalse(store.canSubmit)
  store.invalidateAccess();XCTAssertNil(store.access)
 }
}
