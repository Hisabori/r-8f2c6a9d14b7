import SwiftUI
public struct NativeInvestmentView: View {
    @EnvironmentObject private var session: NativeInvestmentSession
    private var store: MarketStore { session.market }
    @Environment(\.scenePhase) private var phase
    @State private var visible = false
    public init() {}
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("시장을 살펴보고, 나의 속도로").font(.title.bold())
                Text("시세와 관심 종목, 전략과 거래 설정을 한곳에서 확인하세요.").foregroundStyle(.secondary)
                Text(session.comparisonSummary).font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("investment-workspace-summary")
                VStack(alignment: .leading, spacing: 16) {
                    NavigationLink { TickerResearchView().environmentObject(session) } label: { Label("코인·미국 주식 티커 분석", systemImage: "sparkle.magnifyingglass").frame(minHeight: 44) }.accessibilityIdentifier("ticker-research-open")
                    Divider()
                    NavigationLink { MarketView(favoritesOnly: false).environmentObject(store) } label: { Label("시장 살펴보기", systemImage: "chart.xyaxis.line").frame(minHeight: 44) }.accessibilityIdentifier("investment-market-open")
                    Divider()
                    NavigationLink { MarketView(favoritesOnly: true).environmentObject(store) } label: { Label("관심 종목", systemImage: "star").frame(minHeight: 44) }.accessibilityIdentifier("investment-favorites-open")
                    Divider()
                    NavigationLink { StrategyResearchView().environmentObject(store) } label: { Label("전략과 리서치", systemImage: "doc.text.magnifyingglass").frame(minHeight: 44) }.accessibilityIdentifier("investment-strategy-open")
                    Divider()
                    NavigationLink { StrategyComparisonView(store:session.comparison,market:store) } label: { Label("전략 비교·비용 스트레스",systemImage:"chart.bar.xaxis").frame(minHeight:44) }.accessibilityIdentifier("strategy-comparison-open")
                    Divider()
                    NavigationLink { SettingsView().environmentObject(store) } label: { Label("거래소와 연결 설정", systemImage: "slider.horizontal.3").frame(minHeight: 44) }.accessibilityIdentifier("investment-settings-open")
                }.modifier(CareCard())
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("투자와 리서치").navigationBarTitleDisplayMode(.inline)
            .environmentObject(store).tint(.careBlue)
            .onAppear { visible = true;store.setForeground(true) }
            .onDisappear { visible = false;store.setForeground(false) }
            .onChange(of: phase) { store.setForeground($0 == .active && visible) }
    }
}
