import SwiftUI
@MainActor final class TradeStore:ObservableObject {
 static let ids=["binance","bingx","bithumb","bitget"]
 static let names=["Binance","BingX","빗썸","Bitget"]
 static let bases=["BTC","ETH","XRP","SOL","DOGE","ADA"]
 static let links=["https://www.binance.com/en/my/settings/api-management","https://bingx.com/en/accounts/api","https://www.bithumb.com/react/api-support/management-api","https://www.bitget.com/account/newapi"]
 @Published var address=UserDefaults.standard.string(forKey:"trade.url") ?? ""
 @Published var token=TradeVault.read()
 @Published var exchange="binance"
 @Published var base="BTC"
 @Published var side="buy"
 @Published var amount=""
 @Published var price=""
 @Published var busy=false
 @Published var message="자동 주문은 시작되지 않습니다. 서버 설정과 API 가이드를 확인하세요."
 @Published var shared:[[String:Any]]=[]
 @Published var sharedRoot=""
 @Published var sharedToken=""
 @Published var performanceSummary: String?
 @Published var review:[String:Any]?
 var reviewKey="",generation=0
 var task:Task<Void,Never>?
 var savedBase=UserDefaults.standard.string(forKey:"trade.url") ?? ""
 var savedToken=TradeVault.read()
 var key:String{[exchange,base,side,amount,price].joined(separator:"|")}
 var lastDescription:String{UserDefaults.standard.string(forKey:"trade.last-description:"+savedBase) ?? ""}
 var last:String{UserDefaults.standard.string(forKey:"trade.last:"+savedBase) ?? ""}
 func save(){guard !busy else{return};do{let u=try TradeAPI.canonical(address).absoluteString.trimmingCharacters(in:CharacterSet(charactersIn:"/"));guard token.count>=32,token.count<=512,!token.contains("\r"),!token.contains("\n")else{throw StrategyError.invalid("토큰 형식 확인 필요")};try TradeVault.save(token);UserDefaults.standard.set(u,forKey:"trade.url");savedBase=u;savedToken=token;address=u;review=nil;message="저장했습니다. 먼저 서버 상태를 확인하세요."}catch{message="HTTPS 주소·토큰·기기 보안 저장소 확인 필요"}}
 func forget(){guard !busy else{return};TradeVault.clear();token="";savedToken="";review=nil;message="기기 토큰만 삭제했습니다. 거래소의 주문은 취소되지 않습니다."}
 func savedMatches()->Bool{guard let u=try? TradeAPI.canonical(address)else{return false};return savedBase==u.absoluteString.trimmingCharacters(in:CharacterSet(charactersIn:"/")) && savedToken==token && !savedToken.isEmpty}
 static func decimal(_ value:String)->Bool{value.range(of:"^(0|[1-9][0-9]{0,14})(\\.[0-9]{1,12})?$",options:.regularExpression) != nil && (Decimal(string:value,locale:Locale(identifier:"en_US_POSIX")) ?? 0)>0}
 func draft()throws->[String:Any]{guard Self.ids.contains(exchange),Self.bases.contains(base),["buy","sell"].contains(side),Self.decimal(amount),Self.decimal(price)else{throw StrategyError.invalid("수량·지정가를 양수로 입력하세요. 소수점은 . 을 사용합니다.")};return ["exchange":exchange,"base":base,"side":side,"amount":amount,"price":price,"draft_id":UUID().uuidString.replacingOccurrences(of:"-",with:"").lowercased()]}
 func preview(){do{call("v1/preview",try draft(),"preview",key)}catch{message=error.localizedDescription}}
 func submit(){guard let id=review?["review_id"] as? String,reviewKey==key else{message="입력 변경 시 다시 주문 검토가 필요합니다.";return};review=nil;call("v1/submit",["review_id":id,"confirmed":true],"submit",key)}
 func status(){guard !last.isEmpty else{message="확인할 주문 ID가 없습니다.";return};call("v1/order/"+last,nil,"status","")}
 func cancelOrder(){guard !last.isEmpty else{return};call("v1/cancel",["review_id":last,"confirmed":true],"cancel","")}
 func cancel(){generation+=1;task?.cancel();task=nil;busy=false;review=nil}
 func call(_ path:String,_ body:[String:Any]?=nil,_ kind:String="capabilities",_ input:String=""){
  guard !busy else{return};guard savedMatches()else{message="먼저 현재 주소와 서버 토큰을 저장하세요.";return};busy=true;generation+=1;let gen=generation,root=savedBase,secret=savedToken;message=kind=="submit" ? "실제 제출 요청 중 · 결과 불명 시 주문 상태를 확인하세요.":"요청 중 · 이전 표시가 최신 상태가 아닐 수 있습니다."
  task=Task{do{let data=try await TradeAPI.request(base:root,token:secret,path:path,body:body);guard gen==generation,!Task.isCancelled else{return};busy=false;guard savedMatches(),root==savedBase,secret==savedToken else{return};guard input.isEmpty || input==key else{message="입력이 변경돼 이전 응답을 적용하지 않았습니다. 제출했다면 마지막 주문 상태를 확인하세요.";return};guard let j=try JSONSerialization.jsonObject(with:data) as? [String:Any]else{throw StrategyError.invalid("응답 형식 확인 필요")};try render(j,kind,input)}catch{guard gen==generation,!Task.isCancelled else{return};busy=false;message="요청 실패 · \(error.localizedDescription)\n실제 제출/취소 후에는 재주문하지 말고 상태를 확인하세요."}}
 }
 func render(_ j:[String:Any],_ kind:String,_ input:String)throws{
  if kind=="history"{guard let items=j["items"] as? [[String:Any]],items.count<=50 else{throw StrategyError.invalid("공통 주문 응답 확인 필요")};shared=items;sharedRoot=savedBase;sharedToken=savedToken;message="선택 계좌의 서버 검토 기록 최근50개입니다. 실제 체결 내역 전체가 아닙니다."}
  else if kind=="preview"{guard let id=j["review_id"] as? String,id.range(of:"^[0-9a-f]{32}$",options:.regularExpression) != nil,j["real_order"] as? Bool==true else{throw StrategyError.invalid("주문 검토 응답 확인 필요")};review=j;reviewKey=input;UserDefaults.standard.set(id,forKey:"trade.last:"+savedBase);UserDefaults.standard.set(reviewText,forKey:"trade.last-description:"+savedBase);message="검토 완료 · 아직 주문을 제출하지 않았습니다."}
  else if kind=="quote"{message="\(j["exchange"] ?? "—") · \(j["symbol"] ?? "—")\n현재가 \(j["price"] ?? "—") \(j["quote_currency"] ?? "—")\n수신 \(j["received_ms"] ?? "—") ms (UTC Unix)\n스냅샷 · 화면에 남은 가격은 변할 수 있습니다."}
  else if kind=="balance"{let rows=j["balances"] as? [[String:Any]] ?? [];message="\(j["exchange"] ?? "—") 계좌 · 조회 당시 잔고\n"+rows.prefix(100).map{"\($0["currency"] ?? "—") 사용가능 \($0["free"] ?? "—") · 주문중 \($0["used"] ?? "—")"}.joined(separator:"\n")}
  else if kind=="performance"{
   let currency=j["currency"] as? String ?? ""
   let today=j["today_realized_pnl"] as? String ?? "—"
   let total=j["cumulative_realized_pnl"] as? String ?? "—"
   let rate=(j["realized_return_pct"] as? String).map { $0+"%" } ?? "—"
   performanceSummary="당일 실현손익 (KST): \(today) \(currency)\n누적 실현손익: \(total) \(currency)\n청산 원가 기준 수익률: \(rate)"
   message="선택 종목의 실현손익을 조회했습니다."
  }
  else if kind=="capabilities"{guard j["mode"] as? String=="MANUAL_SPOT_TRADE_BRIDGE"else{throw StrategyError.invalid("거래 서버 형식 확인 필요")};message=j["live_enabled"] as? Bool==true ? "거래 서버 실주문 활성 · 수동 확인 후 제출 가능합니다.":"거래 서버 연결됨 · 실주문은 비활성 상태입니다."}
  else{message="주문 상태 \(j["state"] ?? "—")\n거래소 주문 ID \(j["exchange_order_id"] ?? "—")\n취소 요청 \(j["cancel_state"] ?? "—")";if let o=j["order"] as? [String:Any]{message+="\n체결 상태 \(o["status"] ?? "—") · 체결 \(o["filled"] ?? "—") · 잔여 \(o["remaining"] ?? "—")"}else{message+="\n결과 불명/대기 상태에서는 새 주문을 만들지 마세요."}}
 }
 func selectShared(_ row:[String:Any]){guard !busy,savedMatches(),sharedRoot==savedBase,sharedToken==savedToken,let rid=row["review_id"] as? String,rid.range(of:"^[0-9a-f]{32}$",options:.regularExpression) != nil else{return};let summary="\(row["exchange"] ?? "—") · \(row["symbol"] ?? "—") · \(row["side"] ?? "—")\n수량 \(row["amount"] ?? "—") · 지정가 \(row["price"] ?? "—")";UserDefaults.standard.set(rid,forKey:"trade.last:"+savedBase);UserDefaults.standard.set(summary,forKey:"trade.last-description:"+savedBase);review=nil;message="공통 주문 선택 · 상태 확인/취소 요청 가능\n"+summary+"\n검토 ID "+rid}
 var reviewText:String{guard let j=review else{return "검토된 주문이 없습니다."};return "\(j["exchange"] ?? "—") · \(j["symbol"] ?? "—") · \(j["side"] ?? "—")\n수량 \(j["amount"] ?? "—") · 지정가 \(j["price"] ?? "—")\n주문금액 \(j["notional"] ?? "—") \(j["quote_currency"] ?? "—")\n수수료 별도 · 검토 유효시간30초"}
}
struct TradeView:View {
 @StateObject private var store=TradeStore()
 @State private var confirmSubmit=false
 @State private var confirmCancel=false
 var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){connection;ticket;performanceCard;sharedOrders;guide}.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("통합 거래소").onDisappear{store.cancel()}.onChange(of:store.key){_ in store.review=nil;store.performanceSummary=nil}.onChange(of:store.address){_ in store.review=nil;store.shared=[];store.performanceSummary=nil}.onChange(of:store.token){_ in store.review=nil;store.shared=[];store.performanceSummary=nil}.confirmationDialog("실제 지정가 주문을 제출할까요?",isPresented:$confirmSubmit,titleVisibility:.visible){Button("실제 주문 제출",role:.destructive){store.submit()};Button("취소",role:.cancel){}}message:{Text(store.reviewText+"\n모의 주문이 아닙니다.")}.alert("거래소에 취소를 요청할까요?",isPresented:$confirmCancel){Button("취소 요청",role:.destructive){store.cancelOrder()};Button("돌아가기",role:.cancel){}}message:{Text(store.lastDescription+"\n이미 체결된 수량은 취소되지 않습니다. 취소 후 주문 상태를 확인하세요.")}}
 var connection:some View{VStack(alignment:.leading,spacing:12){Text("시세 · 계좌 · 수동 실주문").font(.title2.bold());Text("현물 지정가 주문입니다. 모의 전략과 연결되지 않습니다. 거래소 API 키는 Ubuntu 실행 서버에만 보관하며 앱에는 서버 접근 토큰만 저장합니다.").font(.caption);TextField("실주문 서버 HTTPS 주소",text:$store.address).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder);SecureField("실주문 서버 접근 토큰",text:$store.token).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder);Button("거래 서버 설정 저장"){store.save()}.frame(minHeight:44);Button("기기의 거래 토큰 삭제"){store.forget()}.frame(minHeight:44);Button("거래 서버 상태 확인"){store.call("v1/capabilities")}.disabled(store.busy).frame(minHeight:44);Text(store.message).font(.caption).textSelection(.enabled);if store.busy{ProgressView()}}.modifier(CareCard())}
 var ticket:some View{VStack(alignment:.leading,spacing:12){Picker("거래소 선택",selection:$store.exchange){ForEach(Array(TradeStore.ids.enumerated()),id:\.offset){i in Text(TradeStore.names[i.offset]).tag(i.element)}};Picker("거래 종목",selection:$store.base){ForEach(TradeStore.bases,id:\.self){Text($0).tag($0)}};Picker("실주문 방향",selection:$store.side){Text("매수").tag("buy");Text("매도").tag("sell")}.pickerStyle(.segmented);TextField("수량 (기준 코인)",text:$store.amount).keyboardType(.decimalPad).textFieldStyle(.roundedBorder);TextField("지정가 (빗썸 KRW · 나머지 USDT)",text:$store.price).keyboardType(.decimalPad).textFieldStyle(.roundedBorder);Button("선택 거래소 시세 조회"){store.call("v1/quote/"+store.exchange+"/"+store.base,nil,"quote",store.key)}.frame(minHeight:44);Button("선택 거래소 계좌 조회"){store.call("v1/balances/"+store.exchange,nil,"balance",store.key)}.frame(minHeight:44);Button("주문 내용 검토"){store.preview()}.disabled(store.busy).frame(minHeight:44);Text(store.reviewText).font(.caption).textSelection(.enabled);Button("검토한 실제 주문 제출"){confirmSubmit=true}.disabled(store.review==nil || store.busy).frame(minHeight:48).modifier(CareControl());Button("마지막 주문 상태 확인"){store.status()}.frame(minHeight:44);Button("마지막 주문 취소 요청"){confirmCancel=true}.disabled(store.last.isEmpty || store.busy).frame(minHeight:44)}.modifier(CareCard())}
 var performanceCard: some View {
  VStack(alignment: .leading, spacing: 12) {
   Text("실현손익").font(.title2.bold())
   Text(store.exchange.uppercased() + " · " + store.base).font(.subheadline)
   Text(store.performanceSummary ?? "조회하면 당일·누적 실현손익을 표시합니다.")
    .font(.callout).textSelection(.enabled)
   Button("실현손익 새로 조회") {
    store.performanceSummary = nil
    store.call("v1/performance/"+store.exchange+"/"+store.base,nil,"performance",store.key)
   }
   .disabled(store.busy || !store.savedMatches())
   .frame(minHeight: 44)
  }.modifier(CareCard())
 }
 var sharedOrders:some View{VStack(alignment:.leading,spacing:12){Text("모바일·윈도우 공통 주문").font(.title2.bold());Text("선택 계좌의 최근50개 서버 검토 기록입니다. 제출 대기/미제출 기록도 포함합니다. 선택 후 기존 마지막 주문 상태/취소 버튼을 사용하세요.").font(.caption);Button("공통 주문 내역 조회"){store.call("v1/orders/"+store.exchange,nil,"history",store.key)}.disabled(store.busy).frame(minHeight:44);ForEach(Array(store.shared.enumerated()),id:\.offset){entry in Button{store.selectShared(entry.element)}label:{VStack(alignment:.leading){Text("\(entry.element["symbol"] ?? "—") · \(entry.element["side"] ?? "—") · \(entry.element["state"] ?? "—")");Text("수량 \(entry.element["amount"] ?? "—") · 지정가 \(entry.element["price"] ?? "—")").font(.caption);Text("\(entry.element["review_id"] ?? "—")").font(.caption2)}}.disabled(store.busy || store.sharedRoot != store.savedBase || store.sharedToken != store.savedToken)}}.modifier(CareCard())}
 var guide:some View{VStack(alignment:.leading,spacing:12){Text("API 설정 가이드").font(.title2.bold());Text("1. 거래소 API 관리에서 조회·현물 주문 권한과 서버 공인 IP를 설정합니다. 출금 권한은 사용하지 않습니다.\n2. Key·Secret은 서버 .env에 입력합니다. Bitget은 Passphrase도 필요합니다.\n3. 서버 주문 한도와 실주문 활성화를 설정한 뒤 HTTPS 주소·서버 토큰을 위에 저장합니다.\n4. 시세·계좌 확인 → 수량·지정가 검토 → 실제 제출 확인 순서로 사용합니다. 결과가 불명확하면 새 주문을 만들지 말고 상태를 확인하세요.").font(.subheadline);ForEach(0..<TradeStore.ids.count,id:\.self){i in Link(TradeStore.names[i]+" API 설정 열기",destination:URL(string:TradeStore.links[i])!).frame(minHeight:44)}}.modifier(CareCard())}
}
