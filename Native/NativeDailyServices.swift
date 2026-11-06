import SwiftUI
import CryptoResearchKit

struct NativeDailyServices: View {
    @ObservedObject private var router = NativeServiceRouter.shared
    @EnvironmentObject private var pets: NativePetStore
    @EnvironmentObject private var travel: NativeTravelStore
    @EnvironmentObject private var investment: NativeInvestmentSession
    private var travelSummary: String { guard let name = travel.selected?.name else { return "목적지를 찾고 여유 있게 출발해요" };return "선택한 목적지 · "+name }
    private var petSummary: String { pets.recording ? "녹음 중 · 눌러서 상태 확인" : pets.busy ? "기기에서 분석 중" : pets.records.first.map { "소리 기록 \(pets.records.count)개 · \($0.date.formatted(date:.abbreviated,time:.omitted))" } ?? "소리를 기록하고 흐름을 살펴봐요" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("함께하는 일상").font(.title2.bold())
            if let recent = router.lastDestination {
                Button { router.open(recent) } label: {
                    Label("이어보기 · "+recent.title,systemImage:"clock.arrow.circlepath")
                        .frame(maxWidth:.infinity,minHeight:44,alignment:.leading)
                }.buttonStyle(.bordered).accessibilityIdentifier("native-service-resume")
            }
            NavigationLink {
                NativePetView().onAppear { router.note(.pet) }.toolbar(.hidden, for: .tabBar)
            } label: { service("반려생활", detail: petSummary, symbol: "pawprint.fill", color: Palette.teal) }
            .accessibilityIdentifier("native-pet-open")
            Divider()
            NavigationLink {
                NativeTravelView().onAppear { router.note(.travel) }.toolbar(.hidden, for: .tabBar)
            } label: { service("이동 준비", detail: travelSummary, symbol: "map.fill", color: Palette.blue) }
            .accessibilityIdentifier("native-travel-open")
            Divider()
            NavigationLink {
                NativeInvestmentView().onAppear { router.note(.investment) }.toolbar(.hidden, for: .tabBar)
            } label: { service("투자와 리서치", detail: investment.researchSummary, symbol: "chart.xyaxis.line", color: Palette.purple) }
            .accessibilityIdentifier("native-investment-open")
            NavigationLink { TickerResearchView().onAppear { router.note(.ticker) }.toolbar(.hidden, for:.tabBar) } label: {
                Label("바로 티커 분석",systemImage:"sparkle.magnifyingglass").frame(maxWidth:.infinity,minHeight:44)
            }.buttonStyle(.bordered).accessibilityIdentifier("home-ticker-open")
        }.careCard().buttonStyle(.plain)
    }
    private func service(_ title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(color).frame(width: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
        }.frame(minHeight: 58).contentShape(Rectangle())
    }
}
