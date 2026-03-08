import CoreExtendedNFC
import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let cenfcPassport = UTType(exportedAs: "wiki.qaq.cenfc.passport-record", conformingTo: .data)
}

enum PassportDocument {
    // MARK: - Export

    static func export(_ record: PassportRecord) throws -> Data {
        try PropertyListEncoder().encode(record)
    }

    static func exportToFile(_ record: PassportRecord) throws -> URL {
        let name = sanitizedFileName(for: record)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("cenfcpass")
        try export(record).write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import

    static func importRecord(from data: Data) throws -> PassportRecord {
        try PropertyListDecoder().decode(PassportRecord.self, from: data)
    }

    static func importRecord(from url: URL) throws -> PassportRecord {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        return try importRecord(from: data)
    }

    // MARK: - Helpers

    private static func sanitizedFileName(for record: PassportRecord) -> String {
        let docNum = (record.passport.mrz?.documentNumber ?? "")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let name = record.displayName
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "\(name)_\(docNum)"
    }
}
