import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // custom scene delegate to handle carplay now playing template
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let controller = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
    controller.loadDefaultSplashScreenView()
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = controller
    self.window = window
    window.makeKeyAndVisible()
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
