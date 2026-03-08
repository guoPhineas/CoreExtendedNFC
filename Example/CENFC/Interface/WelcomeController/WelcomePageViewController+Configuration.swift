//
//  WelcomePageViewController+Configuration.swift
//  CENFC
//

import UIKit

extension WelcomePageViewController {
    struct Configuration {
        var icon: UIImage?
        var title: String.LocalizationValue
        var highlightedTitle: String.LocalizationValue
        var subtitle: String.LocalizationValue
        var buttonTitle: String.LocalizationValue
        var accentColor: UIColor
        var features: [Feature]
    }

    struct Feature {
        var icon: UIImage
        var title: String.LocalizationValue
        var detail: String.LocalizationValue
    }
}

extension WelcomePageViewController.Configuration {
    static var `default`: Self {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "CENFC"

        var appIcon: UIImage?
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last
        {
            appIcon = UIImage(named: name)
        }

        return .init(
            icon: appIcon,
            title: "Welcome to",
            highlightedTitle: "\(displayName)",
            subtitle: "An advanced NFC toolkit for iOS. Scan, identify, dump, and analyze NFC tags — all processed locally on your device.",
            buttonTitle: "Get Started",
            accentColor: AppTheme.accent,
            features: [
                // MARK: - Scanning & Identification

                .init(
                    icon: UIImage(systemName: "sensor.tag.radiowaves.forward.fill")!,
                    title: "Tag Scanning",
                    detail: "Identify NFC tags via ATQA/SAK lookup. Supports ISO 14443, FeliCa, and ISO 15693."
                ),
                .init(
                    icon: UIImage(systemName: "cpu.fill")!,
                    title: "Chip Fingerprinting",
                    detail: "Detect precise chip variants — NTAG, Ultralight, DESFire, MIFARE Classic, and more."
                ),

                // MARK: - Memory & Data

                .init(
                    icon: UIImage(systemName: "internaldrive.fill")!,
                    title: "Memory Dump",
                    detail: "Read full card memory with page/block detail. Export as hex, JSON, or binary."
                ),
                .init(
                    icon: UIImage(systemName: "doc.text.fill")!,
                    title: "NDEF Read & Write",
                    detail: "Create, read, and write NDEF records — text, URI, smart poster, MIME, and external types."
                ),

                // MARK: - Passport

                .init(
                    icon: UIImage(systemName: "person.text.rectangle.fill")!,
                    title: "Passport Reading",
                    detail: "Read eMRTD chips with BAC authentication. View MRZ data, photo, and security report."
                ),
                .init(
                    icon: UIImage(systemName: "checkmark.shield.fill")!,
                    title: "Security Verification",
                    detail: "Passive and Active Authentication verify data integrity and chip genuineness."
                ),

                // MARK: - Tools

                .init(
                    icon: UIImage(systemName: "wrench.and.screwdriver.fill")!,
                    title: "Protocol Tools",
                    detail: "CRC calculator, hex converter, ATQA/SAK lookup, access bits decoder, and BER-TLV parser."
                ),
                .init(
                    icon: UIImage(systemName: "list.bullet.rectangle.fill")!,
                    title: "Protocol Logging",
                    detail: "Full protocol trace for every NFC session. Share logs for debugging and analysis."
                ),

                // MARK: - Privacy & Files

                .init(
                    icon: UIImage(systemName: "lock.fill")!,
                    title: "Offline & Private",
                    detail: "All data stays on your device. No network, no cloud, no tracking."
                ),
                .init(
                    icon: UIImage(systemName: "square.and.arrow.up.fill")!,
                    title: "Import & Export",
                    detail: "Share scan records, dumps, and passport data as portable files."
                ),
            ]
        )
    }
}
