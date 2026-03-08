import UIKit

MainActor.assumeIsolated {
    _ = UIApplicationMain(
        CommandLine.argc,
        CommandLine.unsafeArgv,
        nil,
        NSStringFromClass(AppDelegate.self)
    )

    fatalError("UIApplicationMain returned unexpectedly.")
}
