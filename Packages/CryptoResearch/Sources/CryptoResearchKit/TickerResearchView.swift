import SwiftUI
import Charts
import UniformTypeIdentifiers

@MainActor final class TickerResearchStore: ObservableObject {
    @Published private(set) var report: ResearchReport?
    @Published private(set) var busy = false
    @Published var message = "티커를 입력하고 분석을 시작하세요. 자동 주문과 연결되지 않습니다."
    private var generation = UUID()
    private var task: Task<Void,Never>?
    private var lastFetch = -Double.infinity
    func cancel(clear: Bool = false) { if busy { message = "자료 확인을 중단했습니다. 입력은 유지됩니다." };generation = UUID();task?.cancel();task = nil;busy = false;if clear { report = nil } }
    func load(_ ticker: ResearchTicker) {
        guard ProcessInfo.processInfo.systemUptime-lastFetch >= 60 else { message = "수동 조회는 60초 간격입니다. 공급자 이용 한도를 확인하세요.";return }
        lastFetch = ProcessInfo.processInfo.systemUptime;cancel(clear:true);busy = true;let token = generation
        message = "가격·지표·뉴스·커뮤니티를 확인하고 있어요."
        let key = TickerResearchKey.read()
        task = Task {
            do { let result = try await TickerResearchService().analyze(ticker,key:key);guard token == generation,!Task.isCancelled else { return };report = result;busy = false;message = "조회 완료 · 일부 자료가 없으면 해당 항목을 제외합니다." }
            catch { guard token == generation,!Task.isCancelled else { return };busy = false;message = (error as? ResearchFailure)?.localizedDescription ?? "분석을 완료하지 못했습니다." }
        }
    }
    func loadFile(_ url: URL,ticker: ResearchTicker,communityOnly: Bool) {
        let existing = report
        cancel(clear:!communityOnly);busy = true;let token = generation
        task = Task {
            do {
                let data = try await Task.detached(priority:.userInitiated) {
                    let access = url.startAccessingSecurityScopedResource();defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let handle = try FileHandle(forReadingFrom:url);defer { try? handle.close() }
                    let data = try handle.read(upToCount:2*1024*1024+1) ?? Data()
                    guard data.count <= 2*1024*1024 else { throw ResearchFailure.oversized };return data
                }.value
                let now = Date(),result: ResearchReport
                if communityOnly {
                    struct Input: Decodable { let community_schema_version: Int,asset: ResearchAsset,symbol: String,synthetic: Bool,posts: [ResearchHeadline] }
                    let decoder = JSONDecoder();decoder.dateDecodingStrategy = .iso8601
                    let input = try decoder.decode(Input.self,from:data)
                    guard input.community_schema_version == 2,input.asset == ticker.asset,input.symbol == ticker.symbol,input.posts.count <= 1000,let existing,existing.ticker == ticker else { throw ResearchFailure.invalidData }
                    result = try TickerResearchMath.report(ticker:ticker,bars:existing.bars,news:existing.news.items,community:input.posts,now:now,source:existing.source,synthetic:existing.synthetic || input.synthetic,imported:true,notices:existing.notices+["커뮤니티: 사용자 추가 파일 · 티커 표기는 파일 작성자의 주장이며 출처 미검증"])
                } else { result = try TickerResearchParsing.imported(data,ticker:ticker,now:now) }
                guard token == generation,!Task.isCancelled else { return };report = result;busy = false;message = "파일 분석 완료 · 원본 앱·서버의 자료는 변경하지 않았습니다."
            } catch { guard token == generation,!Task.isCancelled else { return };busy = false;message = (error as? ResearchFailure)?.localizedDescription ?? "연구 JSON의 스키마·티커·날짜를 확인하세요." }
        }
    }
    func sample(_ ticker: ResearchTicker) {
        cancel(clear:true)
        let now = Date(),end = now.addingTimeInterval(-86400)
        let bars = (0..<90).map { i in
            let c = 100+Double(i)*0.3+sin(Double(i)/5)*2
            return ResearchBar(time:end.addingTimeInterval(Double(i-89)*86400),open:c-0.2,high:c+1,low:c-1,close:c,volume:i == 89 ? 2400:1000)
        }
        report = try? TickerResearchMath.report(ticker:ticker,bars:bars,news:[],community:[],now:now,source:"합성 예제 · 실제 가격·기사·게시글 아님",synthetic:true)
        message = "합성 데이터로 화면만 확인합니다. 실제 종목 분석은 아닙니다."
    }
    func exportData() throws -> Data {
        guard let r = report else { throw ResearchFailure.invalidData }
        struct Bar: Encodable { let time: Date,open: Double,high: Double,low: Double,close: Double,volume: Double;let closed = true }
        struct Output: Encodable {
            let research_schema_version = 1
            let asset: ResearchAsset,symbol: String,synthetic: Bool
            let bars: [Bar],news: [ResearchHeadline],community: [ResearchHeadline]
        }
        let output = Output(asset:r.ticker.asset,symbol:r.ticker.symbol,synthetic:r.synthetic,bars:r.bars.map { Bar(time:$0.time,open:$0.open,high:$0.high,low:$0.low,close:$0.close,volume:$0.volume) },news:r.news.items,community:r.community.items)
        let encoder = JSONEncoder();encoder.dateEncodingStrategy = .iso8601;encoder.outputFormatting = [.prettyPrinted,.sortedKeys];return try encoder.encode(output)
    }
}

public struct TickerResearchView: View {
    @EnvironmentObject private var session: NativeInvestmentSession
    public init() {}
    public var body: some View { TickerResearchContent(session:session,store:session.research) }
}

private struct TickerResearchContent: View {
    @ObservedObject var session: NativeInvestmentSession
    @ObservedObject var store: TickerResearchStore
    @AppStorage("native-research-live") private var liveStatus = false
    @State private var showComparison = false
    @State private var showKey = false
    @State private var keyAvailable = !TickerResearchKey.read().isEmpty
    @State private var importing = false
    @State private var communityOnly = false
    @State private var exporting = false
    @State private var document = JSONDocument(data:Data())
    private var asset: ResearchAsset { session.researchAsset }
    private var ticker: String { session.researchTicker }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                controls
                if let r = store.report {
                    Button("이 일봉으로 전략 비교") { do { try session.prepareComparison();showComparison = true } catch { store.message = error.localizedDescription } }.frame(minHeight:44).accessibilityIdentifier("ticker-to-comparison")
                    overview(r);priceChart(r);if let m = r.metrics { indicators(m) };evidence(r);headlines("뉴스",r.news,synthetic:r.synthetic);headlines("커뮤니티",r.community,synthetic:r.synthetic) }
            }.padding(20)
        }.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("티커 종합 분석").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented:$showComparison) { StrategyComparisonView(store:session.comparison,market:session.market) }
        .onChange(of:ticker) { _ in store.cancel(clear:true) }
        .onChange(of:asset) { _ in store.cancel(clear:true) }
        .sheet(isPresented:$showKey,onDismiss:{ keyAvailable = !TickerResearchKey.read().isEmpty }) { ResearchDataKeyView() }
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json]) { result in
            switch result { case .success(let url): if let t = try? ResearchTicker(ticker,asset:asset) { store.loadFile(url,ticker:t,communityOnly:communityOnly) };case .failure:store.message = "파일을 열지 못했습니다." }
        }
        .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"ticker-research-snapshot") { result in if case .failure = result { store.message = "스냅샷을 저장하지 못했습니다." } }
    }
    private var controls: some View {
        VStack(alignment:.leading,spacing:14) {
            Text("가격과 이야기, 함께 살펴봐요").font(.title2.bold())
            Picker("자산",selection:$session.researchAsset) { Text("코인 · USDT").tag(ResearchAsset.crypto);Text("미국 주식 · USD").tag(ResearchAsset.stock) }.pickerStyle(.segmented)
            TextField(asset == .crypto ? "BTC 또는 ETHUSDT":"AAPL · MSFT · NVDA",text:$session.researchTicker).textInputAutocapitalization(.characters).autocorrectionDisabled().textFieldStyle(.roundedBorder).accessibilityIdentifier("ticker-symbol")
            Button { do { store.load(try ResearchTicker(ticker,asset:asset)) } catch { store.message = error.localizedDescription } } label: { Label("종합 분석",systemImage:"sparkle.magnifyingglass").frame(maxWidth:.infinity,minHeight:48) }.buttonStyle(.borderedProminent).disabled(store.busy).accessibilityIdentifier("ticker-analyze")
            if store.busy { ProgressView("자료 확인 중");Button("조회 중단") { store.cancel() }.frame(minHeight:44) }
            Text(store.message).font(.caption).foregroundStyle(.secondary)
            Toggle("잠금 화면에 자료 확인 진행 표시",isOn:$liveStatus).font(.subheadline)
            Button(keyAvailable ? "분석 데이터 연결 관리":"미국 주식·뉴스 데이터 연결") { showKey = true }.frame(minHeight:44)
            Button("연구 JSON 가져오기") { communityOnly = false;importing = true }.disabled(store.busy)
            Button("커뮤니티 표본 JSON 추가") { communityOnly = true;importing = true }.disabled(store.busy || store.report == nil)
            Button("분석 스냅샷 저장") { do { document = JSONDocument(data:try store.exportData());exporting = true } catch { store.message = "먼저 분석을 실행하세요." } }.disabled(store.report == nil || store.busy)
            Button("합성 예제로 화면 확인") { if let t = try? ResearchTicker(ticker,asset:asset) { store.sample(t) } }.disabled(store.busy).accessibilityIdentifier("ticker-sample")
            Text("확정 일봉 기준 · 수동 조회 60초 간격. 주식+뉴스는 공급자 API를 최대 2회 요청합니다. 실시간 호가·장중 틱 분석이 아닙니다.").font(.caption).foregroundStyle(.secondary)
        }.modifier(CareCard())
    }
    private func overview(_ r: ResearchReport) -> some View {
        VStack(alignment:.leading,spacing:12) {
            if r.synthetic { Label("합성 예제 · 실제 시장 자료 아님",systemImage:"testtube.2").font(.headline).foregroundStyle(.orange) }
            Text(r.ticker.label).font(.title.bold())
            if let price = r.bars.last { Text(price.close.formatted(.number.precision(.significantDigits(2...10)))+" "+(r.ticker.asset == .crypto ? "USDT":"USD")).font(.title.bold());Text("최근 확정 일봉 종가 · "+price.time.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary) }
            Text(r.direction).font(.title2.bold()).accessibilityIdentifier("ticker-direction")
            if let score = r.score { Text(String(format:"규칙 점수 %+.0f / ±100",score)).monospacedDigit() }
            Text("입력 충족도 \(r.coverage)% · 정확도·상승 확률이 아님").font(.subheadline)
            Text(r.source).font(.caption).foregroundStyle(.secondary)
            Text("수동 분석 스냅샷 · "+r.fetched.formatted(date:.abbreviated,time:.standard)).font(.caption).foregroundStyle(.secondary)
            Text("상관된 지표를 더한 연구용 규칙입니다. 가격 예측·매수/매도 권고·자동 주문 신호가 아닙니다.").font(.caption).foregroundStyle(.secondary)
        }.modifier(CareCard())
    }
    private func priceChart(_ r: ResearchReport) -> some View {
        VStack(alignment:.leading,spacing:12) {
            Text("최근 확정 일봉 흐름").font(.headline)
            if r.bars.isEmpty { Text("가격 자료 없음").foregroundStyle(.secondary) }
            else { Chart(Array(r.bars.suffix(90))) { bar in LineMark(x:.value("시각",bar.time),y:.value("종가",bar.close)).foregroundStyle(Color.careBlue) }.chartYScale(domain:.automatic(includesZero:false)).frame(height:180).accessibilityLabel("확정 일봉 종가 추이") }
        }.modifier(CareCard())
    }
    private func indicators(_ m: ResearchMetrics) -> some View {
        VStack(alignment:.leading,spacing:12) {
            Text("기술적 지표 · 거래량 · 가격").font(.headline)
            metric("SMA 20 / 50",String(format:"%.4g / %.4g",m.sma20,m.sma50))
            metric("RSI 14 · Wilder",String(format:"%.1f",m.rsi14))
            metric("MACD / 시그널 · 12·26·9",String(format:"%.4g / %.4g",m.macd,m.macdSignal))
            metric("ATR 14",String(format:"%.4g",m.atr14))
            metric("볼린저 20 · 2σ",String(format:"%.4g ~ %.4g",m.lowerBand,m.upperBand))
            metric("직전 일봉 대비",String(format:"%+.2f%%",m.changePercent))
            metric("시가 갭",String(format:"%+.2f%%",m.gapPercent))
            metric("거래량 / 직전 20일 평균",m.relativeVolume.map { String(format:"%.2f배",$0) } ?? "계산 불가")
            metric("거래량 z-score",m.volumeZ.map { String(format:"%+.2f",$0) } ?? "기준 분산 없음")
        }.modifier(CareCard())
    }
    private func metric(_ title: String,_ value: String) -> some View {
        VStack(alignment:.leading,spacing:3) { Text(title).font(.caption).foregroundStyle(.secondary);Text(value).font(.body.monospacedDigit()).textSelection(.enabled) }
    }
    private func evidence(_ r: ResearchReport) -> some View {
        VStack(alignment:.leading,spacing:12) {
            Text("근거와 특이점").font(.headline)
            ForEach(Array(r.reasons.enumerated()),id:\.offset) { _,text in Text("• "+text) }
            if r.anomalies.isEmpty { Text("검출된 규칙상 특이점 없음 · 모든 위험을 확인했다는 뜻은 아닙니다.").font(.caption).foregroundStyle(.secondary) }
            ForEach(Array(r.anomalies.enumerated()),id:\.offset) { _,text in Label(text,systemImage:"exclamationmark.circle").foregroundStyle(.orange) }
            Divider()
            ForEach(Array(r.notices.enumerated()),id:\.offset) { _,text in Text(text).font(.caption).foregroundStyle(.secondary) }
            Text("가중치: 기술 60 · 최근 가격 변화 15 · 거래량 15 · 뉴스 5 · 커뮤니티 5. 없는 입력의 가중치를 다른 항목에 재분배하지 않습니다. 제목의 단순 표현 사전은 반어·부정·맥락을 오독할 수 있습니다.").font(.caption).foregroundStyle(.secondary)
        }.modifier(CareCard())
    }
    private func headlines(_ title: String,_ summary: ResearchTextSummary,synthetic: Bool) -> some View {
        VStack(alignment:.leading,spacing:12) {
            Text(title+" · 분석 시각 기준 7일 제목 \(summary.items.count)개").font(.headline)
            Text("상승 표현 \(summary.positive) · 하락 표현 \(summary.negative) · 혼합 \(summary.mixed)").font(.caption).foregroundStyle(.secondary)
            if summary.items.isEmpty { Text("유효 표본 없음 · 중립 여론으로 해석하지 않습니다.").foregroundStyle(.secondary) }
            ForEach(Array(summary.items.prefix(15))) { item in
                VStack(alignment:.leading,spacing:5) {
                    if !synthetic,let url = URL(string:item.url) { Link(item.title,destination:url) } else { Text(item.title) }
                    Text(item.source+" · "+item.time.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.modifier(CareCard())
    }
}

private struct ResearchDataKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var message = "분석 데이터 전용 키입니다. 거래소 주문 키와 분리됩니다."
    var body: some View {
        NavigationStack {
            Form {
                Section("Alpha Vantage · 미국 주식과 뉴스") {
                    SecureField("데이터 API 키",text:$key).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text(message).font(.caption)
                    Button("기기에 안전하게 저장") { do { try TickerResearchKey.save(key);key = "";dismiss() } catch { message = "키 형식 또는 기기 저장 상태를 확인하세요." } }.disabled(key.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    Button("이 데이터 연결 해제",role:.destructive) { do { try TickerResearchKey.save("");dismiss() } catch { message = "연결 해제를 완료하지 못했습니다." } }
                }
                Section("연결 안내") {
                    Link("데이터 키 발급·이용 한도",destination:URL(string:"https://www.alphavantage.co/support/#api-key")!)
                    Link("가격·뉴스 API 공식 문서",destination:URL(string:"https://www.alphavantage.co/documentation/")!)
                    Text("주식·뉴스 지원 범위와 요청 한도는 공급자 요금제에 따릅니다. 키는 이 기기의 Keychain에 보관하며, 조회 시 Alpha Vantage에만 전송합니다. 채팅·연구 JSON·주문 서버에는 넣지 않습니다.").font(.caption)
                }
            }.navigationTitle("분석 데이터 연결").toolbar { ToolbarItem(placement:.confirmationAction) { Button("닫기") { dismiss() } } }
        }
    }
}
