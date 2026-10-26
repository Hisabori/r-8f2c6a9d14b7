import SwiftUI
import Charts
import UniformTypeIdentifiers
@main struct CryptoResearchApp:App {
 @StateObject private var store=MarketStore()
 @Environment(\.scenePhase) private var scenePhase
 var body:some Scene {WindowGroup{RootView().environmentObject(store).tint(.careBlue).onAppear{store.setForeground(true)}.onChange(of:scenePhase){phase in store.setForeground(phase == .active)}}}
}
extension Color {static let careBlue=Color(red:0.22,green:0.49,blue:0.96);static let careTeal=Color(red:0.09,green:0.66,blue:0.61)}
struct CareCard:ViewModifier {func body(content:Content)->some View{content.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:26,style:.continuous))}}
struct CareControl:ViewModifier {
 @Environment(\.accessibilityReduceTransparency) var reduce
 @ViewBuilder func body(content:Content)->some View{if #available(iOS 26.0,*),!reduce{content.glassEffect(.regular.tint(Color.careBlue.opacity(0.12)).interactive(),in:RoundedRectangle(cornerRadius:18))}else{content.background(Color.careBlue.opacity(0.1),in:RoundedRectangle(cornerRadius:18))}}
}
func percent(_ v:Double?)->String{guard let v=v,v.isFinite else{return "—"};return String(format:"%+.2f%%",v)}
func money(_ v:Double?)->String{guard let v=v,v.isFinite else{return "—"};return v.formatted(.currency(code:"KRW").precision(.fractionLength(v<100 ? 2:0)))}
struct RootView:View {
 @EnvironmentObject var store:MarketStore
 var body:some View {TabView{MarketView(favoritesOnly:false).tabItem{Label("마켓",systemImage:"chart.xyaxis.line")};MarketView(favoritesOnly:true).tabItem{Label("관심",systemImage:"star")};ResearchView().tabItem{Label("연구실",systemImage:"doc.text.magnifyingglass")};SettingsView().tabItem{Label("설정",systemImage:"slider.horizontal.3")}}}
}
struct MarketView:View {
 @EnvironmentObject var store:MarketStore
 let favoritesOnly:Bool
 @State private var search=""
 @State private var metric=0
 @State private var range=5
 @State private var sort=0
 var filtered:[String] {let rows=store.symbols.filter{(!favoritesOnly || store.favorites.contains($0)) && (search.isEmpty || ($0+(store.names[$0] ?? "")).localizedCaseInsensitiveContains(search))};return rows.sorted{a,b in if sort==1 {let x=store.premium(a),y=store.premium(b);if x==nil{return false};if y==nil{return true};return x!>y!};return a<b}}
 var body:some View {NavigationStack{ScrollView{VStack(alignment:.leading,spacing:18){
 HStack{Label(store.status,systemImage:store.connected ? "dot.radiowaves.left.and.right":"wifi.slash");Spacer();Text("모의매매 전용")}.font(.caption).foregroundStyle(.secondary)
 VStack(alignment:.leading,spacing:12){HStack{Text("\(store.names[store.selected] ?? store.selected) · \(store.selected)").font(.headline);Spacer();Button{store.toggleFavorite(store.selected)}label:{Image(systemName:store.favorites.contains(store.selected) ? "star.fill":"star").frame(width:44,height:44)}.accessibilityLabel("관심 종목 변경")}
 Text(money(store.price(store.selected))).font(.system(size:38,weight:.bold,design:.rounded)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
 HStack(spacing:20){metricValue("FX 김프",percent(store.premium(store.selected)));metricValue("USDT 기준 차이",percent(store.gap(store.selected)))}
 Text("UTC 당일 변동 \(percent(store.quotes[store.selected]?.change))").font(.caption).foregroundStyle(.secondary)
 Button{store.setConnected(!store.connected)}label:{Label(store.connected ? "시세 연결 끊기":"실시간 시세 연결",systemImage:store.connected ? "pause.fill":"play.fill").font(.subheadline.weight(.semibold)).frame(maxWidth:.infinity,minHeight:48)}.modifier(CareControl())
 Picker("차트 항목",selection:$metric){Text("원화").tag(0);Text("FX 김프").tag(1);Text("USDT 차이").tag(2)}.pickerStyle(.segmented)
 ObservedChart(points:store.history[store.selected] ?? [],metric:metric,range:range,now:store.now).frame(height:180)
 Picker("관측 구간",selection:$range){ForEach([1,5,15,60],id:\.self){Text("\($0)분").tag($0)}}.pickerStyle(.segmented)
 Text("연결 후 실제 관측한 구간만 표시해요.\nFX 김프는 USDT=USD 가정 · 환율은 일별 참고값").font(.caption2).foregroundStyle(.secondary)

 }.modifier(CareCard())
 HStack{Text("\(filtered.count)개 종목").font(.headline);Spacer();Picker("정렬",selection:$sort){Text("이름순").tag(0);Text("김프 높은순").tag(1)}.pickerStyle(.menu)}
 VStack(spacing:0){ForEach(filtered,id:\.self){s in HStack{Button{store.toggleFavorite(s)}label:{Image(systemName:store.favorites.contains(s) ? "star.fill":"star").frame(width:44,height:56)}.accessibilityLabel("\(s) 관심 변경");Button{store.selected=s}label:{HStack{VStack(alignment:.leading,spacing:4){Text(store.names[s] ?? s).font(.headline).foregroundStyle(.primary);Text(s).font(.caption).foregroundStyle(.secondary)};Spacer();VStack(alignment:.trailing,spacing:4){Text(money(store.price(s))).font(.subheadline.weight(.semibold)).foregroundStyle(.primary);Text("FX \(percent(store.premium(s)))").font(.caption).foregroundStyle(Color.careBlue)}}.frame(minHeight:62)}.buttonStyle(.plain)};if s != filtered.last{Divider()}};if filtered.isEmpty{ContentUnavailable("관심 종목이 없어요",description:"별을 눌러 종목을 추가해 보세요.")}}.modifier(CareCard())
 VStack(alignment:.leading,spacing:12){Text("김프 알림").font(.headline);if store.alerts.isEmpty{Text("설정에서 앱 내 알림을 켤 수 있어요.").font(.subheadline).foregroundStyle(.secondary)};ForEach(store.alerts.prefix(8)){a in HStack{Text("\(a.symbol)  \(percent(a.value))");Spacer();Text(a.date,style:.time).foregroundStyle(.secondary)}.font(.caption)}}.modifier(CareCard())
 }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle(favoritesOnly ? "관심 종목":"마켓").searchable(text:$search,prompt:"코인 검색")}}
 func metricValue(_ label:String,_ value:String)->some View{VStack(alignment:.leading,spacing:4){Text(label).font(.caption).foregroundStyle(.secondary);Text(value).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(Color.careBlue)}}
}
struct ContentUnavailable:View {let title:String;let description:String;init(_ title:String,description:String){self.title=title;self.description=description};var body:some View{VStack(spacing:8){Image(systemName:"star").font(.largeTitle);Text(title).font(.headline);Text(description).font(.caption)}.foregroundStyle(.secondary).frame(maxWidth:.infinity,minHeight:100)}}
struct ChartSample:Identifiable{let id:UUID;let time:Date;let value:Double;let segment:Int}
struct ObservedChart:View {
 let points:[Observation];let metric:Int;let range:Int;let now:Date
 var samples:[ChartSample]{var out:[ChartSample]=[];var segment=0;var previous:Date?;for p in points where p.time>=now.addingTimeInterval(Double(-range*60)){let v=metric==0 ? p.price:metric==1 ? p.premium:p.gap;guard let v=v,v.isFinite else{segment+=1;previous=nil;continue};if let previous=previous,p.time.timeIntervalSince(previous)>3{segment+=1};out.append(ChartSample(id:p.id,time:p.time,value:v,segment:segment));previous=p.time};return out}
 var body:some View{Group{if samples.count<2{VStack{Image(systemName:"waveform.path").font(.largeTitle);Text("관측 데이터가 쌓이면 표시됩니다").font(.caption)}.foregroundStyle(.secondary).frame(maxWidth:.infinity,maxHeight:.infinity)}else{Chart(samples){p in LineMark(x:.value("관측 시각",p.time),y:.value("값",p.value),series:.value("연속 구간",p.segment)).foregroundStyle(Color.careBlue).lineStyle(StrokeStyle(lineWidth:2.5))}.chartXScale(domain:now.addingTimeInterval(Double(-range*60))...now).chartYScale(domain:.automatic(includesZero:false)).chartXAxis{AxisMarks(values:.automatic(desiredCount:3)){AxisGridLine();AxisValueLabel(format:.dateTime.hour().minute())}}.accessibilityLabel("실제 관측 데이터 차트")}}}
}
struct SettingsView:View {
 @EnvironmentObject var store:MarketStore
 @State private var rate=""
 @State private var threshold=""
 @State private var error=""
 var body:some View{NavigationStack{Form{Section("김프 환산 기준"){Toggle("수동 USD/KRW 사용",isOn:$store.manual);TextField("수동 환율",text:$rate).keyboardType(.decimalPad);Text(fxDescription).font(.caption).foregroundStyle(.secondary);Text("자동 환율이 없을 때 수동값을 자동 적용하지 않습니다.").font(.caption)};Section("앱 내 알림"){Toggle("FX 김프 알림",isOn:$store.alertsEnabled);TextField("절대 김프 기준 (%)",text:$threshold).keyboardType(.decimalPad);Text("앱을 보고 있을 때만 기록해요. 임계값 재진입과 60초 간격을 적용합니다.").font(.caption)};Section{Button("환율·알림 기준 저장"){guard let r=Double(rate),r.isFinite,r>0,let t=Double(threshold),t.isFinite,t>0,t<=100 else{error="양수 환율과 0 초과 100 이하 기준을 입력하세요.";return};store.manualFx=r;store.threshold=t;error="저장했어요"};Text(error).font(.caption)};Section("연구 전용"){Text("공개 시세만 사용하며 주문·계좌·API 키 기능은 없습니다.");Text("FX 김프 = (KRW 가격 ÷ (USDT 가격 × USD/KRW) − 1) × 100. USDT=USD를 가정합니다.");Text("USDT 기준 차이는 국내 USDT 시세로 환산한 거래소 간 차이입니다. 김프는 거래 가능한 순이익을 뜻하지 않습니다.");Text("Crypto Research 1.0.0 · 개발용").foregroundStyle(.secondary)}}.navigationTitle("설정").onAppear{rate=String(store.manualFx);threshold=String(store.threshold)}}}
 var fxDescription:String{if store.manual{return "수동 환율 \(store.manualFx)"};guard let fx=store.effectiveFX,let date=store.fxDate else{return "일별 환율 이용 불가"};return "일별 USD/KRW \(fx) · 기준일 \(date.formatted(date:.numeric,time:.omitted))"}
}
struct JSONDocument:FileDocument{static var readableContentTypes:[UTType]{[.json]};var data:Data;init(data:Data){self.data=data};init(configuration:ReadConfiguration)throws{data=configuration.file.regularFileContents ?? Data()};func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper{FileWrapper(regularFileWithContents:data)}}
struct ResearchView:View {
 @EnvironmentObject var store:MarketStore
 @State private var importing=false
 @State private var exporting=false
 @State private var busy=false
 @State private var result="Windows 연구실에서 내보낸 결과 JSON을 열어보세요."
 @State private var document=JSONDocument(data:Data())
 var body:some View{NavigationStack{ScrollView{VStack(alignment:.leading,spacing:18){VStack(alignment:.leading,spacing:16){Text("백테스트 리포트").font(.title2.bold());Text("기존 결과 그대로, 모바일에서").foregroundStyle(.secondary);Button{importing=true}label:{Label("결과 JSON 열기",systemImage:"doc.badge.plus").frame(maxWidth:.infinity,minHeight:48)}.modifier(CareControl()).disabled(busy);Button{document=JSONDocument(data:store.exportData());exporting=true}label:{Label("공개 시세 스냅샷 저장",systemImage:"square.and.arrow.up").frame(maxWidth:.infinity,minHeight:48)}.modifier(CareControl());if busy{ProgressView()};Text(result).font(.system(.subheadline,design:.monospaced)).textSelection(.enabled)}.modifier(CareCard());VStack(alignment:.leading,spacing:12){Text("연구 범위").font(.headline);Text("모바일은 시세와 결과 확인용입니다. Python CSV/SQLite 전략 실행은 함께 제공한 Windows/Python 프로젝트에서 수행하세요.");Text("v1.0/v1.1 설정과 결과 원본은 변경하지 않습니다. v1.7 CVD 신호·유동성 증발 시뮬레이션은 개발 예정입니다.");Text("지연·누락은 — 로 표시하고 과거 가격을 생성하지 않습니다.")}.font(.subheadline).foregroundStyle(.secondary).modifier(CareCard())}.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("연구실").fileImporter(isPresented:$importing,allowedContentTypes:[.json],allowsMultipleSelection:false){r in switch r{case .success(let urls):if let u=urls.first{load(u)};case .failure(let e):result="열 수 없어요: \(e.localizedDescription)"}}.fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"crypto-research-snapshot"){r in if case .failure(let e)=r{result="저장 실패: \(e.localizedDescription)"}}}}
 func load(_ url:URL){busy=true;Task{let output=await Task.detached(priority:.userInitiated){()->String in let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};do{let handle=try FileHandle(forReadingFrom:url);defer{try? handle.close()};let data=try handle.read(upToCount:8*1024*1024+1) ?? Data();guard data.count<=8*1024*1024 else{return "8MB 이하 파일만 열 수 있어요."};guard let j=try JSONSerialization.jsonObject(with:data) as? [String:Any],let mode=j["mode"] as? String,mode.count<=200 else{return "기존 백테스트 결과 JSON이 필요해요."};var rows=["가져온 연구 결과 · 실거래 검증 아님",""];for k in ["mode","closed_trades","ending_equity_usdt","return_pct","max_drawdown_pct","win_rate","net_expectancy_usdt","profit_factor_net","halted","full_v1_1_implemented"]{if let v=j[k]{rows.append("\(k): \(v)")}};return rows.joined(separator:"\n")}catch{return "열 수 없어요: \(error.localizedDescription)"}}.value;result=output;busy=false}}
}
