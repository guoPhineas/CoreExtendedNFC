import Foundation

// MARK: - Export / Import / Diff

public extension CoreExtendedNFC {
    // MARK: Export

    /// Export a memory dump as a hex string (one line per page/block).
    static func exportHex(dump: MemoryDump) -> String {
        dump.exportHex()
    }

    /// Export a memory dump as raw binary data.
    static func exportBinary(dump: MemoryDump) -> Data {
        dump.exportBinary()
    }

    /// Export a memory dump in Flipper Zero NFC format.
    static func exportFlipperNFC(dump: MemoryDump) throws -> String {
        try dump.exportFlipperNFC()
    }

    /// Export a memory dump in Proxmark3 MFU format.
    static func exportProxmark3MFU(dump: MemoryDump) throws -> Data {
        try dump.exportProxmark3MFU()
    }

    /// Export a memory dump in libnfc MFD format.
    static func exportLibNFCMFD(dump: MemoryDump) throws -> Data {
        try dump.exportLibNFCMFD()
    }

    /// Export a memory dump as structured JSON.
    static func exportJSON(
        dump: MemoryDump,
        prettyPrinted: Bool = true
    ) throws -> String {
        try dump.exportStructuredJSON(prettyPrinted: prettyPrinted)
    }

    /// Export a memory dump in all supported formats at once.
    static func exportAll(dump: MemoryDump) throws -> [MemoryDump.ExportArtifact] {
        try dump.exportArtifacts()
    }

    // MARK: Import

    /// Import a memory dump from Flipper Zero NFC text format.
    static func importFlipperNFC(_ text: String) throws -> MemoryDump {
        try MemoryDump.importFlipperNFC(text)
    }

    /// Import a memory dump from Proxmark3 MFU binary format.
    static func importProxmark3MFU(_ data: Data) throws -> MemoryDump {
        try MemoryDump.importProxmark3MFU(data)
    }

    // MARK: Diff

    /// Compare two memory dumps and produce a summary of differences.
    static func diffDumps(
        _ lhs: MemoryDump,
        _ rhs: MemoryDump
    ) -> MemoryDump.DiffSummary {
        lhs.diffSummary(against: rhs)
    }
}
