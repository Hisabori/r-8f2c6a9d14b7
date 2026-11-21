import SwiftUI

@main struct TrainPreviewApp:App {
    var body:some Scene {WindowGroup{NavigationStack{
        RideMotionView().safeAreaInset(edge:.top){Text("OnCare 전철 미리보기 · 통합 앱과 별도").font(.caption).foregroundStyle(.secondary).padding(8).frame(maxWidth:.infinity).background(.ultraThinMaterial)}
    }}}
}

// Standalone host support only; the shared production components remain unchanged.
enum PublicTransitError:Error {case invalidInput,invalidResponse}
enum TrainPhaseStrip {
    static func index(_ code:String)->Int? {switch code {case "3","4","5":return 0;case "0":return 1;case "1":return 2;case "2":return 3;default:return nil}}
}
