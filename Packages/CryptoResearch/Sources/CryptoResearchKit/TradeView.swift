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
 @Published var access:TradeConnectionAccess?
 @Published var verifiedAt:Date?
 @Published var healthSummary:String?
 var verifiedRoot="",verifiedToken=""
 var canSubmit:Bool{access?.canTrade==true && savedMatches() && verifiedRoot==savedBase && verifiedToken==savedToken}
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
 func invalidateAccess(){access=nil;verifiedAt=nil;verifiedRoot="";verifiedToken="";healthSummary=nil}
 func save(){guard !busy else{return};do{let u=try TradeAPI.canonical(address).absoluteString.trimmingCharacters(in:CharacterSet(charactersIn:"/"));let secret=try TradeAPI.validateToken(token);try TradeVault.save(secret);UserDefaults.standard.set(u,forKey:"trade.url");savedBase=u;savedToken=secret;address=u;token=secret;review=nil;invalidateAccess();message="저장했습니다. 연결 및 권한 확인을 눌러 서버 역할을 확인하세요."}catch{message=(error as? StrategyError)?.localizedDescription ?? "기기 보안 저장소를 확인하세요."}}
 func forget(){guard !busy else{return};TradeVault.clear();token="";savedToken="";review=nil;invalidateAccess();message="기기 토큰만 삭제했습니다. 거래소 주문은 취소되지 않습니다."}
 func probe(){
  guard !busy else{return}
  guard let root=try? TradeAPI.canonical(address).absoluteString else{message="먼저 HTTPS 서버 주소를 입력하세요.";return}
  busy=true;generation+=1;let gen=generation;healthSummary=nil;message="토큰 없이 서버 응답 확인 중"
  task=Task{defer{if gen==generation{busy=false;task=nil}};do{try await TradeAPI.probe(base:root);guard gen==generation,!Task.isCancelled,(try? TradeAPI.canonical(address).absoluteString)==root else{return};healthSummary="서버 응답 정상 · /health 확인";message="이 상태 확인은 토큰 인증·계좌 연결 검사와 별개입니다. 필요한 경우 연결 및 권한 확인을 진행하세요."}catch{guard gen==generation,!Task.isCancelled else{return};message=(error as? TradeHTTPFailure)?.localizedDescription ?? (error as? StrategyError)?.localizedDescription ?? TradeAPI.transportFailure("health")}}
 }
 func savedMatches()->Bool{guard let u=try? TradeAPI.canonical(address)else{return false};return savedBase==u.absoluteString.trimmingCharacters(in:CharacterSet(charactersIn:"/")) && savedToken==token && !savedToken.isEmpty}
 static func decimal(_ value:String)->Bool{value.range(of:"^(0|[1-9][0-9]{0,14})(\\.[0-9]{1,12})?$",options:.regularExpression) != nil && (Decimal(string:value,locale:Locale(identifier:"en_US_POSIX")) ?? 0)>0}
 func draft()throws->[String:Any]{guard Self.ids.contains(exchange),Self.bases.contains(base),["buy","sell"].contains(side),Self.decimal(amount),Self.decimal(price)else{throw StrategyError.invalid("수량·지정가를 양수로 입력하세요. 소수점은 . 을 사용합니다.")};return ["exchange":exchange,"base":base,"side":side,"amount":amount,"price":price,"draft_id":UUID().uuidString.replacingOccurrences(of:"-",with:"").lowercased()]}
 func preview(){do{call("v1/preview",try draft(),"preview",key)}catch{message=error.localizedDescription}}
 func submit(){guard let id=review?["review_id"] as? String,reviewKey==key else{message="입력 변경 시 다시 주문 검토가 필요합니다.";return};review=nil;call("v1/submit",["review_id":id,"confirmed":true],"submit",key)}
 func status(){guard !last.isEmpty else{message="확인할 주문 ID가 없습니다.";return};call("v1/order/"+last,nil,"status","")}
 func cancelOrder(){guard !last.isEmpty else{return};call("v1/cancel",["review_id":last,"confirmed":true],"cancel","")}
 func cancel(){generation+=1;task?.cancel();task=nil;busy=false;review=nil}
 func call(_ path:String,_ body:[String:Any]?=nil,_ kind:String="capabilities",_ input:String=""){
  guard !busy else{return};guard savedMatches()else{message="먼저 현재 주소와 서버 토큰을 저장하세요.";return};if ["v1/preview","v1/submit","v1/cancel"].contains(path) && !canSubmit{message="제어 토큰과 서버 실주문 활성 상태를 연결 및 권한 확인에서 먼저 확인하세요.";return};if kind=="capabilities"{invalidateAccess()};busy=true;generation+=1;let gen=generation,root=savedBase,secret=savedToken;message=kind=="submit" ? "실제 제출 요청 중 · 결과 불명 시 주문 상태를 확인하세요.":"요청 중 · 이전 표시가 최신 상태가 아닐 수 있습니다."
  task=Task{do{let data=try await TradeAPI.request(base:root,token:secret,path:path,body:body);guard gen==generation,!Task.isCancelled else{return};busy=false;guard savedMatches(),root==savedBase,secret==savedToken else{return};guard input.isEmpty || input==key else{message="입력이 변경돼 이전 응답을 적용하지 않았습니다. 제출했다면 마지막 주문 상태를 확인하세요.";return};guard let j=try JSONSerialization.jsonObject(with:data) as? [String:Any]else{throw StrategyError.invalid("응답 형식 확인 필요")};try render(j,kind,input)}catch{guard gen==generation,!Task.isCancelled else{return};busy=false;if let failure=error as? TradeHTTPFailure,[401,403].contains(failure.status){invalidateAccess()};message="요청 실패 · "+((error as? TradeHTTPFailure)?.localizedDescription ?? (error as? StrategyError)?.localizedDescription ?? TradeAPI.transportFailure(path))}}
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
  else if kind=="capabilities"{invalidateAccess();let value=try TradeConnectionAccess(j);access=value;verifiedRoot=savedBase;verifiedToken=savedToken;verifiedAt=Date();message=value.summary+"\n"+(value.canTrade ? "실제 주문 검토가 가능합니다. 제출·취소는 매번 사용자 확인이 필요합니다.":"조회 연결은 사용 가능하며 실제 주문 검토는 비활성입니다.")}
  else{message="주문 상태 \(j["state"] ?? "—")\n거래소 주문 ID \(j["exchange_order_id"] ?? "—")\n취소 요청 \(j["cancel_state"] ?? "—")";if let o=j["order"] as? [String:Any]{message+="\n체결 상태 \(o["status"] ?? "—") · 체결 \(o["filled"] ?? "—") · 잔여 \(o["remaining"] ?? "—")"}else{message+="\n결과 불명/대기 상태에서는 새 주문을 만들지 마세요."}}
 }
 func selectShared(_ row:[String:Any]){guard !busy,savedMatches(),sharedRoot==savedBase,sharedToken==savedToken,let rid=row["review_id"] as? String,rid.range(of:"^[0-9a-f]{32}$",options:.regularExpression) != nil else{return};let summary="\(row["exchange"] ?? "—") · \(row["symbol"] ?? "—") · \(row["side"] ?? "—")\n수량 \(row["amount"] ?? "—") · 지정가 \(row["price"] ?? "—")";UserDefaults.standard.set(rid,forKey:"trade.last:"+savedBase);UserDefaults.standard.set(summary,forKey:"trade.last-description:"+savedBase);review=nil;message="공통 주문 선택 · 상태 확인/취소 요청 가능\n"+summary+"\n검토 ID "+rid}
 var reviewText:String{guard let j=review else{return "검토된 주문이 없습니다."};return "\(j["exchange"] ?? "—") · \(j["symbol"] ?? "—") · \(j["side"] ?? "—")\n수량 \(j["amount"] ?? "—") · 지정가 \(j["price"] ?? "—")\n주문금액 \(j["notional"] ?? "—") \(j["quote_currency"] ?? "—")\n수수료 별도 · 검토 유효시간30초"}
}
struct TradeView:View {
 @StateObject private var store=TradeStore()
 @State private var confirmSubmit=false
 @State private var confirmCancel=false
 var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){connection;strategyLink;ticket;if store.busy { loadingCard };performanceCard;sharedOrders;guide}.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("통합 거래소").scrollDismissesKeyboard(.interactively).onDisappear{store.cancel()}.onChange(of:store.key){_ in store.review=nil;store.performanceSummary=nil;store.shared=[]}.onChange(of:store.address){_ in store.invalidateAccess();store.review=nil;store.shared=[];store.performanceSummary=nil}.onChange(of:store.token){_ in store.invalidateAccess();store.review=nil;store.shared=[];store.performanceSummary=nil}.confirmationDialog("실제 지정가 주문을 제출할까요?",isPresented:$confirmSubmit,titleVisibility:.visible){Button("실제 주문 제출",role:.destructive){store.submit()};Button("취소",role:.cancel){}}message:{Text(store.reviewText+"\n모의 주문이 아닙니다.")}.alert("거래소에 취소를 요청할까요?",isPresented:$confirmCancel){Button("취소 요청",role:.destructive){store.cancelOrder()};Button("돌아가기",role:.cancel){}}message:{Text(store.lastDescription+"\n이미 체결된 수량은 취소되지 않습니다. 취소 후 주문 상태를 확인하세요.")}}
 var connection:some View{
  VStack(alignment:.leading,spacing:12){
   Text("시세 · 계좌 · 수동 실주문").font(.title2.bold())
   Text("거래소 API 키는 Ubuntu 실행 서버에 보관합니다. 앱에는 서버 접근 토큰만 저장하며 모의 전략은 실제 주문을 만들지 않습니다.").font(.caption)
   Text("서버 주소").font(.headline)
   TextField("https://기기.개인네트워크.ts.net:8443",text:$store.address).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).accessibilityIdentifier("trade-server-address")
   Text("서버 토큰 · 거래소 API 키가 아닙니다").font(.headline)
   SecureField("서버 토큰 값만 입력",text:$store.token).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).accessibilityIdentifier("trade-server-token")
   Text("TRADE_READ_TOKEN= / TRADE_CONTROL_TOKEN= / Bearer 접두사를 제외한 값만 입력하세요. 저장을 누르면 기존 기기 보안 저장소에 보관합니다.").font(.caption).foregroundStyle(.secondary)
   Button("거래 서버 설정 저장"){store.save()}.disabled(store.busy).frame(minHeight:44)
   Button("서버 응답 확인 · 토큰 불필요"){store.probe()}.disabled(store.busy).frame(minHeight:44).accessibilityIdentifier("trade-health-check")
   Button("연결 및 권한 확인"){store.call("v1/capabilities")}.disabled(store.busy || !store.savedMatches()).frame(minHeight:44)
   Text(store.access?.summary ?? "권한 미확인 · 연결 및 권한 확인을 진행하세요.").font(.subheadline).accessibilityIdentifier("trade-access-summary")
   if let time=store.verifiedAt{Text("마지막 권한 확인 "+time.formatted(date:.abbreviated,time:.standard)).font(.caption).foregroundStyle(.secondary)}
   if let health=store.healthSummary{Text(health).font(.caption)}
   Button("기기의 거래 토큰 삭제"){store.forget()}.disabled(store.busy).frame(minHeight:44)
   Text(store.message).font(.caption).textSelection(.enabled).accessibilityIdentifier("trade-connection-message")
   if store.busy{ProgressView()}
  }.modifier(CareCard())
 }
 var strategyLink: some View {
  NavigationLink("현물 전략 계산기") {
   SpotScenarioView(symbol: store.base, currency: store.exchange == "bithumb" ? "KRW" : "USDT")
  }.frame(minHeight:44)
 }
 var loadingCard: some View {
  VStack(alignment:.leading,spacing:10) {
   ForEach([160.0, 240.0, 120.0],id:\.self) { width in
    RoundedRectangle(cornerRadius:7).fill(Color.secondary.opacity(0.18))
     .frame(maxWidth:width).frame(height:14)
   }
  }.modifier(CareCard()).accessibilityHidden(true)
 }
 var ticket:some View{VStack(alignment:.leading,spacing:12){Picker("거래소 선택",selection:$store.exchange){ForEach(Array(TradeStore.ids.enumerated()),id:\.offset){i in Text(TradeStore.names[i.offset]).tag(i.element)}};Picker("거래 종목",selection:$store.base){ForEach(TradeStore.bases,id:\.self){Text($0).tag($0)}};Picker("실주문 방향",selection:$store.side){Text("매수").tag("buy");Text("매도").tag("sell")}.pickerStyle(.segmented);TextField("수량 (기준 코인)",text:$store.amount).keyboardType(.decimalPad).textFieldStyle(.roundedBorder);TextField("지정가 (빗썸 KRW · 나머지 USDT)",text:$store.price).keyboardType(.decimalPad).textFieldStyle(.roundedBorder);Button("선택 거래소 시세 조회"){store.call("v1/quote/"+store.exchange+"/"+store.base,nil,"quote",store.key)}.frame(minHeight:44);Button("선택 거래소 계좌 조회"){store.call("v1/balances/"+store.exchange,nil,"balance",store.key)}.frame(minHeight:44);Button("주문 내용 검토"){store.preview()}.disabled(store.busy || !store.canSubmit).frame(minHeight:44);Text(store.reviewText).font(.caption).textSelection(.enabled);Button("검토한 실제 주문 제출"){confirmSubmit=true}.disabled(store.review==nil || store.busy || !store.canSubmit).frame(minHeight:48).modifier(CareControl());Button("마지막 주문 상태 확인"){store.status()}.frame(minHeight:44);Button("마지막 주문 취소 요청"){confirmCancel=true}.disabled(store.last.isEmpty || store.busy || !store.canSubmit).frame(minHeight:44)}.modifier(CareCard())}
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
 @State private var attentionOnly = false
 private var filteredOrders: [[String: Any]] {
  guard attentionOnly else { return store.shared }
  return store.shared.filter { row in
   ["UNKNOWN","PENDING"].contains(row["state"] as? String ?? "") ||
   ["UNKNOWN","PENDING"].contains(row["cancel_state"] as? String ?? "")
  }
 }
 var sharedOrders:some View{VStack(alignment:.leading,spacing:12){Text("모바일·윈도우 공통 주문").font(.title2.bold());Text("선택 계좌의 최근50개 서버 검토 기록입니다. 제출 대기/미제출 기록도 포함합니다. 선택 후 기존 마지막 주문 상태/취소 버튼을 사용하세요.").font(.caption);Button("공통 주문 내역 조회"){store.call("v1/orders/"+store.exchange,nil,"history",store.key)}.disabled(store.busy).frame(minHeight:44);Toggle("확인이 필요한 주문만 보기",isOn:$attentionOnly);Text("표시 \(filteredOrders.count) / \(store.shared.count)건").font(.caption);ForEach(Array(filteredOrders.enumerated()),id:\.offset){entry in Button{store.selectShared(entry.element)}label:{VStack(alignment:.leading){Text("\(entry.element["symbol"] ?? "—") · \(entry.element["side"] ?? "—") · \(entry.element["state"] ?? "—")");Text("수량 \(entry.element["amount"] ?? "—") · 지정가 \(entry.element["price"] ?? "—")").font(.caption);Text("\(entry.element["review_id"] ?? "—")").font(.caption2)}}.disabled(store.busy || store.sharedRoot != store.savedBase || store.sharedToken != store.savedToken)}}.modifier(CareCard())}
 var guide:some View{VStack(alignment:.leading,spacing:12){Text("API 설정 가이드").font(.title2.bold());Text("1. 거래소 API 관리에서 조회·현물 주문 권한과 서버 공인 IP를 설정합니다. 출금 권한은 사용하지 않습니다.\n2. Key·Secret은 서버 .env에 입력합니다. Bitget은 Passphrase도 필요합니다.\n3. 서버 주문 한도와 실주문 활성화를 설정한 뒤 HTTPS 주소·서버 토큰을 위에 저장합니다.\n4. 시세·계좌 확인 → 수량·지정가 검토 → 실제 제출 확인 순서로 사용합니다. 결과가 불명확하면 새 주문을 만들지 말고 상태를 확인하세요.").font(.subheadline);ForEach(0..<TradeStore.ids.count,id:\.self){i in Link(TradeStore.names[i]+" API 설정 열기",destination:URL(string:TradeStore.links[i])!).frame(minHeight:44)}}.modifier(CareCard())}
}

private struct SpotScenarioView: View {
 let symbol: String
 let currency: String
 @State private var fields = ["", "", "", "", "0"]
 private let labels = ["진입가", "손절가", "목표가", "최대 가정 손실", "편도 수수료 %"]
 var body: some View {
  Form {
   Section("\(symbol) · \(currency)") {
    ForEach(labels.indices,id:\.self) { index in
     TextField(labels[index],text:$fields[index]).keyboardType(.decimalPad)
    }
   }
   Section("빠른 입력") {
    Button("가상 예제 채우기") { fields = ["100", "95", "110", "25", "0.1"] }
    Button("입력 초기화") { fields = ["", "", "", "", "0"] }
   }
   Section("시나리오") {
    if let outcomes {
     ForEach(outcomes.indices,id:\.self) { index in
      LabeledContent(outcomes[index].label) {
       Text(outcomes[index].value).monospacedDigit().textSelection(.enabled)
      }
     }
    } else {
     Text("손절가 < 진입가 < 목표가, 양수 손실 한도, 수수료 0~10%를 입력하세요.")
      .foregroundStyle(.secondary)
    }
    Text("가정 계산입니다. 슬리피지·잔고·최소 주문 단위는 별도입니다.").font(.caption)
   }
  }.navigationTitle("현물 매수 전략")
 }
 private var outcomes: [(label: String, value: String)]? {
  let v = fields.map { field -> Double in
   let raw = field.trimmingCharacters(in:.whitespacesAndNewlines)
   guard raw.range(of:#"\A[0-9]{1,15}(?:[.,][0-9]{1,12})?\z"#,
                   options:.regularExpression) != nil else { return .nan }
   return Double(raw.replacingOccurrences(of:",",with:".")) ?? .nan
  }
  let entry = v[0], stop = v[1], target = v[2], budget = v[3], fee = v[4] / 100
  guard v.allSatisfy({ $0.isFinite }), stop > 0, entry > stop, target > entry,
        budget > 0, fee >= 0, fee <= 0.1 else {
   return nil
  }
  let loss = entry - stop + fee * (entry + stop)
  let quantity = budget / loss
  let cost = quantity * entry * (1 + fee)
  let targetGain = quantity * (target - entry - fee * (entry + target))
  let breakEven = entry * (1 + fee) / (1 - fee)
  let ratio = targetGain / budget
  guard quantity > 0, quantity.isFinite, cost.isFinite, ratio.isFinite, targetGain.isFinite, breakEven.isFinite else { return nil }
  let format = FloatingPointFormatStyle<Double>.number.precision(.significantDigits(1...8))
  return [
   ("가정 수량", "\(quantity.formatted(format)) \(symbol)"),
   ("필요 자금", "\(cost.formatted(format)) \(currency)"),
   ("목표 도달 시 손익", "\(targetGain.formatted(format)) \(currency)"),
   ("손익분기 매도가", "\(breakEven.formatted(format)) \(currency)"),
   ("수수료 반영 손익비", "\(ratio.formatted(format))배"),
  ]
 }
}
