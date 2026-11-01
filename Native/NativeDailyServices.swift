import SwiftUI
import CryptoResearchKit

struct NativeDailyServices: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("함께하는 일상").font(.title2.bold())
            NavigationLink {
                NativePetView().toolbar(.hidden, for: .tabBar)
            } label: { service("반려생활", detail: "소리를 기록하고 흐름을 살펴봐요", symbol: "pawprint.fill", color: Palette.teal) }
            .accessibilityIdentifier("native-pet-open")
            Divider()
            NavigationLink {
                NativeTravelView().toolbar(.hidden, for: .tabBar)
            } label: { service("이동 준비", detail: "목적지를 찾고 여유 있게 출발해요", symbol: "map.fill", color: Palette.blue) }
            .accessibilityIdentifier("native-travel-open")
            Divider()
            NavigationLink {
                NativeInvestmentView().toolbar(.hidden, for: .tabBar)
            } label: { service("투자와 리서치", detail: "시장과 나의 투자 기록을 확인해요", symbol: "chart.xyaxis.line", color: Palette.purple) }
            .accessibilityIdentifier("native-investment-open")
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
