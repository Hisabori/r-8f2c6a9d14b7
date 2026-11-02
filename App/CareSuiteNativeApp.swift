import SwiftUI
import CryptoResearchKit
@main struct CareSuiteNativeApp: App {
    @UIApplicationDelegateAdaptor(CareShortcutAppDelegate.self) private var appDelegate
    @StateObject private var shortcuts = CareShortcutRouter.shared
    @StateObject private var medications = MedicationStore()
    @StateObject private var articles = ArticleLibrary()
    @StateObject private var journal = Journal()
    @StateObject private var sync = LocalHealthSync()
    @StateObject private var pets = NativePetStore()
    @StateObject private var travel = NativeTravelStore()
    @StateObject private var investment = NativeInvestmentSession()
    @StateObject private var wellbeing = WellbeingResearchStore()
    @Environment(\.scenePhase) private var phase
    @AppStorage("native-research-live") private var researchLive = false
    @AppStorage("app-theme") private var theme = "system"
    @AppStorage("app-deep-mind") private var deepMind = false
    @AppStorage("app-deep-style") private var deepStyle = "미드나잇"
    init() { CareAppShortcuts.updateAppShortcutParameters() }
    var body: some Scene {
        WindowGroup {
            RootView().modifier(CareThemeSurface()).preferredColorScheme(deepMind ? .dark : theme == "dark" ? .dark : theme == "light" ? .light : nil).environmentObject(journal).environmentObject(sync).environmentObject(shortcuts).environmentObject(articles).environmentObject(medications).environmentObject(pets).environmentObject(travel).environmentObject(investment).environmentObject(wellbeing).tint(deepMind ? CareAppearance.accent(for: deepStyle) : Palette.blue).environment(\.locale, Locale(identifier: "ko_KR"))
                .onOpenURL { let accepted = NativeServiceRouter.route($0); print("OnCare link received at app root: accepted=\(accepted)") }
                .task { NativeLiveStatus.shared.recover(petRunning:pets.recording,researchRunning:investment.researchBusy,researchEnabled:researchLive) }
                .onChange(of:investment.researchBusy) { NativeLiveStatus.shared.research(active:$0 && phase == .active,enabled:researchLive && phase == .active) }
                .onChange(of:researchLive) { NativeLiveStatus.shared.research(active:investment.researchBusy && phase == .active,enabled:$0 && phase == .active) }
                .onChange(of:phase) { if $0 == .background { investment.cancelResearch() };NativeLiveStatus.shared.research(active:$0 == .active && investment.researchBusy,enabled:researchLive && $0 == .active) }
                .alert("온케어 안내", isPresented: Binding(get: { journal.notice != nil }, set: { if !$0 { journal.notice = nil } })) { Button("확인") { journal.notice = nil } } message: { Text(journal.notice ?? "") }
        }
    }
}
