import UIKit

extension UIViewController {
    /// Adds a tap gesture recognizer to the view that dismisses the keyboard
    /// when the user taps outside of text input fields.
    ///
    /// Call this in `viewDidLoad()` for any view controller that contains
    /// text fields or text views.
    func setupDismissKeyboardOnTap() {
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboardFromTap)
        )
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboardFromTap() {
        view.endEditing(true)
    }
}
