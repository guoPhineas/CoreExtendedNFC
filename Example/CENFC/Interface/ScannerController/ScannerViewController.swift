import CoreExtendedNFC
import SnapKit
import SPIndicator
import Then
import UIKit
import UniformTypeIdentifiers

final class ScannerViewController: UIViewController {
    nonisolated enum Section { case main }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var dataSource: UITableViewDiffableDataSource<Section, UUID>!

    private lazy var scanBarButton: UIBarButtonItem = {
        let protocolActions: [UIMenuElement] = [
            UIAction(
                title: String(localized: "All Protocols"),
                image: UIImage(systemName: "antenna.radiowaves.left.and.right")
            ) { [weak self] _ in self?.performScan(targets: [.all]) },
        ]

        let specificProtocols = UIMenu(options: .displayInline, children: [
            UIAction(
                title: String(localized: "ISO 14443"),
                image: UIImage(systemName: "wave.3.right")
            ) { [weak self] _ in self?.performScan(targets: [.iso14443]) },
            UIAction(
                title: String(localized: "ISO 18092"),
                image: UIImage(systemName: "dot.radiowaves.right")
            ) { [weak self] _ in self?.performScan(targets: [.iso18092]) },
            UIAction(
                title: String(localized: "ISO 15693"),
                image: UIImage(systemName: "barcode")
            ) { [weak self] _ in self?.performScan(targets: [.iso15693]) },
        ])

        let importAction = UIMenu(options: .displayInline, children: [
            UIAction(
                title: String(localized: "Import from File"),
                image: UIImage(systemName: "square.and.arrow.down")
            ) { [weak self] _ in self?.presentImportPicker() },
        ])

        let sortMenu = UIMenu(
            title: String(localized: "Sort By"),
            image: UIImage(systemName: "arrow.up.arrow.down"),
            children: [
                UIAction(
                    title: String(localized: "Date (Newest First)"),
                    image: UIImage(systemName: "calendar")
                ) { [weak self] _ in
                    ScanStore.shared.sort { $0.date > $1.date }
                    self?.reloadSnapshot()
                },
                UIAction(
                    title: String(localized: "Date (Oldest First)"),
                    image: UIImage(systemName: "calendar.badge.clock")
                ) { [weak self] _ in
                    ScanStore.shared.sort { $0.date < $1.date }
                    self?.reloadSnapshot()
                },
                UIAction(
                    title: String(localized: "Card Type"),
                    image: UIImage(systemName: "textformat")
                ) { [weak self] _ in
                    ScanStore.shared.sort { $0.cardInfo.type.description.localizedCaseInsensitiveCompare($1.cardInfo.type.description) == .orderedAscending }
                    self?.reloadSnapshot()
                },
                UIAction(
                    title: String(localized: "UID"),
                    image: UIImage(systemName: "number")
                ) { [weak self] _ in
                    ScanStore.shared.sort { $0.cardInfo.uid.hexString < $1.cardInfo.uid.hexString }
                    self?.reloadSnapshot()
                },
                UIAction(
                    title: String(localized: "AID"),
                    image: UIImage(systemName: "creditcard")
                ) { [weak self] _ in
                    ScanStore.shared.sort {
                        ($0.cardInfo.initialSelectedAID ?? "").localizedCaseInsensitiveCompare($1.cardInfo.initialSelectedAID ?? "") == .orderedAscending
                    }
                    self?.reloadSnapshot()
                },
            ]
        )

        let sortSection = UIMenu(options: .displayInline, children: [sortMenu])

        let scanMenu = UIMenu(children: protocolActions + [specificProtocols, importAction, sortSection])

        return UIBarButtonItem(
            image: UIImage(systemName: "plus.viewfinder"),
            primaryAction: UIAction { [weak self] _ in
                self?.performScan(targets: [.all])
            },
            menu: scanMenu
        )
    }()

    private lazy var doneBarButton = UIBarButtonItem(
        image: UIImage(systemName: "checkmark.circle"),
        style: .plain,
        target: self,
        action: #selector(exitEditingMode)
    )

    private lazy var deleteBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(deleteSelected)
        )
        button.tintColor = .systemRed
        return button
    }()

    private lazy var exportSelectedBarButton = UIBarButtonItem(
        image: UIImage(systemName: "square.and.arrow.up"),
        style: .plain,
        target: self,
        action: #selector(exportSelected)
    )

    private var currentSearchText: String {
        navigationItem.searchController?.searchBar.text ?? ""
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDismissKeyboardOnTap()
        view.backgroundColor = .systemBackground

        setupTableView()
        setupDataSource()
        setupNavBar()
        setupSearch()
        setupDropInteraction()
        reloadSnapshot()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSnapshot()
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.do {
            $0.separatorStyle = .singleLine
            $0.separatorInset = .zero
            $0.backgroundColor = .clear
            $0.delegate = self
            $0.dragDelegate = self
            $0.dropDelegate = self
            $0.dragInteractionEnabled = true
            $0.allowsMultipleSelectionDuringEditing = true
            $0.register(ScanRecordCell.self, forCellReuseIdentifier: ScanRecordCell.reuseIdentifier)
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func setupDataSource() {
        dataSource = .init(tableView: tableView) { tableView, indexPath, recordID in
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ScanRecordCell.reuseIdentifier, for: indexPath
            ) as! ScanRecordCell
            if let record = ScanStore.shared.record(for: recordID) {
                cell.update(with: record)
            }
            return cell
        }
        dataSource.defaultRowAnimation = .fade
    }

    private func setupNavBar() {
        navigationItem.rightBarButtonItem = scanBarButton
    }

    // MARK: - Editing state (two-finger pan enters editing)

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        updateEditingNavBar()
    }

    @objc private func exitEditingMode() {
        setEditing(false, animated: true)
    }

    private func updateEditingNavBar() {
        if tableView.isEditing {
            let hasSelection = (tableView.indexPathsForSelectedRows?.count ?? 0) > 0
            navigationItem.setLeftBarButton(hasSelection ? deleteBarButton : nil, animated: true)
            navigationItem.setRightBarButtonItems(
                hasSelection ? [doneBarButton, exportSelectedBarButton] : [doneBarButton],
                animated: true
            )
        } else {
            navigationItem.setLeftBarButton(nil, animated: true)
            navigationItem.setRightBarButtonItems([scanBarButton], animated: true)
        }
    }

    private func selectedRecords() -> [ScanRecord] {
        guard let indexPaths = tableView.indexPathsForSelectedRows else { return [] }
        return indexPaths.compactMap { indexPath in
            guard let id = dataSource.itemIdentifier(for: indexPath) else { return nil }
            return ScanStore.shared.record(for: id)
        }
    }

    @objc private func deleteSelected() {
        let records = selectedRecords()
        guard !records.isEmpty else { return }

        let alert = UIAlertController(
            title: String(localized: "Delete \(records.count) Record(s)?"),
            message: String(localized: "This action cannot be undone."),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: String(localized: "Delete"), style: .destructive) { [weak self] _ in
            for record in records {
                ScanStore.shared.remove(id: record.id)
            }
            self?.reloadSnapshot()
            self?.setEditing(false, animated: true)
        })
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        alert.popoverPresentationController?.sourceView = view
        present(alert, animated: true)
    }

    @objc private func exportSelected() {
        let records = selectedRecords()
        guard !records.isEmpty else { return }

        do {
            let fileURLs = try records.map { try CardDocument.exportToFile($0) }
            let activity = UIActivityViewController(activityItems: fileURLs, applicationActivities: nil)
            activity.popoverPresentationController?.barButtonItem = exportSelectedBarButton
            present(activity, animated: true)
        } catch {
            presentErrorAlert(for: error)
        }
    }

    private func setupSearch() {
        let search = UISearchController(searchResultsController: nil).then {
            $0.delegate = self
            $0.searchBar.placeholder = String(localized: "Search by card type or UID")
            $0.searchBar.autocapitalizationType = .none
            $0.searchBar.autocorrectionType = .no
            $0.searchBar.delegate = self
            $0.obscuresBackgroundDuringPresentation = false
            $0.hidesNavigationBarDuringPresentation = false
        }
        navigationItem.searchController = search
        navigationItem.preferredSearchBarPlacement = .stacked
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    private func setupDropInteraction() {
        let dropInteraction = UIDropInteraction(delegate: self)
        view.addInteraction(dropInteraction)
    }

    // MARK: - Data Source

    func reloadSnapshot() {
        let query = currentSearchText
        let filtered = ScanStore.shared.records.filter { record in
            query.isEmpty
                || record.cardInfo.type.description.localizedCaseInsensitiveContains(query)
                || record.cardInfo.uid.hexString.localizedCaseInsensitiveContains(query)
                || record.cardInfo.uid.compactHexString.localizedCaseInsensitiveContains(query)
        }
        var snapshot = NSDiffableDataSourceSnapshot<Section, UUID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(filtered.map(\.id))
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: - Scan

    private func performScan(targets: [NFCSessionManager.PollingTarget]) {
        Task {
            let manager = NFCSessionManager()
            do {
                let (coarseInfo, transport) = try await manager.scan(for: targets)
                let refinedInfo = try await CoreExtendedNFC.refineCardInfo(coarseInfo, transport: transport)
                manager.setAlertMessage(refinedInfo.type.description)
                manager.invalidate()
                handleNewScan(ScanRecord(cardInfo: refinedInfo))
            } catch is CancellationError {
                return
            } catch {
                manager.invalidate()
                if !presentNFCErrorAlertIfNeeded(for: error) {
                    presentErrorAlert(for: error)
                }
            }
        }
    }

    private func handleNewScan(_ record: ScanRecord) {
        if let existing = ScanStore.shared.record(withUID: record.cardInfo.uid) {
            promptDuplicateScan(record, existingID: existing.id)
        } else {
            ScanStore.shared.add(record)
            reloadSnapshot()
            navigationController?.pushViewController(
                CardDetailViewController(record: record), animated: true
            )
        }
    }

    private func promptDuplicateScan(_ record: ScanRecord, existingID: UUID) {
        let alert = UIAlertController(
            title: String(localized: "Card Already Exists"),
            message: String(localized: "A card with this UID already exists in the history. What would you like to do?"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Overwrite"), style: .destructive) { [weak self] _ in
            ScanStore.shared.replace(existingID, with: record)
            self?.reloadSnapshot()
            self?.navigationController?.pushViewController(
                CardDetailViewController(record: record), animated: true
            )
        })
        alert.addAction(UIAlertAction(title: String(localized: "Save as New"), style: .default) { [weak self] _ in
            ScanStore.shared.add(record)
            self?.reloadSnapshot()
            self?.navigationController?.pushViewController(
                CardDetailViewController(record: record), animated: true
            )
        })
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Import

    private func presentImportPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.cenfc, .propertyList])
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    func importFile(at url: URL) {
        do {
            let envelope = try CardDocument.importEnvelope(from: url)
            let record = envelope.scanRecord
            if let existing = ScanStore.shared.record(withUID: record.cardInfo.uid) {
                ScanStore.shared.replace(existing.id, with: record)
            } else {
                ScanStore.shared.add(record)
            }
            reloadSnapshot()

            if let dumpRecord = envelope.dumpRecord, dumpRecord.hasMemoryData {
                promptSaveDump(dumpRecord)
            }
        } catch {
            presentErrorAlert(for: error)
        }
    }

    private func promptSaveDump(_ dumpRecord: DumpRecord) {
        let alert = UIAlertController(
            title: String(localized: "Dump Data Detected"),
            message: String(localized: "This file contains memory dump data (\(dumpRecord.dump.summary.technicalSummary)). Save to Dump store?"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Save"), style: .default) { _ in
            DumpStore.shared.add(dumpRecord)
        })
        alert.addAction(UIAlertAction(title: String(localized: "Skip"), style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Export

    private func exportRecord(_ record: ScanRecord) {
        do {
            let fileURL = try CardDocument.exportToFile(record)
            let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            activity.popoverPresentationController?.sourceView = view
            present(activity, animated: true)
        } catch {
            presentErrorAlert(for: error)
        }
    }

    // MARK: - Errors

    private func presentErrorAlert(for error: Error) {
        let alert = UIAlertController(
            title: String(localized: "Error"),
            message: String(describing: error),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate

extension ScannerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateEditingNavBar()
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        guard let recordID = dataSource.itemIdentifier(for: indexPath),
              let record = ScanStore.shared.record(for: recordID)
        else { return }
        navigationController?.pushViewController(
            CardDetailViewController(record: record), animated: true
        )
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt _: IndexPath) {
        if tableView.isEditing {
            updateEditingNavBar()
        }
    }

    func tableView(
        _: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard !tableView.isEditing else { return nil }
        guard let recordID = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let delete = UIContextualAction(style: .destructive, title: String(localized: "Delete")) { [weak self] _, _, completion in
            ScanStore.shared.remove(id: recordID)
            self?.reloadSnapshot()
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    func tableView(
        _: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point _: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard !tableView.isEditing else { return nil }
        guard let recordID = dataSource.itemIdentifier(for: indexPath),
              let record = ScanStore.shared.record(for: recordID)
        else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(
                    title: String(localized: "Copy UID"),
                    image: UIImage(systemName: "doc.on.doc")
                ) { _ in
                    UIPasteboard.general.string = record.cardInfo.uid.hexString
                    SPIndicator.present(
                        title: String(localized: "Copied"),
                        preset: .done,
                        haptic: .success
                    )
                },
                UIAction(
                    title: String(localized: "Export"),
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { _ in
                    self?.exportRecord(record)
                },
                UIAction(
                    title: String(localized: "Delete"),
                    image: UIImage(systemName: "trash"),
                    attributes: [.destructive]
                ) { [weak self] _ in
                    ScanStore.shared.remove(id: recordID)
                    self?.reloadSnapshot()
                },
            ])
        }
    }

    // Two-finger pan gesture automatically enters editing mode on UITableView
    // when allowsMultipleSelectionDuringEditing = true (iOS 13+).

    func tableView(_: UITableView, shouldBeginMultipleSelectionInteractionAt _: IndexPath) -> Bool {
        true
    }

    func tableView(_: UITableView, didBeginMultipleSelectionInteractionAt _: IndexPath) {
        setEditing(true, animated: true)
    }

    func tableViewDidEndMultipleSelectionInteraction(_: UITableView) {
        // Keep editing mode active until user explicitly exits
    }
}

// MARK: - Search

extension ScannerViewController: UISearchControllerDelegate, UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange _: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(commitSearch), object: nil)
        perform(#selector(commitSearch), with: nil, afterDelay: 0.25)
    }

    @objc private func commitSearch() {
        reloadSnapshot()
    }
}

// MARK: - UITableViewDragDelegate

extension ScannerViewController: UITableViewDragDelegate {
    func tableView(
        _: UITableView,
        itemsForBeginning _: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        guard let recordID = dataSource.itemIdentifier(for: indexPath),
              let record = ScanStore.shared.record(for: recordID)
        else { return [] }

        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.cenfc.identifier,
            visibility: .all
        ) { completion in
            do {
                let data = try CardDocument.exportScanOnly(record)
                completion(data, nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }
        provider.suggestedName = record.cardInfo.type.description

        let item = UIDragItem(itemProvider: provider)
        item.localObject = recordID
        return [item]
    }
}

// MARK: - UITableViewDropDelegate

extension ScannerViewController: UITableViewDropDelegate {
    func tableView(
        _: UITableView,
        canHandle session: UIDropSession
    ) -> Bool {
        session.hasItemsConforming(toTypeIdentifiers: [UTType.cenfc.identifier])
            || session.localDragSession != nil
    }

    func tableView(
        _: UITableView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath _: IndexPath?
    ) -> UITableViewDropProposal {
        if session.localDragSession != nil {
            return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UITableViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
    }

    func tableView(
        _: UITableView,
        performDropWith coordinator: UITableViewDropCoordinator
    ) {
        let destinationIndexPath = coordinator.destinationIndexPath
            ?? IndexPath(row: ScanStore.shared.records.count, section: 0)

        if coordinator.session.localDragSession != nil {
            for item in coordinator.items {
                guard let sourceID = item.dragItem.localObject as? UUID,
                      let sourceIndex = ScanStore.shared.records.firstIndex(where: { $0.id == sourceID })
                else { continue }

                ScanStore.shared.move(from: sourceIndex, to: destinationIndexPath.row)

                var snapshot = dataSource.snapshot()
                let ids = ScanStore.shared.records.map(\.id)
                snapshot.deleteAllItems()
                snapshot.appendSections([.main])
                snapshot.appendItems(ids)
                dataSource.apply(snapshot, animatingDifferences: false)

                coordinator.drop(item.dragItem, toRowAt: destinationIndexPath)
            }
            return
        }

        for item in coordinator.items {
            item.dragItem.itemProvider.loadDataRepresentation(
                forTypeIdentifier: UTType.cenfc.identifier
            ) { [weak self] data, _ in
                guard let data else { return }
                DispatchQueue.main.async {
                    guard let envelope = try? CardDocument.importEnvelope(from: data) else { return }
                    let record = envelope.scanRecord
                    if let existing = ScanStore.shared.record(withUID: record.cardInfo.uid) {
                        ScanStore.shared.replace(existing.id, with: record)
                    } else {
                        ScanStore.shared.insert(record, at: destinationIndexPath.row)
                    }
                    if let dump = envelope.dumpRecord, dump.hasMemoryData {
                        DumpStore.shared.add(dump)
                    }
                    self?.reloadSnapshot()
                }
            }
        }
    }
}

// MARK: - UIDropInteractionDelegate (view-level drop for external files)

extension ScannerViewController: UIDropInteractionDelegate {
    func dropInteraction(
        _: UIDropInteraction,
        canHandle session: UIDropSession
    ) -> Bool {
        session.hasItemsConforming(toTypeIdentifiers: [UTType.cenfc.identifier])
    }

    func dropInteraction(
        _: UIDropInteraction,
        sessionDidUpdate _: UIDropSession
    ) -> UIDropProposal {
        UIDropProposal(operation: .copy)
    }

    func dropInteraction(
        _: UIDropInteraction,
        performDrop session: UIDropSession
    ) {
        for item in session.items {
            item.itemProvider.loadDataRepresentation(
                forTypeIdentifier: UTType.cenfc.identifier
            ) { [weak self] data, _ in
                guard let data else { return }
                DispatchQueue.main.async {
                    guard let envelope = try? CardDocument.importEnvelope(from: data) else { return }
                    let record = envelope.scanRecord
                    if let existing = ScanStore.shared.record(withUID: record.cardInfo.uid) {
                        ScanStore.shared.replace(existing.id, with: record)
                    } else {
                        ScanStore.shared.add(record)
                    }
                    if let dump = envelope.dumpRecord, dump.hasMemoryData {
                        DumpStore.shared.add(dump)
                    }
                    self?.reloadSnapshot()
                }
            }
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension ScannerViewController: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            importFile(at: url)
        }
    }
}
