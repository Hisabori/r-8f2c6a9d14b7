import SwiftUI
import UniformTypeIdentifiers

struct ComparisonResearchInput {
    let ticker: ResearchTicker
    let fetched: Date
    let synthetic: Bool
    let bars: [StrategyBar]
    var label: String { (synthetic ? "합성 · ":"분석 스냅샷 · ")+ticker.label+" · "+(ticker.asset == .crypto ? "USDT":"USD")+" · 확정 일봉" }
    init(_ report: ResearchReport) throws {
        guard (30...50000).contains(report.bars.count),report.bars.allSatisfy({ $0.valid }) else { throw StrategyError.invalid("전달할 유효 확정 일봉이 30개 이상 필요합니다.") }
        let times = report.bars.compactMap { Int64(exactly:($0.time.timeIntervalSince1970*1000).rounded()) }
        guard times.count == report.bars.count,report.fetched.timeIntervalSince1970.isFinite,zip(times,times.dropFirst()).allSatisfy({ $0.0 < $0.1 }) else { throw StrategyError.invalid("일봉 시각 순서를 확인하세요.") }
        ticker = report.ticker;fetched = report.fetched;synthetic = report.synthetic
        bars = zip(times,report.bars).map { time,bar in StrategyBar(t:time,o:bar.open,h:bar.high,l:bar.low,c:bar.close,v:bar.volume) }
    }
    func marketSymbol(in symbols: [String]) -> String? { ticker.asset == .crypto && symbols.contains(ticker.base) ? ticker.base:nil }
}
struct StrategyComparisonRow: Codable {
    let profile: String
    let segment: String
    let bars: Int
    let feeBps: Double
    let slipBps: Double
    let returnPct: Double
    let maxDrawdownPct: Double
    let trades: Int
    let totalFees: Double
    let halted: Bool
}
struct StrategyComparisonReport: Codable {
    let mode: String
    let inputLabel: String?
    let synthetic: Bool
    let rows: [StrategyComparisonRow]
    let buyAndHoldReturnPct: Double
    let splitIndex: Int?
    let notes: [String]
}
enum StrategyComparison {
    static func run(_ rows: [StrategyBar],capital: Double,fee: Double,slip: Double,synthetic: Bool,inputLabel: String? = nil) throws -> StrategyComparisonReport {
        _ = try StrategyCore(capital,fee,slip)
        guard (30...50000).contains(rows.count) else { throw StrategyError.invalid("비교에는 30~50000봉이 필요합니다.") }
        var previous = Int64.min
        for row in rows {
            guard row.t > previous,[row.o,row.h,row.l,row.c,row.v].allSatisfy({ $0.isFinite }),
                  min(row.o,row.h,row.l,row.c) > 0,row.v >= 0,row.l <= min(row.o,row.c),row.h >= max(row.o,row.c) else { throw StrategyError.invalid("봉 순서와 OHLCV를 확인하세요.") }
            previous = row.t
        }
        var results: [StrategyComparisonRow] = []
        func compare(_ data: [StrategyBar],segment: String,fee: Double,slip: Double) throws {
            for profile in StrategyProfile.allCases {
                let engine = try StrategyCore.backtest(data,capital,fee,slip,profile)
                results.append(StrategyComparisonRow(profile:profile.rawValue,segment:segment,bars:data.count,feeBps:fee,slipBps:slip,
                    returnPct:(engine.equity/capital-1)*100,maxDrawdownPct:engine.maxDD,trades:engine.sells,totalFees:engine.totalFees,halted:engine.halted))
            }
        }
        try compare(rows,segment:"전체 구간",fee:fee,slip:slip)
        var notes = ["종가 신호 후 다음 봉 시가 체결 · 비용 포함 · 마지막 봉 청산", "전략 자본 배분은 기본10%·방어5%, 단순 보유 기준은 자본100%이므로 노출이 다릅니다.","파라미터 최적화·전략 자동 선택·실주문 연결을 하지 않습니다."]
        if fee <= 50 && slip <= 50 { try compare(rows,segment:"비용 2배",fee:fee*2,slip:slip*2) }
        else { notes.append("2배 비용이 엔진 상한100bps를 넘어서 비용 스트레스를 생략했습니다.") }
        let split = rows.count*7/10
        let splitIndex: Int?
        if split >= 30 && rows.count-split >= 30 {
            splitIndex = split
            try compare(Array(rows[..<split]),segment:"앞 70% 독립 실행",fee:fee,slip:slip)
            try compare(Array(rows[split...]),segment:"뒤 30% 독립 실행",fee:fee,slip:slip)
            notes.append("분할 구간은 각각 현금으로 시작하고 30봉을 준비합니다. 앞 구간의 지표·보유를 넘기지 않습니다. 최적화 후 검증이나 수익 보장이 아닙니다.")
        } else { splitIndex = nil;notes.append("앞·뒤 구간에 각각 30봉이 필요해 분할 비교를 생략했습니다.") }
        let buy = rows[0].o*(1+slip/10000)
        guard buy.isFinite,buy > 0 else { throw StrategyError.invalid("가격 규모가 계산 범위를 초과했습니다.") }
        let entryUnitCost = buy*(1+fee/10000)
        guard entryUnitCost.isFinite,entryUnitCost > 0 else { throw StrategyError.invalid("가격·비용 규모가 계산 범위를 초과했습니다.") }
        let quantity = capital/entryUnitCost
        let proceeds = quantity*rows[rows.count-1].c*(1-slip/10000)*(1-fee/10000)
        guard quantity.isFinite,proceeds.isFinite,((proceeds/capital-1)*100).isFinite,results.allSatisfy({ $0.returnPct.isFinite && $0.maxDrawdownPct.isFinite && $0.totalFees.isFinite }) else { throw StrategyError.invalid("입력 규모가 계산 범위를 초과했습니다.") }
        return StrategyComparisonReport(mode:"PAPER_STRATEGY_COMPARISON_V1",inputLabel:inputLabel,synthetic:synthetic,rows:results,buyAndHoldReturnPct:(proceeds/capital-1)*100,splitIndex:splitIndex,notes:notes)
    }
    static func sample() -> [StrategyBar] {
        (0..<180).map { index in
            let price = 100+Double(index)*0.05+sin(Double(index)/8)*5
            return StrategyBar(t:1767225600000+Int64(index)*60000,o:price,h:price+1,l:price-1,c:price,v:1000)
        }
    }
}
@MainActor final class StrategyComparisonStore: ObservableObject {
    @Published var capital = "1000000"
    @Published var fee = "5"
    @Published var slip = "5"
    @Published private(set) var researchInput: ComparisonResearchInput?
    @Published var report: StrategyComparisonReport?
    @Published var message = "CSV로 비교하거나 합성 예제를 실행하세요."
    @Published var busy = false
    private var task: Task<Void,Never>?
    private var generation = UUID()
    func cancel() { if busy { message = "비교를 취소했습니다." };generation = UUID();task?.cancel();task = nil;busy = false }
    func useResearch(_ input: ComparisonResearchInput) { cancel();report = nil;researchInput = input;message = "분석 일봉을 받았습니다. 비용을 확인하고 비교를 실행하세요." }
    func start(url: URL?,capital: Double,fee: Double,slip: Double,researchInput input: ComparisonResearchInput? = nil) {
        cancel();let token = generation;report = nil;busy = true;message = "기기 안에서 전략 비교 중"
        task = Task {
            let worker = Task.detached(priority:.userInitiated) { () throws -> StrategyComparisonReport in
                let rows: [StrategyBar]
                if let input { rows = input.bars }
                else if let url {
                    let access = url.startAccessingSecurityScopedResource();defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let file = try FileHandle(forReadingFrom:url);defer { try? file.close() }
                    let bytes = try file.read(upToCount:8*1024*1024+1) ?? Data()
                    guard bytes.count <= 8*1024*1024,let text = String(data:bytes,encoding:.utf8) else { throw StrategyError.invalid("UTF-8 CSV 8MB 이하가 필요합니다.") }
                    rows = try StrategyCore.csv(text)
                } else { rows = StrategyComparison.sample() }
                return try StrategyComparison.run(rows,capital:capital,fee:fee,slip:slip,synthetic:input?.synthetic ?? (url == nil),inputLabel:input?.label ?? (url == nil ? "합성 예제":"사용자 CSV · 통화 미지정"))
            }
            do {
                let value = try await withTaskCancellationHandler(operation: { try await worker.value },onCancel: { worker.cancel() })
                guard !Task.isCancelled,generation == token else { return }
                report = value;message = value.synthetic ? "합성 예제 · 실제 시장 성과 아님":"입력 자료 비교 · 과거 모의 결과"
            } catch { if !Task.isCancelled,generation == token { message = "실행 실패: "+error.localizedDescription } }
            if generation == token { busy = false;task = nil }
        }
    }
}
struct StrategyComparisonView: View {
    @ObservedObject var store: StrategyComparisonStore
    let market: MarketStore
    @State private var importing = false
    @State private var exporting = false
    @State private var document = JSONDocument(data:Data())
    @State private var inputMessage = ""
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                Text("전략의 비용과 위험을 함께").font(.title2.bold())
                VStack(alignment:.leading,spacing:12) {
                    TextField("시작 자본",text:$store.capital).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    TextField("수수료 bps",text:$store.fee).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    TextField("슬리피지 bps",text:$store.slip).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    if let input = store.researchInput {
                        Text("전달받은 자료 · "+input.label).font(.subheadline).accessibilityIdentifier("comparison-research-source")
                        Text("분석 시각 "+input.fetched.formatted(date:.abbreviated,time:.shortened)+" · \(input.bars.count)봉").font(.caption)
                        Text("일봉 종료시각을 봉 식별자로 사용합니다. 실제 장중 체결시각을 재현하지 않습니다.").font(.caption).foregroundStyle(.secondary)
                        Button("전달받은 일봉 비교") { run(nil,input:input) }.disabled(store.busy).frame(minHeight:44).accessibilityIdentifier("comparison-research-run")
                        if let symbol = input.marketSymbol(in:market.symbols) {
                            NavigationLink {
                                MarketView(favoritesOnly:false).environmentObject(market).onAppear { market.selected = symbol;market.setForeground(true) }.onDisappear { market.setForeground(false) }
                            } label: { Text(symbol+" 원화 시세 살펴보기") }
                            Text("분석은 USDT 일봉, 시세 화면은 KRW 관측 가격으로 가격 기준이 다릅니다.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("CSV 전략 비교") { importing = true }.frame(minHeight:44).disabled(store.busy)
                    Button("합성 예제 비교") { run(nil) }.frame(minHeight:44).disabled(store.busy).accessibilityIdentifier("strategy-comparison-sample")
                    if store.busy { ProgressView();Button("비교 취소") { store.cancel() } }
                    Text(inputMessage.isEmpty ? store.message:inputMessage).accessibilityIdentifier("strategy-comparison-status")
                }.modifier(CareCard())
                if let report = store.report {
                    Text("이번 결과 입력 · "+(report.inputLabel ?? "이전 비교 결과")).font(.headline)
                    ForEach(Array(report.rows.enumerated()),id:\.offset) { _,row in
                        VStack(alignment:.leading,spacing:6) {
                            Text(row.profile+" · "+row.segment).font(.headline)
                            Text(String(format:"순수익률 %+.2f%% · 최대 낙폭 %.2f%%",row.returnPct,row.maxDrawdownPct))
                            Text("청산 \(row.trades)회 · \(row.bars)봉 · 수수료 \(row.feeBps)bps · 슬리피지 \(row.slipBps)bps").font(.caption)
                            Text(row.halted ? "손실 한도로 신규 진입 중지":"신규 진입 중지 없음").font(.caption)
                        }.frame(maxWidth:.infinity,alignment:.leading).modifier(CareCard())
                    }
                    Text(String(format:"자본100%% 단순 보유 순수익률 %+.2f%%",report.buyAndHoldReturnPct)).font(.headline)
                    ForEach(report.notes,id:\.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                    Button("비교 결과 JSON 저장") {
                        if let bytes = try? JSONEncoder().encode(report) { document = JSONDocument(data:bytes);exporting = true }
                    }.frame(minHeight:44)
                }
                Text("기존 기본·방어 전략을 같은 자료에서 평가합니다. 수익 개선을 보장하거나 주문을 실행하지 않습니다.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.navigationTitle("전략 비교").background(Color(uiColor:.systemGroupedBackground))
        .fileImporter(isPresented:$importing,allowedContentTypes:[.commaSeparatedText,.plainText]) { result in
            switch result { case .success(let url):run(url);case .failure:inputMessage = "파일을 열지 못했습니다." }
        }
        .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"strategy-comparison") { result in if case .failure = result { inputMessage = "비교 결과를 저장하지 못했습니다." } }
        .onDisappear { store.cancel() }
        .onChange(of:store.capital) { _ in inputsChanged() }.onChange(of:store.fee) { _ in inputsChanged() }.onChange(of:store.slip) { _ in inputsChanged() }
    }
    private func inputsChanged() { store.cancel();store.report = nil;inputMessage = "입력이 변경됐습니다. 다시 비교하세요." }
    private func run(_ url: URL?,input: ComparisonResearchInput? = nil) {
        guard let c = Double(store.capital),let f = Double(store.fee),let s = Double(store.slip) else { inputMessage = "숫자 입력을 확인하세요.";return }
        inputMessage = "";store.start(url:url,capital:c,fee:f,slip:s,researchInput:input)
    }
}
