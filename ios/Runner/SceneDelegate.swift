import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene:UIScene,willConnectTo session:UISceneSession,options connectionOptions:UIScene.ConnectionOptions){
    super.scene(scene,willConnectTo:session,options:connectionOptions)
    if let url=connectionOptions.urlContexts.first?.url,url.scheme=="caresuite-care" {NativeSuitePresenter.pendingCareURL=url}
    if let shortcut=connectionOptions.shortcutItem {_ = NativeSuitePresenter.shortcut(shortcut.type)}
  }
  override func scene(_ scene:UIScene,openURLContexts contexts:Set<UIOpenURLContext>){
    super.scene(scene,openURLContexts:contexts)
    if let url=contexts.first?.url {NativeSuitePresenter.receive(url)}
  }

  override func windowScene(_ windowScene:UIWindowScene,performActionFor shortcutItem:UIApplicationShortcutItem,completionHandler:@escaping(Bool)->Void){completionHandler(NativeSuitePresenter.shortcut(shortcutItem.type))}
  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    if #available(iOS 16.2, *) {
      Task { @MainActor in BarkLiveController.shared.end(result: { _ in }) }
    }
  }
}
