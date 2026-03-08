import ConfigurableKit
import CoreExtendedNFC
import SnapKit
import UIKit

extension NDEFViewController {
    class NDEFRecordCell: UITableViewCell {
        static let reuseIdentifier = "NDEFRecordCell"

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

        func update(with record: NDEFDataRecord) {
            content.configure(icon: UIImage(systemName: iconName(for: record)))
            content.configure(title: String.LocalizationValue(stringLiteral: record.name))
            content.configure(description: String.LocalizationValue(stringLiteral: record.displayValue))
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            preservesSuperviewLayoutMargins = false
            separatorInset = .zero
            layoutMargins = .zero
        }

        private func iconName(for record: NDEFDataRecord) -> String {
            guard let parsed = record.parsedRecord else { return "circle.dashed" }
            switch parsed.parsedPayload {
            case .empty: return "circle.dashed"
            case .text: return "doc.plaintext"
            case .uri: return "link"
            case .smartPoster: return "rectangle.and.text.magnifyingglass"
            case .mime: return "doc.richtext"
            case .external: return "puzzlepiece.extension"
            case .unknown: return "questionmark.circle"
            }
        }
    }
}
