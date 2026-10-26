import SwiftUI
import UniformTypeIdentifiers
struct StrategyResearchView:View {
 @EnvironmentObject var store:MarketStore
 @State private var capital="1000000"
 @State private var fee="5"
 @State private var slip="5"
 @State private var importing=false
 @State private var exporting=false
 @State private var busy=false
 @State private var result="CSV를 선택하면 휴대폰 안에서 백테스트합니다."
 @State private var csvReport=Data()
 @State private var document=JSONDocument(data:Data())
 var body:some View{NavigationStack{ScrollView{VStack(alignment:.leading,spacing:18){
 VStack(alignment:.leading,spacing:14){Text("전략 실행").font(.title2.bold());Text("EMA9/21 현물 매수·청산 · 모의 전용").font(.subheadline).foregroundStyle(.secondary);Text("시작 자본 (입력 가격 통화)").font(.caption).foregroundStyle(.secondary);TextField("시작 자본 (입력 가격 통화)",text:$capital).keyboardType(.decimalPad).textFieldStyle(.roundedBorder);HStack{VStack(alignment:.leading){Text("수수료 (bps)").font(.caption);TextField("수수료 bps",text:$fee).keyboardType(.decimalPad)};VStack(alignment:.leading){Text("슬리피지 (bps)").font(.caption);TextField("슬리피지 bps",text:$slip).keyboardType(.decimalPad)}}.textFieldStyle(.roundedBorder);Text("자본 10% 진입 · 손절 1.5% · 익절 3% · 30봉 준비 · 시작 자본 5% 손실 시 신규 진입 중지").font(.caption).foregroundStyle(.secondary);Button{importing=true}label:{Label("CSV 백테스트 실행",systemImage:"play.rectangle").frame(maxWidth:.infinity,minHeight:48)}.modifier(CareControl()).disabled(busy);if busy{ProgressView()};Text(result).font(.system(.caption,design:.monospaced)).textSelection(.enabled);if !csvReport.isEmpty{ResearchAnalyticsView(data:csvReport)};Button("CSV 결과 JSON 저장"){document=JSONDocument(data:csvReport);exporting=true}.disabled(csvReport.isEmpty).frame(minHeight:44)
 }.modifier(CareCard())
 VStack(alignment:.leading,spacing:14){Text("실시간 모의매매").font(.title2.bold());Text("\(store.selected) · 업비트 KRW · 관측 가격 1분봉").font(.subheadline);Text("첫 부분봉 제외, 30개 완성봉 준비가 필요해요. 수신 공백·백그라운드에서는 일시 정지하며 남은 모의 보유분은 유지합니다. 새 세션은 모의계좌를 초기화합니다.").font(.caption).foregroundStyle(.secondary);Button{startPaper()}label:{Label("새 실시간 모의세션 시작",systemImage:"play.circle").frame(maxWidth:.infinity,minHeight:48)}.modifier(CareControl());Button("모의매매 일시 정지"){store.paper?.pause("사용자 일시 정지");store.objectWillChange.send()}.frame(minHeight:44);if let p=store.paper{ProgressView(value:Double(min(p.engine.bars,30)),total:30);Text("준비 \(min(p.engine.bars,30))/30봉 · \(p.engine.halted ? "신규 진입 중지":"신호 관찰")").font(.caption).foregroundStyle(.secondary);Text((p.running ? "실행 중 · ":"정지 · ")+p.symbol+"\n"+p.engine.summary).font(.system(.caption,design:.monospaced)).textSelection(.enabled);Button("모의계좌 JSON 저장"){document=JSONDocument(data:p.engine.report());exporting=true}.frame(minHeight:44)}
 }.modifier(CareCard())
 NavigationLink{ResearchView()}label:{Label("결과 JSON 열기",systemImage:"doc.text").frame(maxWidth:.infinity,minHeight:48)}.modifier(CareControl())
 Text("모바일 EMA는 별도 엔진입니다. 기존 v1.6·v1.1 멀티팩터·v1.7 구현과 동일하지 않습니다. 실거래 자동매매 코드는 동봉된 operator 폴더에서 사용자가 직접 준비·가동합니다. 앱에는 실제 주문 기능이 없습니다.").font(.caption).foregroundStyle(.secondary)
 }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("연구실").fileImporter(isPresented:$importing,allowedContentTypes:[.commaSeparatedText,.plainText],allowsMultipleSelection:false){r in switch r{case .success(let urls):if let u=urls.first{loadCSV(u)};case .failure(let e):result=e.localizedDescription}}.fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"strategy-paper-result"){r in if case .failure(let e)=r{result=e.localizedDescription}}}}
 func parameters()throws->(Double,Double,Double){guard let c=Double(capital),let f=Double(fee),let s=Double(slip)else{throw StrategyError.invalid("숫자를 입력하세요")};_ = try StrategyCore(c,f,s);return(c,f,s)}
 func startPaper(){do{let(c,f,s)=try parameters();store.paper=try LivePaper(store.selected,c,f,s);store.setConnected(true)}catch{result=error.localizedDescription}}
 func loadCSV(_ url:URL){do{let(c,f,s)=try parameters();busy=true;Task{let resultValue=await Task.detached(priority:.userInitiated){()->(String,Data) in let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};do{let handle=try FileHandle(forReadingFrom:url);defer{try? handle.close()};let data=try handle.read(upToCount:8*1024*1024+1) ?? Data();guard data.count<=8*1024*1024,let text=String(data:data,encoding:.utf8)else{throw StrategyError.invalid("UTF-8 CSV 8MB 이하 필요")};let e=try StrategyCore.backtest(StrategyCore.csv(text),c,f,s);return(e.summary,e.report())}catch{return(error.localizedDescription,Data())}}.value;result=resultValue.0;csvReport=resultValue.1;document=JSONDocument(data:resultValue.1);busy=false}}catch{result=error.localizedDescription}}
}
