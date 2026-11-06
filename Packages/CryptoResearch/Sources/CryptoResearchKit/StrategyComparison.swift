import SwiftUI
import UniformTypeIdentifiers

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
    let synthetic: Bool
    let rows: [StrategyComparisonRow]
    let buyAndHoldReturnPct: Double
    let splitIndex: Int?
    let notes: [String]
}
enum StrategyComparison {
    static func run(_ rows: [StrategyBar],capital: Double,fee: Double,slip: Double,synthetic: Bool) throws -> StrategyComparisonReport {
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
        return StrategyComparisonReport(mode:"PAPER_STRATEGY_COMPARISON_V1",synthetic:synthetic,rows:results,buyAndHoldReturnPct:(proceeds/capital-1)*100,splitIndex:splitIndex,notes:notes)
    }
    static func sample() -> [StrategyBar] {
        (0..<180).map { index in
            let price = 100+Double(index)*0.05+sin(Double(index)/8)*5
            return StrategyBar(t:1767225600000+Int64(index)*60000,o:price,h:price+1,l:price-1,c:price,v:1000)
        }
    }
}
@MainActor final class StrategyComparisonStore: ObservableObject {
    @Published var report: StrategyComparisonReport?
    @Published var message = "CSV로 비교하거나 합성 예제를 실행하세요."
    @Published var busy = false
    private var task: Task<Void,Never>?
    private var generation = UUID()
    func cancel() { if busy { message = "비교를 취소했습니다." };generation = UUID();task?.cancel();task = nil;busy = false }
    func start(url: URL?,capital: Double,fee: Double,slip: Double) {
        cancel();let token = generation;report = nil;busy = true;message = "기기 안에서 전략 비교 중"
        task = Task {
            let worker = Task.detached(priority:.userInitiated) { () throws -> StrategyComparisonReport in
                let rows: [StrategyBar]
                if let url {
                    let access = url.startAccessingSecurityScopedResource();defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let file = try FileHandle(forReadingFrom:url);defer { try? file.close() }
                    let bytes = try file.read(upToCount:8*1024*1024+1) ?? Data()
                    guard bytes.count <= 8*1024*1024,let text = String(data:bytes,encoding:.utf8) else { throw StrategyError.invalid("UTF-8 CSV 8MB 이하가 필요합니다.") }
                    rows = try StrategyCore.csv(text)
                } else { rows = StrategyComparison.sample() }
                return try StrategyComparison.run(rows,capital:capital,fee:fee,slip:slip,synthetic:url == nil)
            }
            do {
                let value = try await withTaskCancellationHandler(operation: { try await worker.value },onCancel: { worker.cancel() })
                guard !Task.isCancelled,generation == token else { return }
                report = value;message = value.synthetic ? "합성 예제 · 실제 시장 성과 아님":"입력 CSV 비교 · 과거 모의 결과"
            } catch { if !Task.isCancelled,generation == token { message = "실행 실패: "+error.localizedDescription } }
            if generation == token { busy = false;task = nil }
        }
    }
}
struct StrategyComparisonView: View {
    @StateObject private var store = StrategyComparisonStore()
    @State private var capital = "1000000"
    @State private var fee = "5"
    @State private var slip = "5"
    @State private var importing = false
    @State private var exporting = false
    @State private var document = JSONDocument(data:Data())
    @State private var inputMessage = ""
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                Text("전략의 비용과 위험을 함께").font(.title2.bold())
                VStack(alignment:.leading,spacing:12) {
                    TextField("시작 자본",text:$capital).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    TextField("수수료 bps",text:$fee).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    TextField("슬리피지 bps",text:$slip).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    Button("CSV 전략 비교") { importing = true }.frame(minHeight:44).disabled(store.busy)
                    Button("합성 예제 비교") { run(nil) }.frame(minHeight:44).disabled(store.busy).accessibilityIdentifier("strategy-comparison-sample")
                    if store.busy { ProgressView();Button("비교 취소") { store.cancel() } }
                    Text(inputMessage.isEmpty ? store.message:inputMessage).accessibilityIdentifier("strategy-comparison-status")
                }.modifier(CareCard())
                if let report = store.report {
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
        .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"strategy-comparison") { _ in }
        .onDisappear { store.cancel() }
        .onChange(of:capital) { _ in inputsChanged() }.onChange(of:fee) { _ in inputsChanged() }.onChange(of:slip) { _ in inputsChanged() }
    }
    private func inputsChanged() { store.cancel();store.report = nil;inputMessage = "입력이 변경됐습니다. 다시 비교하세요." }
    private func run(_ url: URL?) {
        guard let c = Double(capital),let f = Double(fee),let s = Double(slip) else { inputMessage = "숫자 입력을 확인하세요.";return }
        inputMessage = "";store.start(url:url,capital:c,fee:f,slip:s)
    }
}
