import Foundation
import SwiftUI
@MainActor final class MarketStore: ObservableObject {
 let symbols=["BTC","ETH","XRP","SOL","DOGE","ADA"]
 let names=["BTC":"비트코인","ETH":"이더리움","XRP":"리플","SOL":"솔라나","DOGE":"도지코인","ADA":"에이다"]
 @Published var quotes:[String:Quote]=[:]
 @Published var history:[String:[Observation]]=[:]
 @Published var alerts:[AlertRecord]=[]
 @Published var connected=false
 @Published var status="연결 안 됨"
 @Published var now=Date()
 @Published var fx:Double?
 @Published var fxDate:Date?
 @Published var fxReceived=Date.distantPast
 @Published var favorites:Set<String> { didSet { save() } }
 @Published var selected:String { didSet { save() } }
 @Published var manual:Bool { didSet { resetAlerts(); save() } }
 @Published var manualFx:Double { didSet { resetAlerts(); save() } }
 @Published var alertsEnabled:Bool { didSet { resetAlerts(); save() } }
 @Published var threshold:Double { didSet { resetAlerts(); save() } }
 var upbit:URLSessionWebSocketTask?, binance:URLSessionWebSocketTask?, clock:Task<Void,Never>?, fxTask:Task<Void,Never>?
 var generation=0, foreground=true, lastFXTry=Date.distantPast, alarms:[String:PremiumAlert]=[:], usdt=Quote()
 @Published var paper:LivePaper?
 let session:URLSession
 init() {
  let d=UserDefaults.standard
  favorites=Set(d.stringArray(forKey:"favorites") ?? ["BTC","ETH"])
  let savedCoin=d.string(forKey:"coin") ?? "BTC"
  selected=["BTC","ETH","XRP","SOL","DOGE","ADA"].contains(savedCoin) ? savedCoin:"BTC"
  manual=d.bool(forKey:"manual"); let f=d.double(forKey:"manualFx");manualFx=f.isFinite && f>0 ? f:1400
  alertsEnabled=d.bool(forKey:"alerts");let t=d.double(forKey:"threshold");threshold=t.isFinite && t>0 && t<=100 ? t:2
  let config=URLSessionConfiguration.ephemeral;config.timeoutIntervalForRequest=15;config.timeoutIntervalForResource=25;session=URLSession(configuration:config)
  for s in symbols { quotes[s]=Quote(); history[s]=[] }
 }
 func save() { let d=UserDefaults.standard;d.set(Array(favorites),forKey:"favorites");d.set(selected,forKey:"coin");d.set(manual,forKey:"manual");d.set(manualFx,forKey:"manualFx");d.set(alertsEnabled,forKey:"alerts");d.set(threshold,forKey:"threshold") }
 func resetAlerts(){ alarms=[:] }
 var effectiveFX:Double? { if manual {return manualFx.isFinite && manualFx>0 ? manualFx:nil};guard now.timeIntervalSince(fxReceived)<21600, let date=fxDate, (-86400...432000).contains(now.timeIntervalSince(date)) else{return nil};return fx }
 func premium(_ symbol:String)->Double? { MarketMath.premium(quotes[symbol] ?? Quote(),fx:effectiveFX,now:now) }
 func gap(_ symbol:String)->Double? { guard MarketMath.valid(usdt.krw,event:usdt.krwEvent,received:usdt.krwReceived,now:now,maxAge:30) else{return nil};return MarketMath.premium(quotes[symbol] ?? Quote(),fx:usdt.krw,now:now) }
 func price(_ symbol:String)->Double? { let q=quotes[symbol] ?? Quote();return MarketMath.valid(q.krw,event:q.krwEvent,received:q.krwReceived,now:now,maxAge:30) ? q.krw:nil }
 func toggleFavorite(_ s:String) { if favorites.contains(s){favorites.remove(s)}else{favorites.insert(s)} }
 func setForeground(_ value:Bool) { foreground=value;if value { startClock();if connected { connectSockets() } } else {stopTasks()} }
 func startClock() { guard clock==nil else{return};clock=Task { [weak self] in while !Task.isCancelled {guard let self=self else{return};self.tick();try? await Task.sleep(nanoseconds:1_000_000_000)} } }
 func setConnected(_ value:Bool) { if !value{paper?.pause("시세 연결 종료")};connected=value;stopSockets();if value && foreground {connectSockets()}else{status="연결 안 됨"};startClock() }
 func stopSockets(){generation+=1;upbit?.cancel(with:.goingAway,reason:nil);binance?.cancel(with:.goingAway,reason:nil);upbit=nil;binance=nil;fxTask?.cancel();fxTask=nil}
 func stopTasks(){paper?.pause("백그라운드 일시 정지");clock?.cancel();clock=nil;stopSockets();status="백그라운드 일시 중지"}
 func tick(){now=Date();if let p=paper,p.running,let q=quotes[p.symbol]{if let price=q.krw{p.tick(Int64(q.krwEvent.timeIntervalSince1970*1000),Int64(q.krwReceived.timeIntervalSince1970*1000),Int64(now.timeIntervalSince1970*1000),price)}else if now.timeIntervalSince(p.started)>15{p.pause("시세 수신 대기 초과")}};for s in symbols {let v=premium(s);history[s,default:[]].append(Observation(time:now,price:price(s),premium:v,gap:gap(s)));if history[s,default:[]].count>3600 {history[s]?.removeFirst()};if alertsEnabled {var alarm=alarms[s] ?? PremiumAlert();if alarm.evaluate(v,threshold:threshold,now:now),let v=v {alerts.insert(AlertRecord(date:now,symbol:s,value:v),at:0);if alerts.count>100 {alerts.removeLast()}};alarms[s]=alarm}}
  if connected && foreground {if upbit==nil || binance==nil {connectSockets()};if !manual && now.timeIntervalSince(lastFXTry)>300 && now.timeIntervalSince(fxReceived)>3600 {fetchFX()}}
 }
 func connectSockets(){guard connected && foreground else{return};let gen=generation
  if upbit==nil {let socket=session.webSocketTask(with:URL(string:"wss://api.upbit.com/websocket/v1")!);upbit=socket;socket.resume();let codes=symbols.map{"KRW-"+$0}+["KRW-USDT"];Task {do {let data=try JSONSerialization.data(withJSONObject:[["ticket":"crypto-public"],["type":"ticker","codes":codes]]);try await socket.send(.string(String(decoding:data,as:UTF8.self)));await receive(socket,domestic:true,generation:gen)}catch{if gen==generation{upbit=nil;status="업비트 재연결 대기"}}}}
  if binance==nil {let streams=symbols.map{$0.lowercased()+"usdt@ticker"}.joined(separator:"/");let socket=session.webSocketTask(with:URL(string:"wss://stream.binance.com:9443/stream?streams="+streams)!);binance=socket;socket.resume();Task{await receive(socket,domestic:false,generation:gen)}}
  status="공개 시세 연결 중";if !manual && now.timeIntervalSince(lastFXTry)>300 && now.timeIntervalSince(fxReceived)>3600 {fetchFX()}
 }
 func receive(_ socket:URLSessionWebSocketTask,domestic:Bool,generation gen:Int) async {
  do {while gen==generation && foreground && connected {let message=try await socket.receive();let received=Date();let data:Data;switch message {case .data(let d):data=d;case .string(let s):data=Data(s.utf8);@unknown default:continue};guard gen==generation,let root=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let j=domestic ? root:root["data"] as? [String:Any] else{continue}
   let symbol=domestic ? (j["code"] as? String ?? "").replacingOccurrences(of:"KRW-",with:""):(j["s"] as? String ?? "").replacingOccurrences(of:"USDT",with:"")
   let p=domestic ? (j["trade_price"] as? NSNumber)?.doubleValue:Double(j["c"] as? String ?? "")
   guard let price=p,let milliseconds=(j[domestic ? "trade_timestamp":"E"] as? NSNumber)?.doubleValue else{continue};let event=Date(timeIntervalSince1970:milliseconds/1000)
   if domestic && symbol=="USDT" {if event>=usdt.krwEvent{usdt.krw=price;usdt.krwEvent=event;usdt.krwReceived=received};continue}
   guard var q=quotes[symbol] else{continue};if domestic && event>=q.krwEvent{q.krw=price;q.krwEvent=event;q.krwReceived=received;q.change=(j["signed_change_rate"] as? NSNumber).map{$0.doubleValue*100}}else if !domestic && event>=q.usdEvent{q.usd=price;q.usdEvent=event;q.usdReceived=received};quotes[symbol]=q;status="공개 시세 수신 중"
  }}catch{if gen==generation{if domestic{upbit=nil}else{binance=nil};status="시세 재연결 대기"}}
 }
 func fetchFX(){guard fxTask==nil else{return};lastFXTry=Date();let gen=generation;fxTask=Task{defer{if gen==generation{fxTask=nil}};do {let (data,response)=try await session.data(from:URL(string:"https://api.frankfurter.dev/v2/rates?base=USD&quotes=KRW")!);guard !Task.isCancelled,gen==generation,(response as? HTTPURLResponse)?.statusCode==200,let a=try JSONSerialization.jsonObject(with:data) as? [[String:Any]],let j=a.first,let rate=(j["rate"] as? NSNumber)?.doubleValue,rate.isFinite,rate>0,let dateString=j["date"] as? String else{return};let f=ISO8601DateFormatter();guard let date=f.date(from:dateString+"T00:00:00Z") else{return};fx=rate;fxDate=date;fxReceived=Date();resetAlerts()}catch{}} }
 func exportData()->Data {let rows=symbols.map{s -> [String:Any] in ["symbol":s,"krw":price(s).map{$0 as Any} ?? NSNull(),"fx_premium_pct":premium(s).map{$0 as Any} ?? NSNull(),"usdt_gap_pct":gap(s).map{$0 as Any} ?? NSNull()]};let obj:[String:Any]=["mode":"PUBLIC_QUOTES_SNAPSHOT_ONLY","observed_at":ISO8601DateFormatter().string(from:now),"fx_basis":manual ? "manual":"daily USD/KRW; USDT=USD assumption","fx":effectiveFX.map{$0 as Any} ?? NSNull(),"quotes":rows];return (try? JSONSerialization.data(withJSONObject:obj,options:[.prettyPrinted,.sortedKeys])) ?? Data() }
}
