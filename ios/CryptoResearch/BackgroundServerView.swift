import SwiftUI
@MainActor final class RemotePaperStore:ObservableObject {
 @Published var address=UserDefaults.standard.string(forKey:"paper-server-url") ?? ""
 @Published var token=ServerVault.read()
 @Published var message="서버를 설정하고 상태를 확인하세요."
 @Published var busy=false
 @Published var canControl=false
 @Published var report=Data()
 var confirmedAddress=UserDefaults.standard.string(forKey:"paper-server-url") ?? ""
 var confirmedToken=ServerVault.read()
 var canAutoRefresh:Bool{!confirmedAddress.isEmpty && !confirmedToken.isEmpty && address==confirmedAddress && token==confirmedToken}
 var lastReceived:Date?
 func save(){do{_ = try PaperServerAPI.canonical(address);guard (32...512).contains(token.count),!token.contains(where:{$0.isWhitespace})else{throw StrategyError.invalid("서버 토큰 확인 필요")};try ServerVault.save(token);UserDefaults.standard.set(address,forKey:"paper-server-url");confirmedAddress=address;confirmedToken=token;message="저장했어요. 상태 확인을 눌러 연결하세요.";canControl=false}catch{message=error.localizedDescription}}
 func forget(){ServerVault.clear();token="";confirmedToken="";canControl=false;report=Data();message="기기에서 서버 토큰을 삭제했어요. 서버 세션은 계속 실행됩니다."}
 func call(_ path:String,body:[String:Any]?=nil)async {guard !busy else{return};busy=true;defer{busy=false};do{let base=address,secret=token;let data=try await PaperServerAPI.request(base:base,token:secret,path:path,body:body);guard base==address,secret==token else{return};lastReceived=Date();if path=="api/v1/report"{report=data;let j=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any];message="서버 \(j?["session_symbol"] as? String ?? "—") 모의 리포트를 가져왔어요."}else{guard let j=try JSONSerialization.jsonObject(with:data) as? [String:Any],j["mode"] as? String=="SERVER_PAPER_ONLY",j["live_orders_supported"] as? Bool==false else{throw StrategyError.invalid("지원하는 모의 서버 응답이 아닙니다")};canControl=j["can_control"] as? Bool ?? false;let symbol=j["symbol"] as? String ?? "—",state=j["state"] as? String ?? "unknown",bars=(j["bars"] as? NSNumber)?.intValue ?? 0;message="서버 \(state) · \(symbol)\n준비 \(min(bars,30))/30봉 · \(canControl ? "제어 가능":"읽기 전용")\n\(j["reason"] as? String ?? "")\n휴대폰이 꺼져도 서버 실행은 독립적으로 유지됩니다."}}catch{canControl=false;message="서버 확인 실패: \(error.localizedDescription)"}}
}
struct BackgroundServerView:View {
 @EnvironmentObject var market:MarketStore
 @StateObject private var remote=RemotePaperStore()
 @Environment(\.scenePhase) private var phase
 @State private var capital="1000000"
 @State private var fee="5"
 @State private var slip="5"
 var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){
 VStack(alignment:.leading,spacing:12){Text("Ubuntu 서버 실행").font(.title2.bold());Text("모의전략은 서버에서 계속 실행하고, iPhone은 화면을 열 때 최신 상태를 가져옵니다. 서버가 켜져 있고 네트워크가 유지되어야 합니다.").font(.subheadline).foregroundStyle(.secondary);Text("HTTPS 서버 주소").font(.caption);TextField("https://gram.example.com",text:$remote.address).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).textFieldStyle(.roundedBorder);Text("서버 접근 토큰 · 거래소 API 키가 아닙니다").font(.caption);SecureField("VIEW_TOKEN 또는 CONTROL_TOKEN",text:$remote.token).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder);Button("서버 설정 저장"){remote.save()}.frame(minHeight:44);Button("기기에서 토큰 삭제"){remote.forget()}.frame(minHeight:44);Button("서버 상태 확인"){Task{await remote.call("api/v1/status")}}.frame(minHeight:44).disabled(remote.busy);if remote.busy{ProgressView()};Text(remote.message).font(.subheadline).textSelection(.enabled);if let date=remote.lastReceived{Text("앱 수신: \(date.formatted(date:.numeric,time:.standard))").font(.caption).foregroundStyle(.secondary)}}.modifier(CareCard())
 NavigationLink {ServerOperationsView(base:remote.confirmedAddress,token:remote.confirmedToken)} label:{Label("서버 운영 센터",systemImage:"server.rack").font(.headline).frame(maxWidth:.infinity,minHeight:48)}.modifier(CareCard())
 VStack(alignment:.leading,spacing:12){Text("새 서버 모의세션").font(.headline);Text("선택 종목 \(market.selected) · KRW\n이미 실행 중이면 중복 시작하지 않습니다. 정지 후 새 세션은 이전 모의계좌를 서버에 보관하고 초기화합니다.").font(.caption).foregroundStyle(.secondary);Text("시작 모의 자본 KRW").font(.caption);TextField("자본",text:$capital).keyboardType(.decimalPad).textFieldStyle(.roundedBorder);Text("수수료 / 슬리피지 (bps)").font(.caption);HStack{TextField("수수료",text:$fee);TextField("슬리피지",text:$slip)}.keyboardType(.decimalPad).textFieldStyle(.roundedBorder);Button("새 서버 모의세션 시작"){start()}.frame(minHeight:44).disabled(remote.busy || !remote.canControl || !remote.canAutoRefresh);Button("서버 모의세션 정지"){Task{await remote.call("api/v1/sessions/pause",body:[:])}}.frame(minHeight:44).disabled(remote.busy || !remote.canControl || !remote.canAutoRefresh);Button("서버 리포트 가져오기"){Task{await remote.call("api/v1/report")}}.frame(minHeight:44).disabled(remote.busy)}.modifier(CareCard())
 if !remote.report.isEmpty{ResearchAnalyticsView(data:remote.report).modifier(CareCard())}
 Text("iOS 기기 안의 로컬 모의매매는 백그라운드에서 정지합니다. 서버 모의세션과 별도 계좌이며 실제 주문은 지원하지 않습니다. 앱이 보이지 않을 때의 실시간 화면 갱신/알림은 보장하지 않습니다.").font(.caption).foregroundStyle(.secondary)
 }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("백그라운드 · 서버").task(id:phase){guard phase == .active else{return};while !Task.isCancelled{if remote.canAutoRefresh{await remote.call("api/v1/status")};do{try await Task.sleep(nanoseconds:10_000_000_000)}catch{return}}}}
 func start(){guard let c=Double(capital),let f=Double(fee),let s=Double(slip),c.isFinite,c>0,c<=1e15,f.isFinite,s.isFinite,(0...100).contains(f),(0...100).contains(s)else{remote.message="자본과 비용 입력을 확인하세요";return};Task{await remote.call("api/v1/sessions/start",body:["symbol":market.selected,"capital":c,"fee_bps":f,"slip_bps":s])}}
}
