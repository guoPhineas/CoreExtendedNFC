import CoreExtendedNFC
import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let cenfc = UTType(exportedAs: "wiki.qaq.cenfc.scan-record", conformingTo: .data)
}

enum ScanRecordDocument {
    // MARK: - Export

    static func export(_ record: ScanRecord) throws -> Data {
        try PropertyListEncoder().encode(record)
    }

    static func exportToFile(_ record: ScanRecord) throws -> URL {
        let name = sanitizedFileName(for: record)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("cenfc")
        try export(record).write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import

    static func importRecord(from data: Data) throws -> ScanRecord {
        try PropertyListDecoder().decode(ScanRecord.self, from: data)
    }

    static func importRecord(from url: URL) throws -> ScanRecord {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        return try importRecord(from: data)
    }

    // MARK: - Helpers

    private static func sanitizedFileName(for record: ScanRecord) -> String {
        let uid = record.cardInfo.uid.compactHexString
        let type = record.cardInfo.type.description
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "\(type)_\(uid)"
    }
}
