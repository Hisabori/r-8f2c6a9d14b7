import Foundation
import Security
import CoreFoundation
// Tokens are scoped to this device and are never persisted in UserDefaults.
enum TradeVault {
 static let service="app.caresuite.super.crypto.live-trade"
 static func save(_ value:String)throws{let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"token"];let bytes=Data(value.utf8);let status=SecItemUpdate(query as CFDictionary,[kSecValueData as String:bytes] as CFDictionary);if status==errSecItemNotFound{var add=query;add[kSecValueData as String]=bytes;add[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly;guard SecItemAdd(add as CFDictionary,nil)==errSecSuccess else{throw StrategyError.invalid("보안 저장 실패")}}else if status != errSecSuccess{throw StrategyError.invalid("보안 저장 실패")}}
 static func read()->String{let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"token",kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne];var item:CFTypeRef?;guard SecItemCopyMatching(q as CFDictionary,&item)==errSecSuccess,let d=item as? Data else{return ""};return String(data:d,encoding:.utf8) ?? ""}
 static func clear(){SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service] as CFDictionary)}
}
final class NoTradeRedirects:NSObject,URLSessionTaskDelegate {
 func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
}
struct TradeConnectionAccess: Equatable {
 let control: Bool
 let live: Bool
 let canTrade: Bool
 init(_ value: [String:Any]) throws {
  guard value["mode"] as? String == "MANUAL_SPOT_TRADE_BRIDGE" else { throw StrategyError.invalid("거래 서버 종류가 다릅니다. 주소와 서버 버전을 확인하세요.") }
  func flag(_ key: String) -> Bool { guard let number = value[key] as? NSNumber,CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() else { return false };return number.boolValue }
  live = flag("live_enabled");control = flag("can_configure") || flag("can_trade");canTrade = flag("can_trade") && live
 }
 var summary: String { "서버 연결됨 · "+(control ? "제어 토큰":"조회 토큰")+" · 실주문 "+(live ? "켜짐":"꺼짐") }
}
struct TradeHTTPFailure: LocalizedError {
 let status: Int
 let path: String
 var errorDescription: String? { TradeAPI.failureMessage(status,path:path) }
}

enum TradeAPI {
 static func canonical(_ raw:String)throws->URL {guard let c=URLComponents(string:raw.trimmingCharacters(in:.whitespacesAndNewlines)),c.scheme?.lowercased()=="https",let host=c.host,!host.isEmpty,c.user==nil,c.password==nil,c.query==nil,c.fragment==nil,(c.path.isEmpty || c.path=="/"),let u=c.url else{throw StrategyError.invalid("HTTPS 서버 기본 주소만 입력하세요 (경로·계정·쿼리 제외)")};return u}
 static func allowedPath(_ path:String)->Bool{["v1/capabilities","v1/preview","v1/submit","v1/cancel"].contains(path) || path.range(of:"^v1/quote/(binance|bingx|bithumb|bitget)/(BTC|ETH|XRP|SOL|DOGE|ADA)$",options:.regularExpression) != nil || path.range(of:"^v1/performance/(binance|bingx|bithumb|bitget)/(BTC|ETH|XRP|SOL|DOGE|ADA)$",options:.regularExpression) != nil || path.range(of:"^v1/orders/(binance|bingx|bithumb|bitget)$",options:.regularExpression) != nil || path.range(of:"^v1/balances/(binance|bingx|bithumb|bitget)$",options:.regularExpression) != nil || path.range(of:"^v1/order/[0-9a-f]{32}$",options:.regularExpression) != nil}

 static func validateToken(_ raw: String) throws -> String {
  let token = raw.trimmingCharacters(in:.whitespacesAndNewlines)
  let upper = token.uppercased()
  guard !upper.hasPrefix("BEARER "),!upper.hasPrefix("TRADE_READ_TOKEN="),!upper.hasPrefix("TRADE_CONTROL_TOKEN=") else { throw StrategyError.invalid("토큰 값만 입력하세요. 변수명과 = 또는 Bearer 접두사는 제외합니다.") }
  guard (32...512).contains(token.utf8.count),token.utf8.allSatisfy({ (33...126).contains($0) }) else { throw StrategyError.invalid("32~512자의 공백 없는 서버 토큰이 필요합니다. 거래소 API 키가 아닌 서버 토큰을 입력하세요.") }
  return token
 }
 static func isMutation(_ path: String) -> Bool { path == "v1/submit" || path == "v1/cancel" }
 static func failureMessage(_ status: Int,path: String) -> String {
  let message: String
  switch status {
  case 401 where path == "health": message = "HTTP 401 · HTTPS 프록시 인증 구성을 확인하세요."
  case 401: message = "HTTP 401 · 서버 토큰 인증 실패. 현재 실행 중인 서버의 토큰 값인지, 다른 폴더의 .env를 복사하지 않았는지 확인하세요."
  case 403: message = "HTTP 403 · 읽기/제어 권한과 서버 허용 범위를 확인하세요."
  case 404: message = "HTTP 404 · 서버 기본 주소·API 경로·버전을 확인하세요."
  case 409: message = "HTTP 409 · 검토 만료·요청 충돌 또는 서버 보호 상태를 확인하세요."
  case 429: message = "HTTP 429 · 요청 제한입니다. 자동 재시도하지 않습니다."
  default: message = "서버 요청 실패 (HTTP \(status)). 서버 상태와 연결을 확인하세요."
  }
  return message+(isMutation(path) ? " 제출·취소 결과를 추정하거나 재요청하지 말고 검토 ID로 상태를 먼저 확인하세요.":"")
 }
 static func transportFailure(_ path: String) -> String { "서버 연결 실패 또는 시간 초과. Tailscale·HTTPS 주소·서버 실행 상태를 확인하세요."+(isMutation(path) ? " 제출·취소 결과가 불명확하므로 검토 ID로 상태를 먼저 확인하세요.":"") }
 static func healthRequest(_ base: String) throws -> URLRequest {
  var request = URLRequest(url:try canonical(base).appendingPathComponent("health"));request.timeoutInterval = 15
  request.cachePolicy = .reloadIgnoringLocalCacheData;request.setValue("no-store",forHTTPHeaderField:"Cache-Control");request.setValue("application/json",forHTTPHeaderField:"Accept")
  return request
 }
 static func makeRequest(base: String,token: String,path: String,body: [String:Any]? = nil) throws -> URLRequest {
  let root = try canonical(base),secret = try validateToken(token)
  guard allowedPath(path),(body == nil || ["v1/preview","v1/submit","v1/cancel"].contains(path)) else { throw StrategyError.invalid("서버 요청 경로를 확인하세요.") }
  var request = URLRequest(url:URL(string:root.absoluteString.trimmingCharacters(in:CharacterSet(charactersIn:"/"))+"/"+path)!)
  request.timeoutInterval = 15;request.cachePolicy = .reloadIgnoringLocalCacheData
  request.setValue("Bearer "+secret,forHTTPHeaderField:"Authorization");request.setValue("application/json",forHTTPHeaderField:"Accept");request.setValue("no-store",forHTTPHeaderField:"Cache-Control")
  if let body { request.httpMethod = "POST";request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.httpBody = try JSONSerialization.data(withJSONObject:body) }
  return request
 }
 private static func execute(_ request: URLRequest,path: String,session supplied: URLSession?) async throws -> Data {
  let active: URLSession
  if let supplied { active = supplied } else {
   let config = URLSessionConfiguration.ephemeral;config.timeoutIntervalForResource = 20;config.urlCache = nil;config.httpCookieStorage = nil;config.httpShouldSetCookies = false
   active = URLSession(configuration:config,delegate:NoTradeRedirects(),delegateQueue:nil)
  }
  defer { if supplied == nil { active.invalidateAndCancel() } }
  let (bytes,response) = try await active.bytes(for:request)
  guard let http = response as? HTTPURLResponse else { throw StrategyError.invalid("서버 응답 형식을 확인하세요.") }
  guard http.statusCode == 200 else { throw TradeHTTPFailure(status:http.statusCode,path:path) }
  guard http.expectedContentLength <= 1_048_576 else { throw StrategyError.invalid("서버 응답이 1MB 상한을 초과했습니다.") }
  var data = Data()
  for try await byte in bytes { guard data.count < 1_048_576 else { throw StrategyError.invalid("서버 응답이 1MB 상한을 초과했습니다.") };data.append(byte) }
  return data
 }
 static func probe(base: String,session: URLSession? = nil) async throws {
  let data = try await execute(healthRequest(base),path:"health",session:session)
  guard let value = (try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value["status"] as? String == "ok" else { throw StrategyError.invalid("상태 응답이 다릅니다. 거래 서버 주소를 확인하세요.") }
 }
 static func request(base: String,token: String,path: String,body: [String:Any]? = nil,session: URLSession? = nil) async throws -> Data {
  try await execute(makeRequest(base:base,token:token,path:path,body:body),path:path,session:session)
 }
}
