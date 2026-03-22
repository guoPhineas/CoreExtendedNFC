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
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppBootstrap.preloadPersistentStores()
        return true
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

@MainActor
private enum AppBootstrap {
    static func preloadPersistentStores() {
        _ = ScanStore.shared
        _ = DumpStore.shared
        _ = NDEFStore.shared
        _ = PassportStore.shared
    }
}
