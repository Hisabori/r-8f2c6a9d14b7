import SwiftUI
import UIKit

/// Shared app surfaces. Mode changes never recreate the journal or discard open forms.
enum CareAppearance {
    static var enabled: Bool { UserDefaults.standard.bool(forKey: "app-deep-mind") }
    static func accent(for style: String) -> Color { Color(uiColor: accentUI(style)) }
    static var accent: Color { accent(for: UserDefaults.standard.string(forKey: "app-deep-style") ?? "미드나잇") }
    static func accentUI(_ style: String) -> UIColor { style == "라일락" ? UIColor(red: 0.78, green: 0.69, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.63, blue: 0.79, alpha: 1) }
    static func surfaceUI(card: Bool, style: String) -> UIColor {
        let rgb: (CGFloat, CGFloat, CGFloat) = style == "로즈" ? (0.13, 0.045, 0.085) : style == "라일락" ? (0.085, 0.055, 0.14) : (0.045, 0.03, 0.065)
        let lift: CGFloat = card ? 0.055 : 0
        return UIColor(red: rgb.0 + lift, green: rgb.1 + lift, blue: rgb.2 + lift, alpha: 1)
    }
    static var background: Color { dynamicSurface(card: false) }
    static var card: Color { dynamicSurface(card: true) }
    private static func dynamicSurface(card: Bool) -> Color {
        Color(uiColor: UIColor { traits in
            guard enabled else { return (card ? UIColor.secondarySystemGroupedBackground : UIColor.systemGroupedBackground).resolvedColor(with: traits) }
            return surfaceUI(card: card, style: UserDefaults.standard.string(forKey: "app-deep-style") ?? "미드나잇")
        })
    }
}

struct CareThemeSurface: ViewModifier {
    @AppStorage("app-deep-mind") private var enabled = false
    @AppStorage("app-deep-style") private var style = "미드나잇"
    func body(content: Content) -> some View {
        content.scrollContentBackground(enabled ? .hidden : .automatic)
            .background(enabled ? Color(uiColor: CareAppearance.surfaceUI(card: false, style: style)) : .clear)
            .toolbarBackground(enabled ? Color(uiColor: CareAppearance.surfaceUI(card: true, style: style)) : CareAppearance.card, for: .navigationBar, .tabBar)
            .toolbarBackground(enabled ? .visible : .automatic, for: .navigationBar, .tabBar)
    }
}
