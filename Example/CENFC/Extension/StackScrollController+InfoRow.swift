import ConfigurableKit
import SPIndicator
import UIKit

extension StackScrollController {
    func addInfoRow(
        icon: String,
        title: String,
        description: String = "",
        value: String,
        isDestructive: Bool = false
    ) {
        let infoView = ConfigurableInfoView()
        infoView.configure(icon: UIImage(systemName: icon))
        infoView.configure(title: String.LocalizationValue(stringLiteral: title))
        infoView.configure(description: String.LocalizationValue(stringLiteral: description))
        infoView.configure(value: value, isDestructive: isDestructive)
        infoView.setTapBlock { _ in
            UIPasteboard.general.string = value
            SPIndicator.present(
                title: String(localized: "Copied"),
                preset: .done,
                haptic: .success
            )
        }
        stackView.addArrangedSubviewWithMargin(infoView)
        stackView.addArrangedSubview(SeparatorView())
    }

    func showCopiedBanner() {
        SPIndicator.present(
            title: String(localized: "Copied"),
            preset: .done,
            haptic: .success
        )
    }
}
