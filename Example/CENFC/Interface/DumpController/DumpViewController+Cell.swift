import ConfigurableKit
import CoreExtendedNFC
import SnapKit
import UIKit

extension DumpViewController {
    class DumpRecordCell: UITableViewCell {
        static let reuseIdentifier = "DumpRecordCell"

        private let content = ConfigurablePageView { nil }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            backgroundColor = .clear
            clipsToBounds = true
            tintColor = .systemBlue
            content.isUserInteractionEnabled = false

            let wrapper = AutoLayoutMarginView(content)
            contentView.addSubview(wrapper)
            wrapper.snp.makeConstraints { $0.edges.equalToSuperview() }

            let editingBackground = UIView()
            editingBackground.backgroundColor = .systemGray5
            multipleSelectionBackgroundView = editingBackground
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }()

        func update(with record: DumpRecord) {
            let dateString = Self.dateFormatter.string(from: record.date)
            content.configure(icon: UIImage(systemName: iconName(for: String(describing: record.dump.cardInfo.type.family))))
            content.configure(title: String.LocalizationValue(stringLiteral: record.dump.cardInfo.type.description))
            content.configure(description: String.LocalizationValue(stringLiteral: "\(dateString) · \(record.dump.summary.technicalSummary)"))
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            preservesSuperviewLayoutMargins = false
            separatorInset = .zero
            layoutMargins = .zero
        }

        private func iconName(for family: String) -> String {
            switch family {
            case "mifareUltralight", "ntag": "creditcard"
            case "mifareClassic": "creditcard.trianglebadge.exclamationmark"
            case "mifarePlus": "creditcard.and.123"
            case "mifareDesfire": "lock.shield"
            case "type4": "doc.text"
            case "felica": "wave.3.right"
            case "iso15693": "barcode"
            case "passport": "person.text.rectangle"
            case "jewelTopaz": "diamond"
            case "iso14443B": "rectangle.on.rectangle"
            default: "questionmark.circle"
            }
        }
    }
}
