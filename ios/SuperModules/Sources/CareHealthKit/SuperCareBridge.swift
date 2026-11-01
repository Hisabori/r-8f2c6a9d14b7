import SwiftUI
import UIKit
@MainActor public enum SuperCareBridge {
    public static func controller(close:@escaping()->Void)->UIViewController {
        UIHostingController(rootView:SuperCareRoot(close:close))
    }
    @discardableResult public static func handle(_ url:URL)->Bool {CareShortcutRouter.shared.open(url)}
}
private struct SuperCareRoot:View {
    let close:()->Void
    @StateObject private var shortcuts=CareShortcutRouter.shared
    @StateObject private var medications=MedicationStore()
    @StateObject private var articles=ArticleLibrary()
    @StateObject private var journal=Journal()
    @StateObject private var sync=LocalHealthSync()
    @AppStorage("app-theme") private var theme="system"
    @AppStorage("app-deep-mind") private var deepMind=false
    @AppStorage("app-deep-style") private var deepStyle="미드나잇"
    var body:some View {
        RootView().modifier(CareThemeSurface())
            .preferredColorScheme(deepMind ? .dark:theme=="dark" ? .dark:theme=="light" ? .light:nil)
            .environmentObject(journal).environmentObject(sync).environmentObject(shortcuts).environmentObject(articles).environmentObject(medications)
            .tint(deepMind ? CareAppearance.accent(for:deepStyle):Palette.blue)
            .environment(\.locale,Locale(identifier:"ko_KR"))
            .safeAreaInset(edge:.top){HStack{Button(action:close){Label("오늘로",systemImage:"chevron.left").frame(minHeight:44)}.accessibilityIdentifier("super-close-health");Spacer();Text("온케어").font(.headline)}.padding(.horizontal,20).background(.bar)}
            .alert("온케어 안내",isPresented:Binding(get:{journal.notice != nil},set:{if !$0{journal.notice=nil}})){Button("확인"){journal.notice=nil}}message:{Text(journal.notice ?? "")}
    }
}
