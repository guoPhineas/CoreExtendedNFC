import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let cndef = UTType(exportedAs: "wiki.qaq.cenfc.ndef-record", conformingTo: .data)
}

enum NDEFDocument {
    // MARK: - Export

    static func export(_ record: NDEFDataRecord) throws -> Data {
        try PropertyListEncoder().encode(record)
    }

    static func exportToFile(_ record: NDEFDataRecord) throws -> URL {
        let name = sanitizedFileName(for: record)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("cndef")
        try export(record).write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import

    static func importRecord(from data: Data) throws -> NDEFDataRecord {
        try PropertyListDecoder().decode(NDEFDataRecord.self, from: data)
    }

    static func importRecord(from url: URL) throws -> NDEFDataRecord {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        return try importRecord(from: data)
    }

    // MARK: - Helpers

    private static func sanitizedFileName(for record: NDEFDataRecord) -> String {
        record.name
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }
}
