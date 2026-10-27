import Foundation
// Does not change running strategies, accounts, or server settings.
enum ResearchSupport {
 static func boundedDraft(_ value:String)->String{String(value.prefix(32))}
 static func serverReport(_ data:Data)throws->Data {
  guard !data.isEmpty,data.count<=8*1024*1024,let j=try JSONSerialization.jsonObject(with:data) as? [String:Any],j["mode"] as? String=="SERVER_PAPER_EMA_SPOT_V2",(j["report_schema_version"] as? NSNumber)?.intValue==2 else{throw StrategyError.invalid("서버 모의 리포트 형식 확인 필요")};return data
 }
}
struct PaperAccountOverview {
 let symbol:String,state:String,equity:Double,cash:Double,quantity:Double
 init(_ paper:LivePaper){let engine=paper.engine;symbol=paper.symbol;state=(paper.running ? "실행 중":"정지")+(engine.halted ? " · 신규 진입 중지":"");equity=engine.equity;cash=engine.cash;quantity=engine.qty}
}
