import SwiftUI
import Combine

public struct NativeResearchDigest: Codable, Equatable {
    public let ticker: String
    public let direction: String
    public let analyzedAt: Date
    public let synthetic: Bool
}

/// In-memory navigation continuity only. It never accepts health or audio data.
@MainActor public final class NativeInvestmentSession: ObservableObject {
    let market = MarketStore()
    let research = TickerResearchStore()
    @Published var researchAsset = ResearchAsset.crypto { didSet { defaults.set(researchAsset.rawValue,forKey:"research-input-kind-v1") } }
    @Published var researchTicker = "BTC" { didSet { defaults.set(researchTicker,forKey:"research-input-symbol-v1") } }
    private var observation: AnyCancellable?
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        researchAsset = ResearchAsset(rawValue:defaults.string(forKey:"research-input-kind-v1") ?? "") ?? .crypto
        if let input = defaults.string(forKey:"research-input-symbol-v1"),input.count <= 24,(try? ResearchTicker(input,asset:researchAsset)) != nil { researchTicker = input }
        else { researchTicker = researchAsset == .stock ? "AAPL":"BTC" }
        market.setForeground(false)
        observation = research.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
    public var researchBusy: Bool { research.busy }
    public var researchDigest: NativeResearchDigest? {
        guard let r = research.report else { return nil }
        return NativeResearchDigest(ticker:r.ticker.label,direction:r.direction,analyzedAt:r.fetched,synthetic:r.synthetic)
    }
    public var researchSummary: String {
        if research.busy { return "티커 자료 확인 중" }
        guard let r = researchDigest else { return "코인·미국 주식과 시장을 차분하게 살펴봐요" }
        return (r.synthetic ? "예제 · ":"최근 분석 · ")+r.ticker+" · "+r.direction
    }
}
