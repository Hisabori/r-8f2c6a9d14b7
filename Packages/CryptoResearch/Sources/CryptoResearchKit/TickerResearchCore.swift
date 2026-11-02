import Foundation

enum ResearchAsset: String, Codable, CaseIterable { case crypto, stock }
struct ResearchTicker: Codable, Equatable {
    let asset: ResearchAsset
    let symbol: String
    init(_ raw: String, asset: ResearchAsset) throws {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch asset {
        case .crypto:
            guard text.range(of: "^[A-Z0-9]{2,20}$", options: .regularExpression) != nil else { throw ResearchFailure.invalidTicker }
            let base = text.hasSuffix("USDT") ? String(text.dropLast(4)) : text
            guard !base.isEmpty, base != "USDT" else { throw ResearchFailure.invalidTicker }
            symbol = base + "USDT"
        case .stock:
            guard text.range(of: "^[A-Z][A-Z0-9.-]{0,14}$", options: .regularExpression) != nil, !text.contains(".."), !text.hasSuffix(".") else { throw ResearchFailure.invalidTicker }
            symbol = text
        }
        self.asset = asset
    }
    var base: String { asset == .crypto ? String(symbol.dropLast(4)) : symbol }
    var label: String { asset == .crypto ? "\(base)/USDT" : symbol }
}
enum ResearchFailure: LocalizedError {
    case invalidTicker, invalidData, missingKey, unavailable, oversized, rateLimit
    var errorDescription: String? {
        switch self {
        case .invalidTicker: return "코인은 BTC·ETHUSDT, 미국 주식은 AAPL·MSFT처럼 입력하세요."
        case .invalidData: return "종목·시각·OHLCV 또는 응답 형식을 확인할 수 없습니다."
        case .missingKey: return "미국 주식·뉴스 조회에는 분석 데이터용 Alpha Vantage 키가 필요합니다."
        case .unavailable: return "공급자가 자료를 제공하지 않았습니다. 지원 종목·연결·API 이용 범위를 확인하세요."
        case .oversized: return "분석 파일과 공급자 응답은 2MB 이하만 허용합니다."
        case .rateLimit: return "공급자 요청 한도에 도달했습니다. 잠시 후 다시 조회하세요."
        }
    }
}
struct ResearchBar: Codable, Equatable, Identifiable {
    let time: Date // Closed bar's end time, never a forming candle.
    let open: Double, high: Double, low: Double, close: Double, volume: Double
    var id: Date { time }
    var valid: Bool {
        [open,high,low,close,volume,time.timeIntervalSince1970].allSatisfy(\.isFinite) && open > 0 && low > 0 && close > 0 && high >= max(open,close) && low <= min(open,close) && high >= low && volume >= 0 && volume <= 1e24 && [open,high,low,close].allSatisfy({ (1e-15...1e15).contains($0) }) && time.timeIntervalSince1970 > 0
    }
}
struct ResearchHeadline: Codable, Identifiable {
    let source: String, title: String, url: String
    let time: Date
    var id: String { url }
}
struct ResearchTextSummary {
    let items: [ResearchHeadline]
    let positive: Int, negative: Int, mixed: Int
    var direction: Double? { items.count >= 3 ? Double(positive-negative)/Double(items.count) : nil }
}
struct ResearchMetrics {
    let sma20: Double, sma50: Double, rsi14: Double, macd: Double, macdSignal: Double
    let atr14: Double, lowerBand: Double, upperBand: Double
    let changePercent: Double, change5Percent: Double, gapPercent: Double
    let relativeVolume: Double?, volumeZ: Double?, returnZ: Double?
}
struct ResearchReport {
    let ticker: ResearchTicker, bars: [ResearchBar], fetched: Date, source: String
    let synthetic: Bool, imported: Bool, stale: Bool
    let metrics: ResearchMetrics?, news: ResearchTextSummary, community: ResearchTextSummary
    let score: Double?, coverage: Int, reasons: [String], anomalies: [String], notices: [String]
    var direction: String {
        guard let score else { return "판정 보류" }
        return score >= 25 ? "상방 단서 우세" : score <= -25 ? "하방 단서 우세" : "방향 혼재"
    }
}
enum TickerResearchMath {
    static func mean(_ values: [Double]) -> Double { values.reduce(0,+)/Double(values.count) }
    static func deviation(_ values: [Double]) -> Double { let m = mean(values); return sqrt(mean(values.map { pow($0-m,2) })) }
    static func ema(_ values: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: values.count)
        guard period > 0, values.count >= period else { return result }
        var value = mean(Array(values.prefix(period))); result[period-1] = value
        for i in period..<values.count { value += (values[i]-value)*2/Double(period+1); result[i] = value }
        return result
    }
    static func rsi(_ close: [Double], period: Int = 14) -> Double? {
        guard period > 0, close.count > period else { return nil }
        let changes = zip(close.dropFirst(),close).map { $0.0-$0.1 }
        var gain = mean(Array(changes.prefix(period)).map { max(0,$0) })
        var loss = mean(Array(changes.prefix(period)).map { max(0,-$0) })
        for change in changes.dropFirst(period) { gain = (gain*Double(period-1)+max(0,change))/Double(period); loss = (loss*Double(period-1)+max(0,-change))/Double(period) }
        return loss == 0 ? (gain == 0 ? 50 : 100) : 100-100/(1+gain/loss)
    }
    static func metrics(_ bars: [ResearchBar]) -> ResearchMetrics? {
        guard bars.count >= 60, bars.allSatisfy(\.valid), let last = bars.last else { return nil }
        let close = bars.map(\.close), previous = bars[bars.count-2]
        let fast = ema(close,period:12), slow = ema(close,period:26)
        let macds = zip(fast,slow).compactMap { a,b -> Double? in guard let a, let b else { return nil }; return a-b }
        guard let macd = macds.last, let signal = ema(macds,period:9).last ?? nil, let rsi = rsi(close) else { return nil }
        let ranges = bars.indices.dropFirst().map { max(bars[$0].high-bars[$0].low,abs(bars[$0].high-bars[$0-1].close),abs(bars[$0].low-bars[$0-1].close)) }
        var atr = mean(Array(ranges.prefix(14)))
        for value in ranges.dropFirst(14) { atr = (atr*13+value)/14 }
        let window = Array(close.suffix(20)), center = mean(window), sd = deviation(window)
        let volumes = Array(bars.dropLast().suffix(20)).map(\.volume), volumeMean = mean(volumes), volumeSD = deviation(volumes)
        let returns = (1..<bars.count-1).map { (bars[$0].close/bars[$0-1].close-1)*100 }
        let priorReturns = Array(returns.suffix(20)), change = (last.close/previous.close-1)*100
        let returnSD = deviation(priorReturns)
        return ResearchMetrics(sma20:center,sma50:mean(Array(close.suffix(50))),rsi14:rsi,macd:macd,macdSignal:signal,atr14:atr,lowerBand:center-2*sd,upperBand:center+2*sd,changePercent:change,change5Percent:(last.close/bars[bars.count-6].close-1)*100,gapPercent:(last.open/previous.close-1)*100,relativeVolume:volumeMean > 0 ? last.volume/volumeMean:nil,volumeZ:volumeSD > 0 ? (last.volume-volumeMean)/volumeSD:nil,returnZ:returnSD > 0 ? (change-mean(priorReturns))/returnSD:nil)
    }
    static func safeLink(_ raw: String) -> Bool {
        guard let u = URLComponents(string:raw),u.scheme == "https",u.user == nil,u.password == nil,u.port == nil || u.port == 443,let host = u.host?.lowercased(), host.contains("."),host != "localhost",!host.hasSuffix(".local"),host.range(of:"^[0-9.:]+$",options:.regularExpression) == nil else { return false }
        return true
    }
    static func textSummary(_ input: [ResearchHeadline], now: Date) -> ResearchTextSummary {
        var urls = Set<String>(), titles = Set<String>()
        let items = input.sorted { $0.time > $1.time }.filter {
            let title = $0.title.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
            guard !$0.source.isEmpty, $0.source.count <= 100, !title.isEmpty, title.count <= 500, safeLink($0.url), (0...7*86400).contains(now.timeIntervalSince($0.time)) else { return false }
            return urls.insert($0.url.components(separatedBy:"?")[0]).inserted && titles.insert(title).inserted
        }
        let up = ["상승","급등","호재","돌파","반등","rally","surge","gain","upgrade","beat"]
        let down = ["하락","급락","악재","폭락","해킹","사기","drop","plunge","loss","downgrade","miss"]
        func contains(_ title: String, _ word: String) -> Bool {
            word.range(of:"^[a-z]+$",options:.regularExpression) == nil ? title.contains(word) : title.range(of:"(?<![a-z])"+word+"(?:s|d|ed|ing)?(?![a-z])",options:.regularExpression) != nil
        }
        var positive = 0,negative = 0,mixed = 0
        for item in items { let t = item.title.lowercased(),u = up.contains { contains(t,$0) },d = down.contains { contains(t,$0) }; if u && d { mixed += 1 } else if u { positive += 1 } else if d { negative += 1 } }
        return ResearchTextSummary(items:items,positive:positive,negative:negative,mixed:mixed)
    }
    static func report(ticker: ResearchTicker, bars: [ResearchBar], news: [ResearchHeadline], community: [ResearchHeadline], now: Date, source: String, synthetic: Bool = false, imported: Bool = false, notices: [String] = []) throws -> ResearchReport {
        guard bars.count <= 1000, bars.allSatisfy(\.valid), zip(bars,bars.dropFirst()).allSatisfy({$0.0.time < $0.1.time}), bars.allSatisfy({$0.time <= now}) else { throw ResearchFailure.invalidData }
        let n = textSummary(news,now:now),c = textSummary(community,now:now)
        let stale = bars.last.map { now.timeIntervalSince($0.time) > (ticker.asset == .crypto ? 2:7)*86400 } ?? true
        let m = metrics(bars)
        var score = 0.0,coverage = 0,reasons: [String] = [],anomalies: [String] = [],warnings = notices
        if let m, let last = bars.last {
            let epsilon = max(abs(last.close)*1e-10,1e-18)
            let trend = m.sma20-m.sma50 > epsilon ? 1.0 : m.sma50-m.sma20 > epsilon ? -1.0 : 0
            let momentum = m.macd-m.macdSignal > epsilon ? 1.0 : m.macdSignal-m.macd > epsilon ? -1.0 : 0
            let strength = m.rsi14 > 55 ? 1.0 : m.rsi14 < 45 ? -1.0 : 0
            score += trend*25+momentum*20+strength*15; coverage += 60
            score += max(-1,min(1,m.change5Percent/5))*15; coverage += 15
            reasons += ["20/50일 평균 추세 \(trend > 0 ? "상방":trend < 0 ? "하방":"중립")", "MACD와 시그널선 \(momentum > 0 ? "상방":momentum < 0 ? "하방":"중립")", "최근 5개 확정 일봉 수익률 \(String(format:"%+.2f%%",m.change5Percent))"]
            if let relative = m.relativeVolume { coverage += 15; score += max(0,min(1,relative-1)) * (m.changePercent > 0 ? 1:m.changePercent < 0 ? -1:0) * 15; if relative >= 2 { anomalies.append("거래량이 직전 20일 평균의 2배 이상") } }
            if abs(m.gapPercent) >= 3 { anomalies.append("직전 종가 대비 시가 갭 3% 이상") }
            if abs(m.returnZ ?? 0) >= 3 { anomalies.append("일간 수익률이 최근 표본 평균에서 3σ 이상 이탈") }
            if m.atr14/last.close >= 0.05 { anomalies.append("ATR 기준 변동폭이 종가의 5% 이상") }
            if m.upperBand > m.lowerBand && (last.close > m.upperBand || last.close < m.lowerBand) { anomalies.append("종가가 20일 볼린저 밴드 밖에 위치") }
            if m.rsi14 >= 70 || m.rsi14 <= 30 { anomalies.append("RSI가 70 이상 또는 30 이하 · 반전 보장은 아님") }
            if ticker.asset == .stock { warnings.append("미국 주식 일봉은 분할·배당 미조정 가격입니다. 기업행사가 급변 신호를 만들 수 있습니다.") }
        } else { warnings.append("지표·종합 판정에는 유효한 확정 일봉 60개 이상이 필요합니다.") }
        if let d = n.direction { score += d*5; coverage += 5 } else { warnings.append("뉴스 제목 유효 표본 3개 미만 · 뉴스 점수 제외") }
        if let d = c.direction { score += d*5; coverage += 5 } else { warnings.append("커뮤니티 제목 유효 표본 3개 미만 · 커뮤니티 점수 제외") }
        if stale { warnings.append("최근 확정 일봉이 오래됐습니다. 종합 판정을 보류합니다.") }
        if imported { warnings.append("가져온 파일의 출처·완전성은 검증되지 않았습니다.") }
        if synthetic { warnings.append("합성 예제입니다. 실제 시장의 분석이나 시그널이 아닙니다.") }
        return ResearchReport(ticker:ticker,bars:bars,fetched:now,source:source,synthetic:synthetic,imported:imported,stale:stale,metrics:m,news:n,community:c,score:m != nil && !stale && !synthetic ? max(-100,min(100,score)):nil,coverage:coverage,reasons:reasons,anomalies:anomalies,notices:warnings)
    }
}
