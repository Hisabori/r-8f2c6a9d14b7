import SwiftUI

struct ServerDiagnostic:Decodable {
 let mode:String,version:String,live_orders_supported:Bool
 let uptime_seconds:Double,feed_frames:Int,feed_reconnects:Int,database_bytes:Int
 let workers:[String:String],session_state:String
}
struct ServerEvent:Decodable,Identifiable {
 let id:Int64,created_ms:Int64,kind:String,detail:String
 var date:Date{Date(timeIntervalSince1970:Double(created_ms)/1000)}
 var title:String{switch kind{case "started":return "모의세션 시작";case "paused":return "모의세션 정지";case "restored":return "계좌 복원 · 정지 상태";case "feed_retry":return "시세 재연결";case "worker_failed":return "서버 작업 중단";default:return kind}}
}
struct ServerEventPage:Decodable{let items:[ServerEvent];let next_before:Int64?}
struct ArchivedPaperSession:Decodable,Identifiable {
 let session_id:String,symbol:String;let archived_at:Double
 var id:String{session_id}
 var date:Date{Date(timeIntervalSince1970:archived_at)}
}
struct ArchivedSessionPage:Decodable{let items:[ArchivedPaperSession]}
@MainActor final class ServerOperationsStore:ObservableObject {
 @Published var diagnostic:ServerDiagnostic?
 @Published var events=[ServerEvent]()
 @Published var sessions=[ArchivedPaperSession]()
 @Published var report=Data()
 @Published var message="새로고침하면 서버1.4 운영 기록을 가져옵니다."
 @Published var busy=false
 @Published var received:Date?
 @Published var nextBefore:Int64?
 private var generation=0
 private var task:Task<Void,Never>?
 let base:String,token:String
 init(base:String,token:String){self.base=base;self.token=token}
 func cancel(){generation+=1;task?.cancel();task=nil;busy=false}
 func load(_ path:String){
  cancel();guard !base.isEmpty,!token.isEmpty else{message="이전 화면에서 HTTPS 주소와 서버 토큰을 먼저 저장하세요.";return}
  let revision=generation;busy=true;message="조회 중 · 기존 표시는 이전 수신 결과입니다."
  task=Task{defer{if revision==generation{busy=false}};do{
   let data=try await PaperServerAPI.request(base:base,token:token,path:path)
   guard !Task.isCancelled,revision==generation else{return}
   try apply(path,data:data);received=Date();message="조회 당시의 서버 기록입니다. 최신 상태는 새로고침하세요."
  }catch{guard revision==generation,!Task.isCancelled else{return};message="조회 실패: \(error.localizedDescription) · 이전 표시는 과거 수신 결과입니다."}}
 }
 func apply(_ path:String,data:Data)throws{
  let decoder=JSONDecoder()
  if path=="api/v1/diagnostics"{let value=try decoder.decode(ServerDiagnostic.self,from:data);guard value.mode=="SERVER_PAPER_ONLY",!value.live_orders_supported else{throw StrategyError.invalid("모의 서버 응답이 아닙니다")};diagnostic=value}
  else if path.hasPrefix("api/v1/events?"){let page=try decoder.decode(ServerEventPage.self,from:data);events=Array(page.items.prefix(50));nextBefore=page.next_before}
  else if path=="api/v1/sessions?limit=100"{let page=try decoder.decode(ArchivedSessionPage.self,from:data);sessions=Array(page.items.prefix(100))}
  else if path.hasSuffix("/report"){guard let j=try JSONSerialization.jsonObject(with:data) as? [String:Any],j["mode"] as? String=="SERVER_PAPER_EMA_SPOT_V2" else{throw StrategyError.invalid("보관된 모의 리포트 형식 확인 필요")};report=data}
 }
}
struct ServerOperationsView:View {
 @StateObject private var store:ServerOperationsStore
 @State private var tab=0
 init(base:String,token:String){_store=StateObject(wrappedValue:ServerOperationsStore(base:base,token:token))}
 var currentPath:String{tab==0 ? "api/v1/diagnostics":tab==1 ? "api/v1/events?limit=50":"api/v1/sessions?limit=100"}
 var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){
  VStack(alignment:.leading,spacing:12){Label("모의 서버 운영",systemImage:"server.rack").font(.title2.bold());Text(store.base.isEmpty ? "서버 설정을 먼저 저장하세요.":store.base).font(.caption).foregroundStyle(.secondary);Text("진단·운영 기록·이전 계좌를 조회합니다. 서버1.4 이상이 필요합니다.").font(.subheadline);Picker("보기",selection:$tab){Text("진단").tag(0);Text("운영 기록").tag(1);Text("이전 세션").tag(2)}.pickerStyle(.segmented);Button("새로고침"){store.load(currentPath)}.frame(minHeight:44);if store.busy{ProgressView()};Text(store.message).font(.caption).foregroundStyle(.secondary);if let date=store.received{Text("마지막 앱 수신 \(date.formatted(date:.numeric,time:.standard))").font(.caption).foregroundStyle(.secondary)}}.modifier(CareCard())
  if tab==0{diagnostic}
  if tab==1{events}
  if tab==2{sessions}
  Text("서버 운영 센터는 조회 전용입니다. Gram 절전·전원 종료 중에는 서버도 멈춥니다. 실제 주문은 지원하지 않습니다.").font(.caption).foregroundStyle(.secondary)
 }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("서버 운영 센터").onChange(of:tab){_ in store.cancel();store.report=Data()}.onDisappear{store.cancel()}}
 @ViewBuilder var diagnostic:some View{if let d=store.diagnostic{VStack(alignment:.leading,spacing:12){Text("서버 \(d.version)").font(.headline);Label(Self.state(d.session_state),systemImage:d.session_state=="running" ? "play.circle.fill":"pause.circle").foregroundStyle(d.session_state=="running" ? .green:.orange);HStack{metric("가동 시간",String(format:"%.0f초",d.uptime_seconds));Spacer();metric("재연결","\(d.feed_reconnects)회")};HStack{metric("수신 프레임","\(d.feed_frames)");Spacer();metric("DB 본체","\(d.database_bytes/1024)KB")};ForEach(d.workers.keys.sorted(),id:\.self){key in HStack{Text(key);Spacer();Text(Self.state(d.workers[key] ?? "—")).foregroundStyle(d.workers[key]=="running" ? .green:.orange)}};Text("횟수는 서버 재시작 때 초기화됩니다. DB 크기는 WAL을 제외합니다. 작업 중단 시 관리자가 상태를 확인하고 서버를 재시작해야 합니다.").font(.caption).foregroundStyle(.secondary)}.modifier(CareCard())}}
 func metric(_ title:String,_ value:String)->some View{VStack(alignment:.leading,spacing:4){Text(title).font(.caption).foregroundStyle(.secondary);Text(value).font(.title3.bold())}}
 @ViewBuilder var events:some View{if store.events.isEmpty{Text("조회된 운영 기록이 없습니다.").modifier(CareCard())};ForEach(store.events){event in VStack(alignment:.leading,spacing:8){Label(event.title,systemImage:event.kind=="worker_failed" ? "exclamationmark.triangle":"clock").font(.headline);Text(event.date.formatted(date:.numeric,time:.standard)).font(.caption).foregroundStyle(.secondary);Text(event.detail).font(.subheadline).textSelection(.enabled)}.modifier(CareCard())};if let next=store.nextBefore,next>0{Button("이전 기록 50개"){store.load("api/v1/events?limit=50&before=\(next)")}.frame(minHeight:44)}}
 @ViewBuilder var sessions:some View{if store.sessions.isEmpty{Text("조회된 이전 세션이 없습니다.").modifier(CareCard())};if !store.report.isEmpty{VStack(alignment:.leading,spacing:8){Text("보관된 모의 리포트").font(.headline);Text("현재 계좌와 별도이며 잔여 모의 보유를 포함합니다.").font(.caption);ResearchAnalyticsView(data:store.report)}.modifier(CareCard())};ForEach(store.sessions){session in VStack(alignment:.leading,spacing:8){Text("\(session.symbol) · 보관된 모의계좌").font(.headline);Text(session.date.formatted(date:.numeric,time:.standard)).font(.caption).foregroundStyle(.secondary);Button("리포트 열기"){store.load("api/v1/sessions/\(session.session_id)/report")}.frame(minHeight:44).disabled(!PaperServerAPI.allowedPath("api/v1/sessions/\(session.session_id)/report"))}.modifier(CareCard())};Text("최근100개까지 표시합니다. 새 모의세션 시작 시 직전 계좌가 서버에 보관됩니다.").font(.caption).foregroundStyle(.secondary)}
 static func state(_ value:String)->String{switch value{case "running":return "실행 중";case "paused":return "정지";case "idle":return "대기";case "failed":return "작업 중단";default:return value}}
}
