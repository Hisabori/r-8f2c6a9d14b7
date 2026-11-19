import SwiftUI
import Foundation

struct ObservedLiquidation: Identifiable {
    let id: Int, time: Int64, side: String
    let price: Double, size: Double
}
enum PublicMarketParsing {
    static func fetch(_ session:URLSession,_ url:String,limit:Int)async throws->Data {
        let (bytes,response)=try await session.bytes(from:URL(string:url)!)
        guard (response as? HTTPURLResponse)?.statusCode==200 else{throw StrategyError.invalid("공개 제공자 응답 오류")}
        var data=Data();for try await byte in bytes{try Task.checkCancellation();guard data.count<limit else{throw StrategyError.invalid("공개 응답 크기 초과")};data.append(byte)};return data
    }
    static func events(_ root: [String:Any], symbol: String, now: Int64) throws -> [ObservedLiquidation] {
        guard root["topic"] as? String == "allLiquidation." + symbol else { return [] }
        guard let rows = root["data"] as? [[String:Any]], rows.count <= 1000 else { throw StrategyError.invalid("청산 응답 형식 오류") }
        return try rows.enumerated().map { index, row in
            guard row["s"] as? String == symbol, let side = row["S"] as? String, ["Buy","Sell"].contains(side),
                  let time = row["T"] as? Int64, time >= now-300_000, time <= now+10_000,
                  let p = row["p"] as? String, let price = Double(p), price.isFinite, price > 0, price < 1e15,
                  let v = row["v"] as? String, let size = Double(v), size.isFinite, size > 0, size < 1e15 else { throw StrategyError.invalid("청산 수치 확인 필요") }
            return ObservedLiquidation(id:index,time:time,side:side,price:price,size:size)
        }
    }
}
@MainActor final class PublicMarketResearchStore: ObservableObject {
    @Published var message = "버튼을 눌러 공개 실서버 자료를 조회하세요. 서버 토큰·거래소 키가 필요하지 않습니다."
    @Published var events: [ObservedLiquidation] = []
    @Published var chain: [String] = []
    @Published var busy = false
    private var job: Task<Void,Never>?, deadline: Task<Void,Never>?
    private var socket: URLSessionWebSocketTask?, session: URLSession?
    private var revision = 0
    func cancel() { revision += 1; job?.cancel(); deadline?.cancel(); socket?.cancel(with:.goingAway,reason:nil); session?.invalidateAndCancel(); socket=nil;session=nil;job=nil;deadline=nil;busy=false }
    func clear() { cancel();events=[];chain=[];message="조건 변경 · 다시 조회하세요." }
    func observe(_ symbol:String) {
        guard ["BTCUSDT","ETHUSDT"].contains(symbol) else { return };clear();let token=revision;busy=true;message="Bybit 공개 청산 관측 중 · 15초 · 현재 관측 구간만 표시"
        let config=URLSessionConfiguration.ephemeral;config.timeoutIntervalForRequest=10;config.timeoutIntervalForResource=25
        let transport=URLSession(configuration:config,delegate:CommunityRedirectGuard(),delegateQueue:nil);session=transport
        let ws=transport.webSocketTask(with:URL(string:"wss://stream.bybit.com/v5/public/linear")!);socket=ws;ws.maximumMessageSize=262144;ws.resume()
        let started=Date();var acknowledged=false;var timedOut=false
        deadline=Task { try? await Task.sleep(nanoseconds:15_000_000_000);guard !Task.isCancelled,token==revision else{return};timedOut=true;ws.cancel(with:.goingAway,reason:nil) }
        job=Task {
            defer { if token==revision { deadline?.cancel();socket=nil;transport.invalidateAndCancel();session=nil;busy=false } }
            do {
                let subscription=try JSONSerialization.data(withJSONObject:["op":"subscribe","args":["allLiquidation."+symbol]])
                try await ws.send(.data(subscription))
                while !Task.isCancelled,token==revision {
                    let frame=try await ws.receive();let bytes:Data
                    switch frame {case .data(let value):bytes=value;case .string(let text):bytes=Data(text.utf8);@unknown default:throw StrategyError.invalid("응답 형식 오류")}
                    guard bytes.count<=262144,let root=try JSONSerialization.jsonObject(with:bytes) as? [String:Any] else {throw StrategyError.invalid("응답 크기/형식 오류")}
                    if root["op"] as? String == "subscribe" {guard root["success"] as? Bool == true else{throw StrategyError.invalid("구독 거부")};acknowledged=true;continue}
                    guard acknowledged else {throw StrategyError.invalid("구독 확인 전 자료")}
                    let rows=try PublicMarketParsing.events(root,symbol:symbol,now:Int64(Date().timeIntervalSince1970*1000))
                    for row in rows {if events.count>=500 {message="500건 상한 · 일부 관측만 표시";return};events.append(ObservedLiquidation(id:events.count,time:row.time,side:row.side,price:row.price,size:row.size))}
                }
            } catch {
                guard token==revision,!Task.isCancelled else{return}
                if timedOut && acknowledged {message="Bybit · \(symbol) · \(started.formatted(date:.omitted,time:.standard))부터 15초 관측 · \(events.count)건 수신"}
                else {events=[];message="연결·구독 실패 · 이전 수치는 지웠습니다. 자동 재시도하지 않습니다."}
            }
        }
    }
    func onchain() {
        clear();let token=revision;busy=true;message="Bitcoin 네트워크 조회 중"
        job=Task {
            let config=URLSessionConfiguration.ephemeral;config.timeoutIntervalForRequest=12;config.timeoutIntervalForResource=20
            let transport=URLSession(configuration:config,delegate:CommunityRedirectGuard(),delegateQueue:nil);session=transport
            defer {transport.invalidateAndCancel();if token==revision {session=nil;busy=false}}
            do {
                let heightData=try await PublicMarketParsing.fetch(transport,"https://mempool.space/api/blocks/tip/height",limit:100)
                let feesData=try await PublicMarketParsing.fetch(transport,"https://mempool.space/api/v1/fees/recommended",limit:16384)
                guard heightData.count<100,feesData.count<16384,
                      let heightText=String(data:heightData,encoding:.utf8),let height=Int(heightText.trimmingCharacters(in:.whitespacesAndNewlines)),height>0,height<100000000,
                      let fees=try JSONSerialization.jsonObject(with:feesData) as? [String:Any] else {throw StrategyError.invalid("네트워크 응답 확인 필요")}
                var values=["Bitcoin 블록 높이 \(height)"]
                for (key,label) in [("fastestFee","우선"),("halfHourFee","약30분 목표"),("hourFee","약1시간 목표"),("economyFee","경제적"),("minimumFee","최소")] {
                    guard let number=fees[key] as? NSNumber,number.doubleValue.isFinite,(0...1000000).contains(number.doubleValue) else{throw StrategyError.invalid("수수료 형식 오류")};values.append("\(label): \(number) sat/vB")
                }
                guard token==revision,!Task.isCancelled else{return};chain=values;message="mempool.space · 앱 수신 "+Date().formatted(date:.abbreviated,time:.standard)
            }catch{guard token==revision,!Task.isCancelled else{return};chain=[];message="온체인 조회 실패 · 이전 수치를 지웠습니다."}
        }
    }
}
public struct PublicMarketResearchView:View {
    @StateObject private var store=PublicMarketResearchStore()
    @State private var symbol="BTCUSDT"
    @Environment(\.scenePhase) private var phase
    public init(){}
    public var body:some View {ScrollView{VStack(alignment:.leading,spacing:18){
        Text("청산과 네트워크, 실제 공개 자료로").font(.title2.bold())
        Text("실제 발생한 Bybit 청산 관측입니다. 미래 청산 예상맵·전체 시장 통계가 아닙니다. 가격은 파산가격이며 체결가격과 다릅니다.").font(.caption).foregroundStyle(.secondary)
        Picker("청산 관측 종목",selection:$symbol){Text("BTCUSDT").tag("BTCUSDT");Text("ETHUSDT").tag("ETHUSDT")}.pickerStyle(.segmented).disabled(store.busy)
        Button("Bybit 실제 청산 · 15초"){store.observe(symbol)}.disabled(store.busy)
        Button("BTC 온체인 조회"){store.onchain()}.disabled(store.busy)
        if store.busy {ProgressView();Button("중지"){store.clear()}}
        Text(store.message).font(.subheadline).modifier(CareCard())
        ForEach(store.chain,id:\.self){Text($0).font(.headline)}
        if !store.chain.isEmpty {Text("권장 비용·처리시간은 보장되지 않습니다. 지갑·거래소 입출금·고래 흐름은 제공하지 않습니다.").font(.caption)}
        if !store.busy && store.events.isEmpty && store.chain.isEmpty {Text("수신된 이벤트가 없다고 전체 시장의 청산이 0건인 것은 아닙니다.").font(.caption)}
        ForEach(Array(store.events.suffix(100).reversed())){event in VStack(alignment:.leading,spacing:6){Text(event.side=="Buy" ? "롱 청산":"숏 청산").font(.headline);Text("파산가격 \(event.price, specifier:"%.2f") USDT · 수량 \(event.size, specifier:"%.6f")");Text(Date(timeIntervalSince1970:Double(event.time)/1000).formatted(date:.omitted,time:.standard)).font(.caption)}.modifier(CareCard())}
        Text("최근 상세100건 · 최대500건 수신 · 자동 주문/재연결 없음").font(.caption).foregroundStyle(.secondary)
    }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("청산 · 온체인").onChange(of:symbol){_ in store.clear()}.onDisappear{store.clear()}.onChange(of:phase){if $0 == .background {store.clear()}}}
}
