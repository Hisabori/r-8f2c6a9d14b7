import SwiftUI
import CryptoResearchKit

enum NativeServiceDestination: String, Identifiable { case pet,travel,investment,ticker;var id: String { rawValue }
    static func parse(_ url: URL) -> NativeServiceDestination? {
        guard url.absoluteString.utf8.count <= 160,let c = URLComponents(url:url,resolvingAgainstBaseURL:false),c.scheme == "caresuite-care",c.host == "service",c.user == nil,c.password == nil,c.port == nil,c.query == nil,c.fragment == nil,
              c.percentEncodedPath == c.path,c.path.hasPrefix("/"),let result = NativeServiceDestination(rawValue:String(c.path.dropFirst())) else { return nil }
        return result
    }
}
struct NativeServiceRequest { let id = UUID();let destination: NativeServiceDestination }
@MainActor final class NativeServiceRouter: ObservableObject {
    static let shared = NativeServiceRouter()
    @Published private(set) var pending: NativeServiceRequest?
    func open(_ destination: NativeServiceDestination) { pending = NativeServiceRequest(destination:destination) }
    func complete(_ id: UUID) { if pending?.id == id { pending = nil } }
    static func route(_ url: URL) -> Bool {
        if let destination = NativeServiceDestination.parse(url) {
            if let health = CareShortcutRouter.shared.pending { CareShortcutRouter.shared.complete(health.id) }
            shared.open(destination);return true
        }
        guard CareDestination.parse(url) != nil else { return false }
        if let request = shared.pending { shared.complete(request.id) }
        return CareShortcutRouter.shared.open(url)
    }
}
struct NativeServiceSheet: View {
    let destination: NativeServiceDestination
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                switch destination {
                case .pet: NativePetView()
                case .travel: NativeTravelView()
                case .investment: NativeInvestmentView()
                case .ticker: TickerResearchView()
                }
            }.toolbar { ToolbarItem(placement:.confirmationAction) { Button("닫기") { dismiss() } } }
        }
    }
}
