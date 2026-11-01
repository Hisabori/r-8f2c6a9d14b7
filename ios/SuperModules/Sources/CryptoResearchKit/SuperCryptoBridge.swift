import SwiftUI
import UIKit
@MainActor public enum SuperCryptoBridge {
    public static func controller(close:@escaping()->Void)->UIViewController{UIHostingController(rootView:SuperCryptoRoot(close:close))}
}
private struct SuperCryptoRoot:View {
    let close:()->Void
    @StateObject private var store=MarketStore()
    @AppStorage("crypto-appearance") private var appearance="system"
    @Environment(\.scenePhase) private var phase
    var body:some View {
        RootView().environmentObject(store).tint(.careBlue)
            .preferredColorScheme(appearance=="dark" ? .dark:appearance=="light" ? .light:nil)
            .safeAreaInset(edge:.top){HStack{Button(action:close){Label("오늘로",systemImage:"chevron.left").frame(minHeight:44)}.accessibilityIdentifier("super-close-crypto");Spacer();Text("투자와 리서치").font(.headline)}.padding(.horizontal,20).background(.bar)}
            .onAppear{store.setForeground(true)}.onDisappear{store.setForeground(false)}.onChange(of:phase){store.setForeground($0 == .active)}
    }
}
