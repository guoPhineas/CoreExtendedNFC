import ConfigurableKit
import UIKit

extension StackScrollController {
    /// Re-pins scrollView top to view.topAnchor so content extends
    /// under the navigation bar, restoring the translucent blur effect.
    func enableExtendedEdge() {
        for constraint in view.constraints {
            guard constraint.firstItem === scrollView,
                  constraint.firstAnchor == scrollView.topAnchor,
                  constraint.secondItem === view.safeAreaLayoutGuide,
                  constraint.secondAnchor == view.safeAreaLayoutGuide.topAnchor
            else { continue }
            constraint.isActive = false
            break
        }
        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    }
}
