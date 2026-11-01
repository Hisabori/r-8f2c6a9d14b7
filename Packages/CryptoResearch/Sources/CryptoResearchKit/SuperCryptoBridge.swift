import SwiftUI
public struct NativeInvestmentView: View {
    @StateObject private var store = MarketStore()
    @Environment(\.scenePhase) private var phase
    public init() {}
    public var body: some View {
        RootView().environmentObject(store).tint(.careBlue)
            .onAppear { store.setForeground(true) }
            .onDisappear { store.setForeground(false) }
            .onChange(of: phase) { store.setForeground($0 == .active) }
    }
}
