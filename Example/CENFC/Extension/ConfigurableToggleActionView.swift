import ConfigurableKit
import UIKit

class ConfigurableToggleActionView: ConfigurableView {
    var switchView: UISwitch {
        contentView as! UISwitch
    }

    var boolValue: Bool = false {
        didSet {
            guard switchView.isOn != boolValue else { return }
            switchView.setOn(boolValue, animated: false)
        }
    }

    var actionBlock: ((Bool) -> Void) = { _ in }

    override init() {
        super.init()
        switchView.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
    }

    override open class func createContentView() -> UIView {
        UISwitch()
    }

    @objc open func valueChanged() {
        let newValue = switchView.isOn
        guard boolValue != newValue else { return }
        boolValue = newValue
        actionBlock(boolValue)
    }
}
