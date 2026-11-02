import SwiftUI
public struct NativeInvestmentView: View {
    @StateObject private var store = MarketStore()
    @Environment(\.scenePhase) private var phase
    public init() {}
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("시장을 살펴보고, 나의 속도로").font(.title.bold())
                Text("시세와 관심 종목, 전략과 거래 설정을 한곳에서 확인하세요.").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 16) {
                    NavigationLink { TickerResearchView() } label: { Label("코인·미국 주식 티커 분석", systemImage: "sparkle.magnifyingglass").frame(minHeight: 44) }.accessibilityIdentifier("ticker-research-open")
                    Divider()
                    NavigationLink { MarketView(favoritesOnly: false) } label: { Label("시장 살펴보기", systemImage: "chart.xyaxis.line").frame(minHeight: 44) }
                    Divider()
                    NavigationLink { MarketView(favoritesOnly: true) } label: { Label("관심 종목", systemImage: "star").frame(minHeight: 44) }
                    Divider()
                    NavigationLink { StrategyResearchView() } label: { Label("전략과 리서치", systemImage: "doc.text.magnifyingglass").frame(minHeight: 44) }
                    Divider()
                    NavigationLink { SettingsView() } label: { Label("거래소와 연결 설정", systemImage: "slider.horizontal.3").frame(minHeight: 44) }
                }.modifier(CareCard())
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("투자와 리서치").navigationBarTitleDisplayMode(.inline)
            .environmentObject(store).tint(.careBlue)
            .onAppear { store.setForeground(true) }
            .onDisappear { store.setForeground(false) }
            .onChange(of: phase) { store.setForeground($0 == .active) }
    }
}
