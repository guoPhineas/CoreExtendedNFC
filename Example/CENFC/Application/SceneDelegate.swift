import UIKit

@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene, willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        defer {
            window.makeKeyAndVisible()
            self.window = window
        }
        window.rootViewController = TabBarController()

        if let urlContext = connectionOptions.urlContexts.first {
            DispatchQueue.main.async { [weak self] in
                self?.handleOpenURL(urlContext.url)
            }
        }
    }

    func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            handleOpenURL(context.url)
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard url.pathExtension.lowercased() == "cenfc" else { return }
        guard let tabBar = window?.rootViewController as? TabBarController,
              let nav = tabBar.viewControllers?.first as? UINavigationController,
              let scanner = nav.viewControllers.first as? ScannerViewController
        else { return }
        tabBar.selectedIndex = 0
        nav.popToRootViewController(animated: false)
        scanner.importFile(at: url)
    }
}
