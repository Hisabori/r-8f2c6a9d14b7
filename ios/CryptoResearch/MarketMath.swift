import Foundation
struct Quote {
 var krw: Double?, usd: Double?, change: Double?
 var krwEvent = Date.distantPast, krwReceived = Date.distantPast, usdEvent = Date.distantPast, usdReceived = Date.distantPast
}
enum MarketMath {
 static func valid(_ price: Double?, event: Date, received: Date, now: Date, maxAge: Double) -> Bool {
  guard let p = price, p.isFinite, p > 0 else { return false }
  return (-5...15).contains(now.timeIntervalSince(received)) && (-5...maxAge).contains(now.timeIntervalSince(event))
 }
 static func premium(_ q: Quote, fx: Double?, now: Date) -> Double? {
  guard valid(q.krw, event:q.krwEvent, received:q.krwReceived, now:now, maxAge:30), valid(q.usd,event:q.usdEvent,received:q.usdReceived,now:now,maxAge:15), abs(q.krwEvent.timeIntervalSince(q.usdEvent)) <= 10, let fx = fx, fx.isFinite, fx > 0, let k=q.krw, let u=q.usd else { return nil }
  return (k/(u*fx)-1)*100
 }
}
struct PremiumAlert {
 var primed=false, armed=true, last=Date.distantPast
 mutating func evaluate(_ value:Double?, threshold:Double, now:Date) -> Bool {
  guard let value=value, value.isFinite, threshold.isFinite, threshold>0 else { return false }; let v=abs(value)
  if !primed { primed=true; armed=v<threshold; return false }
  if v < threshold-min(0.1, threshold*0.2) { armed=true }
  if armed && v>=threshold && now.timeIntervalSince(last)>=60 { last=now; armed=false; return true }; return false
 }
}
struct Observation: Identifiable { let id=UUID(); let time:Date; let price:Double?; let premium:Double?; let gap:Double? }
struct AlertRecord: Identifiable { let id=UUID(); let date:Date; let symbol:String; let value:Double }
