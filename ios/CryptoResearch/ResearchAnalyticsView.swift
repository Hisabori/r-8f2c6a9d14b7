import SwiftUI
import Charts
struct AnalyticsReport:Decodable {
 var equity_curve:[EquityPoint]?
 var fill_records:[StrategyFill]?
 var win_rate:Double?
 var profit_factor_net:Double?
 var total_fees:Double?
 var price_currency:String?
 var curve_truncated:Bool?
}
struct ResearchAnalyticsView:View {
 let data:Data
 @State private var report:AnalyticsReport?
 @State private var plotted:[EquityPoint]=[]
 var body:some View{VStack(alignment:.leading,spacing:14){Text("성과 리포트 · 모의 결과").font(.title3.bold());if let r=report{HStack{metric("승률",r.win_rate.map{String(format:"%.2f%%",$0*100)} ?? "—");Spacer();metric("손익비",r.profit_factor_net.map{String(format:"%.4f",$0)} ?? "—")};Text("누적 수수료 \(r.total_fees.map{String(format:"%.4f",$0)} ?? "—") · \(r.price_currency == "KRW" ? "KRW":"입력 가격 통화")").font(.caption).foregroundStyle(.secondary);let points=r.equity_curve ?? [];Text("손익 곡선 · 봉 timestamp 기준").font(.headline);if points.count>=2{Chart(Array(plotted.enumerated()),id:\.offset){item in LineMark(x:.value("봉 시각",Date(timeIntervalSince1970:Double(item.element.bar_timestamp_ms)/1000)),y:.value("모의 자산",item.element.equity)).foregroundStyle(Color.careBlue)}.chartYScale(domain:.automatic(includesZero:false)).chartXAxis{AxisMarks(values:.automatic(desiredCount:3))}.frame(height:180).accessibilityLabel("모의 자산 손익 곡선")}else{Text("곡선을 표시할 봉이 부족합니다").foregroundStyle(.secondary)};Text("\(points.count)개 봉 · \(r.curve_truncated == true ? "최근 구간":"전체 입력 구간")\n최종 모의 청산 비용 반영 · 전체 봉으로 지표 계산\n곡선은 극값을 보존해 표시용 샘플링 · 실제 체결 검증 아님").font(.caption2).foregroundStyle(.secondary);Text("최근 체결 내역").font(.headline);let fills=Array((r.fill_records ?? []).suffix(100).reversed());if fills.isEmpty{Text("모의 체결이 없어요").font(.caption).foregroundStyle(.secondary)};ForEach(Array(fills.enumerated()),id:\.offset){item in let f=item.element;VStack(alignment:.leading,spacing:4){Text(f.side).font(.subheadline.bold());Text(Date(timeIntervalSince1970:Double(f.timestamp_ms)/1000),style:.date).font(.caption);Text(String(format:"가격 %.4f · 수량 %.8f\n수수료 %.4f",f.price,f.quantity,f.fee)).font(.system(.caption,design:.monospaced))};Divider()};Text("시각은 입력 봉/관측 기준 · 최대 최근100건").font(.caption2).foregroundStyle(.secondary)}else{ProgressView()}}.task(id:data){let source=data;let decoded=await Task.detached(priority:.userInitiated){try? JSONDecoder().decode(AnalyticsReport.self,from:source)}.value;report=decoded;plotted=chartSample(decoded?.equity_curve ?? [])}}
 func chartSample(_ points:[EquityPoint])->[EquityPoint]{guard points.count>600 else{return points};let step=max(1,points.count/300);var selected=Set<Int>([0,points.count-1]);for start in stride(from:0,to:points.count,by:step){let end=min(points.count,start+step);var low=start,high=start;for i in start..<end{if points[i].equity<points[low].equity{low=i};if points[i].equity>points[high].equity{high=i}};selected.insert(low);selected.insert(high)};return selected.sorted().map{points[$0]}}
 func metric(_ title:String,_ value:String)->some View{VStack(alignment:.leading){Text(title).font(.caption).foregroundStyle(.secondary);Text(value).font(.title2.bold()).monospacedDigit()}}
}
