import UIKit
import CareHealthKit
import CryptoResearchKit
@MainActor enum NativeSuitePresenter {
    static weak var current:UIViewController?
    static var hosts:[String:UIViewController]=[:]
    static var kind=""
    static var pendingCareURL:URL?
    static func open(_ module:String)->Bool {
        guard ["health","crypto"].contains(module),current==nil,
              let scene=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).first(where:{$0.activationState == .foregroundActive}),
              let root=scene.windows.first(where:{$0.isKeyWindow})?.rootViewController,root.presentedViewController==nil else{return false}
        let close:()->Void={current?.dismiss(animated:true){current=nil;kind="";flushPending()}}
        let host=hosts[module] ?? (module=="health" ? SuperCareBridge.controller(close:close):SuperCryptoBridge.controller(close:close))
        hosts[module]=host
        host.modalPresentationStyle = .fullScreen;current=host;kind=module;root.present(host,animated:true);return true
    }
    static func shortcut(_ type:String)->Bool{guard type.hasPrefix("app.oncare.open."),let url=URL(string:"caresuite-care://open/"+String(type.dropFirst("app.oncare.open.".count))),SuperCareBridge.handle(url) else{return false};receive(url);return true}
    static func receive(_ url:URL){guard url.scheme=="caresuite-care" else{return};pendingCareURL=url;flushPending()}
    static func flushPending(){guard let url=pendingCareURL else{return};if kind=="health" {if SuperCareBridge.handle(url){pendingCareURL=nil};return};guard current==nil else{return};if SuperCareBridge.handle(url),open("health"){pendingCareURL=nil}}
}
