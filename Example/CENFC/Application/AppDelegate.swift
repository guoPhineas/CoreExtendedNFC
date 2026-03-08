@_exported import CoreExtendedNFC
import UIKit

@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate {
    override init() {
        super.init()
        PrintRedirection.start()
        NFCLogConfiguration.logger = AppNFCLogBridge()
    }

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
