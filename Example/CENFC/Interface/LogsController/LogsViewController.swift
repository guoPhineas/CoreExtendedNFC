import ConfigurableKit
import UIKit

@MainActor
final class LogsViewController: StackScrollController {
    init() {
        super.init(nibName: nil, bundle: nil)
        title = String(localized: "Logs")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDismissKeyboardOnTap()
        view.backgroundColor = AppTheme.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            primaryAction: UIAction { [weak self] _ in
                self?.shareLogs()
            },
            menu: UIMenu(children: [
                UIAction(
                    title: String(localized: "Share Logs"),
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { [weak self] _ in
                    self?.shareLogs()
                },
                UIAction(
                    title: String(localized: "Clear"),
                    image: UIImage(systemName: "trash"),
                    attributes: [.destructive]
                ) { [weak self] _ in
                    AppLogStore.shared.clear()
                    self?.rebuild()
                },
            ])
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLogsChange),
            name: .appLogsDidChange,
            object: AppLogStore.shared
        )
    }

    override func setupContentViews() {
        super.setupContentViews()
        rebuild()
    }

    @objc private func handleLogsChange() {
        rebuild()
    }

    private func rebuild() {
        for sub in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }

        stackView.addArrangedSubview(SeparatorView())

        guard !AppLogStore.shared.entries.isEmpty else {
            let empty = makeNotice(String(localized: "No logs yet. Scan a tag and the protocol trace will appear here."))
            stackView.addArrangedSubviewWithMargin(empty) { insets in
                insets.top = 18
                insets.bottom = 18
            }
            AppTheme.normalizeTypography(in: stackView)
            return
        }

        for entry in AppLogStore.shared.entries.prefix(100) {
            let view = LogEntryView(entry: entry)
            stackView.addArrangedSubviewWithMargin(view) { insets in
                insets.top = 18
                insets.bottom = 18
            }
            stackView.addArrangedSubview(SeparatorView())
        }

        AppTheme.normalizeTypography(in: stackView)
    }

    private func makeNotice(_ text: String) -> UIView {
        let label = UILabel()
        label.font = AppTheme.unifiedFont()
        label.textColor = AppTheme.secondaryText
        label.numberOfLines = 0
        label.text = text
        return label
    }

    private func shareLogs() {
        do {
            let result = try makeShareItems()
            presentSheet(items: result.items, cleanup: result.cleanup)
        } catch {
            presentSheet(items: [AppLogStore.shared.exportText()])
        }
    }

    private func presentSheet(items: [Any], cleanup: (() -> Void)? = nil) {
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = ac.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        ac.completionWithItemsHandler = { _, _, _, _ in cleanup?() }
        present(ac, animated: true)
    }

    private func makeShareItems() throws -> (items: [Any], cleanup: () -> Void) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreExtendedNFC-Logs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let urls: [Any] = try AppLogStore.shared.exportArtifacts().map { artifact in
            let url = directory.appendingPathComponent(artifact.suggestedFilename)
            try artifact.data.write(to: url, options: .atomic)
            return url
        }
        return (urls, { try? FileManager.default.removeItem(at: directory) })
    }
}

private final class LogEntryView: UIView {
    init(entry: AppLogEntry) {
        super.init(frame: .zero)

        let sourceLabel = UILabel()
        sourceLabel.font = AppTheme.unifiedFont(weight: .semibold)
        sourceLabel.textColor = color(for: entry.level)
        sourceLabel.text = "\(entry.source) · \(entry.level.rawValue)"

        let messageLabel = UILabel()
        messageLabel.font = AppTheme.unifiedFont()
        messageLabel.numberOfLines = 0
        messageLabel.text = entry.message

        let timeLabel = UILabel()
        timeLabel.font = AppTheme.unifiedFont(monospaced: true)
        timeLabel.textColor = AppTheme.secondaryText
        timeLabel.text = DateFormatter.logTimestamp.string(from: entry.timestamp)

        let stack = UIStackView(arrangedSubviews: [sourceLabel, messageLabel, timeLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func color(for level: AppLogLevel) -> UIColor {
        switch level {
        case .debug:
            AppTheme.secondaryText
        case .info:
            AppTheme.accent
        case .warning:
            AppTheme.warning
        case .error:
            AppTheme.error
        }
    }
}

private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}
