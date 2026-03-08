import ConfigurableKit
import SnapKit
import UIKit

class ConfigurableInfoView: ConfigurableView {
    var valueLabel: EasyHitButton {
        contentView as! EasyHitButton
    }

    private var onTapBlock: ((ConfigurableInfoView) -> Void) = { _ in }

    override init() {
        super.init()
        valueLabel.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        valueLabel.titleLabel?.numberOfLines = 3
        valueLabel.titleLabel?.lineBreakMode = .byTruncatingMiddle
        valueLabel.titleLabel?.textAlignment = .right
        valueLabel.contentHorizontalAlignment = .right
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        verticalStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        verticalStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueLabel.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        valueLabel.snp.makeConstraints {
            $0.top.bottom.equalTo(contentContainer)
            $0.leading.greaterThanOrEqualTo(contentContainer)
            $0.trailing.equalTo(contentContainer)
        }
        contentContainer.snp.makeConstraints {
            $0.width.lessThanOrEqualTo(self).multipliedBy(0.5)
        }
    }

    func configure(value: String, isDestructive: Bool = false) {
        let attrString = NSAttributedString(string: value, attributes: [
            .foregroundColor: isDestructive ? UIColor.systemRed : UIColor.tintColor,
            .font: UIFont.systemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
                weight: .semibold
            ),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ])
        valueLabel.setAttributedTitle(attrString, for: .normal)
    }

    @discardableResult
    func setTapBlock(_ block: @escaping (ConfigurableInfoView) -> Void) -> Self {
        onTapBlock = block
        return self
    }

    @objc private func tapped() {
        onTapBlock(self)
    }

    override class func createContentView() -> UIView {
        EasyHitButton()
    }

    func use(menu: @escaping () -> [UIMenuElement]) {
        valueLabel.removeTarget(self, action: #selector(tapped), for: .touchUpInside)
        valueLabel.showsMenuAsPrimaryAction = true
        valueLabel.menu = .init(children: [
            UIDeferredMenuElement.uncached { completion in
                completion(menu())
            },
        ])
    }
}
