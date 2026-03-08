import ConfigurableKit
import UIKit

enum AppTheme {
    static let baseTextPointSize = UIFont.preferredFont(forTextStyle: .body).pointSize
    static let accent = UIColor(named: "AccentColor") ?? .systemOrange
    static let success = UIColor.systemGreen
    static let warning = UIColor.systemOrange
    static let error = UIColor.systemRed
    static let background = UIColor.systemGroupedBackground
    static let surface = UIColor.secondarySystemGroupedBackground
    static let tertiarySurface = UIColor.tertiarySystemGroupedBackground
    static let secondaryText = UIColor.secondaryLabel

    static func unifiedFont(weight: UIFont.Weight = .regular, monospaced: Bool = false) -> UIFont {
        if monospaced {
            return .monospacedSystemFont(ofSize: baseTextPointSize, weight: weight)
        }
        return .systemFont(ofSize: baseTextPointSize, weight: weight)
    }

    static func normalizeTypography(in view: UIView) {
        if let configurable = view as? ConfigurableSectionHeaderView {
            configurable.titleLabel.font = unifiedFont(weight: .bold)
        } else if let configurable = view as? ConfigurableView {
            configurable.titleLabel.font = unifiedFont(weight: .bold)
            configurable.descriptionLabel.font = unifiedFont()
        } else if let label = view as? UILabel {
            label.font = normalized(label.font)
        } else if let textField = view as? UITextField {
            textField.font = normalized(textField.font)
        } else if let textView = view as? UITextView {
            textView.font = normalized(textView.font)
        } else if let button = view as? UIButton {
            button.titleLabel?.font = normalized(button.titleLabel?.font)
        }

        for subview in view.subviews {
            normalizeTypography(in: subview)
        }
    }

    private static func normalized(_ font: UIFont?) -> UIFont {
        guard let font else {
            return unifiedFont()
        }
        let isMonospaced = font.fontName.localizedCaseInsensitiveContains("mono")
            || font.fontName.localizedCaseInsensitiveContains("menlo")
            || font.fontName.localizedCaseInsensitiveContains("courier")
        let traits = font.fontDescriptor.symbolicTraits
        let weight: UIFont.Weight = traits.contains(.traitBold) ? .semibold : .regular
        return unifiedFont(weight: weight, monospaced: isMonospaced)
    }
}
