import SwiftUI
@main struct CareSuiteNativeApp: App {
    @UIApplicationDelegateAdaptor(CareShortcutAppDelegate.self) private var appDelegate
    @StateObject private var shortcuts = CareShortcutRouter.shared
    @StateObject private var medications = MedicationStore()
    @StateObject private var articles = ArticleLibrary()
    @StateObject private var journal = Journal()
    @StateObject private var sync = LocalHealthSync()
    @AppStorage("app-theme") private var theme = "system"
    @AppStorage("app-deep-mind") private var deepMind = false
    @AppStorage("app-deep-style") private var deepStyle = "미드나잇"
    init() { CareAppShortcuts.updateAppShortcutParameters() }
    var body: some Scene {
        WindowGroup {
            RootView().modifier(CareThemeSurface()).preferredColorScheme(deepMind ? .dark : theme == "dark" ? .dark : theme == "light" ? .light : nil).environmentObject(journal).environmentObject(sync).environmentObject(shortcuts).environmentObject(articles).environmentObject(medications).tint(deepMind ? CareAppearance.accent(for: deepStyle) : Palette.blue).environment(\.locale, Locale(identifier: "ko_KR"))
                .onOpenURL { let accepted = shortcuts.open($0); print("OnCare link received at app root: accepted=\(accepted)") }
                .alert("온케어 안내", isPresented: Binding(get: { journal.notice != nil }, set: { if !$0 { journal.notice = nil } })) { Button("확인") { journal.notice = nil } } message: { Text(journal.notice ?? "") }
        }
    }
}
