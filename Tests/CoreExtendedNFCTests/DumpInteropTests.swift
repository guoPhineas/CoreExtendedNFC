// Dump interoperability tests: export format, page-count verification.
//
// ## References
// - libnfc nfc-mfultralight.c: MFD binary format (raw page concatenation)
//   https://github.com/nfc-tools/libnfc/blob/master/utils/nfc-mfultralight.c
// - Flipper Zero NFC file format (firmware source)
// - Proxmark3 client source: MFU dump header format
// - NXP NTAG213/215/216 datasheet: page counts and memory maps
//   https://www.nxp.com/docs/en/data-sheet/NTAG213_215_216.pdf
@testable import CoreExtendedNFC
import Foundation
import Testing

struct DumpInteropTests {
    @Test("Structured dump export includes normalized fields")
    func structuredJSONExport() throws {
        let dump = MemoryDump(
            cardInfo: CardInfo(type: .ntag213, uid: Data([0x01, 0x02, 0x03, 0x04])),
            pages: [.init(number: 4, data: Data([0x03, 0x03, 0xD1, 0x01]))],
            ndefMessage: NDEFMessage.text("Hi").data,
            facts: [.init(key: "Write Access", value: "Writable")],
            capabilities: [.readable, .writable]
        )

        let json = try dump.exportStructuredJSON()

        #expect(json.contains("\"cardType\""))
        #expect(json.contains("\"uid\""))
        #expect(json.contains("\"capabilities\""))
        #expect(json.contains("\"parsedNDEF\""))
    }

    @Test("Export artifacts include binary, JSON, and libnfc MFD when supported")
    func exportArtifacts() throws {
        let dump = MemoryDump(
            cardInfo: CardInfo(type: .ntag213, uid: Data([0xDE, 0xAD, 0xBE, 0xEF])),
            pages: [
                .init(number: 4, data: Data([0x01, 0x02, 0x03, 0x04])),
                .init(number: 5, data: Data([0x05, 0x06, 0x07, 0x08])),
            ],
            capabilities: [.readable]
        )

        let artifacts = try dump.exportArtifacts()

        #expect(artifacts.count == 6)
        #expect(artifacts.map(\.suggestedFilename).contains("ntag-deadbeef.json"))
        #expect(artifacts.map(\.suggestedFilename).contains("ntag-deadbeef.bin"))
        #expect(artifacts.map(\.suggestedFilename).contains("ntag-deadbeef.mfd"))
        #expect(artifacts.map(\.suggestedFilename).contains("ntag-deadbeef.nfc"))
        #expect(artifacts.map(\.suggestedFilename).contains("ntag-deadbeef-proxmark3.bin"))
        #expect(try dump.exportLibNFCMFD() == Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]))
    }

    @Test("Flipper Zero export round-trips page dumps")
    func flipperRoundTrip() throws {
        let dump = MemoryDump(
            cardInfo: CardInfo(
                type: .ntag213,
                uid: Data([0x04, 0x57, 0x01, 0xCA, 0x53, 0x28, 0x80]),
                atqa: Data([0x44, 0x00]),
                sak: 0x00
            ),
            pages: [
                .init(number: 0, data: Data([0x04, 0x57, 0x01, 0x84])),
                .init(number: 1, data: Data([0xCA, 0x53, 0x28, 0x80])),
                .init(number: 2, data: Data([0xDB, 0x48, 0x00, 0x00])),
                .init(number: 4, data: Data([0x03, 0x03, 0xD1, 0x01])),
            ]
        )

        let exported = try dump.exportFlipperNFC()
        let imported = try MemoryDump.importFlipperNFC(exported)

        #expect(exported.contains("Filetype: Flipper NFC device"))
        #expect(exported.contains("Device type: NTAG/Ultralight"))
        #expect(exported.contains("Mifare version: 00 04 04 02 01 00 0F 03"))
        #expect(imported.cardInfo.type == .ntag213)
        #expect(imported.cardInfo.uid == dump.cardInfo.uid)
        #expect(imported.pages.first?.data == dump.pages.first?.data)
    }

    @Test("Proxmark3 MFU binary export round-trips page dumps")
    func proxmarkRoundTrip() throws {
        let dump = MemoryDump(
            cardInfo: CardInfo(
                type: .ntag213,
                uid: Data([0x04, 0x57, 0x01, 0xCA, 0x53, 0x28, 0x80])
            ),
            pages: [
                .init(number: 0, data: Data([0x04, 0x57, 0x01, 0x84])),
                .init(number: 1, data: Data([0xCA, 0x53, 0x28, 0x80])),
                .init(number: 2, data: Data([0xDB, 0x48, 0x00, 0x00])),
                .init(number: 44, data: Data([0x00, 0x00, 0x00, 0x00])),
            ]
        )

        let exported = try dump.exportProxmark3MFU()
        let imported = try MemoryDump.importProxmark3MFU(exported)

        #expect(exported.count == 56 + 45 * 4)
        #expect(imported.cardInfo.type == .ntag213)
        #expect(imported.cardInfo.uid == dump.cardInfo.uid)
        #expect(imported.pages.count == 45)
        #expect(imported.pages[44].data == Data([0x00, 0x00, 0x00, 0x00]))
    }

    @Test("Proxmark3 plain binary import is accepted")
    func proxmarkPlainBinaryImport() throws {
        let imported = try MemoryDump.importProxmark3MFU(
            Data([
                0x04, 0x57, 0x01, 0x84,
                0xCA, 0x53, 0x28, 0x80,
                0xDB, 0x48, 0x00, 0x00,
                0xE1, 0x10, 0x12, 0x00,
            ])
        )

        #expect(imported.cardInfo.uid == Data([0x04, 0x57, 0x01, 0xCA, 0x53, 0x28, 0x80]))
        #expect(imported.pages.count == 4)
        #expect(imported.pages[3].data == Data([0xE1, 0x10, 0x12, 0x00]))
    }

    @Test("Dump diff summary reports changed blocks and files")
    func dumpDiffSummary() {
        let lhs = MemoryDump(
            cardInfo: CardInfo(type: .iso15693_generic, uid: Data([0xE0, 0x01, 0x02, 0x03])),
            blocks: [
                .init(number: 0, data: Data([0x01, 0x02, 0x03, 0x04])),
                .init(number: 1, data: Data([0x05, 0x06, 0x07, 0x08])),
            ],
            files: [.init(fileID: 1, data: Data([0xAA]))],
            facts: [.init(key: "AFI", value: "0x00")],
            capabilities: [.readable]
        )

        let rhs = MemoryDump(
            cardInfo: CardInfo(type: .iso15693_generic, uid: Data([0xE0, 0x01, 0x02, 0x03])),
            blocks: [
                .init(number: 0, data: Data([0x01, 0x02, 0x03, 0x04])),
                .init(number: 1, data: Data([0x09, 0x06, 0x07, 0x08])),
            ],
            files: [.init(fileID: 2, data: Data([0xBB]))],
            facts: [.init(key: "AFI", value: "0x07")],
            capabilities: [.readable]
        )

        let diff = lhs.diffSummary(against: rhs)

        #expect(diff.sameUID)
        #expect(diff.blockChanges == 1)
        #expect(diff.fileChanges == 2)
        #expect(diff.factChanges == 1)
        #expect(diff.hasDifferences)
    }

    @Test("libnfc MFD export rejects non page-based dumps")
    func libNFCMFDUnsupported() {
        let dump = MemoryDump(
            cardInfo: CardInfo(type: .iso15693_generic, uid: Data([0xE0, 0x01, 0x02, 0x03])),
            blocks: [.init(number: 0, data: Data([0xAA, 0xBB, 0xCC, 0xDD]))]
        )

        #expect(throws: NFCError.self) {
            _ = try dump.exportLibNFCMFD()
        }
    }
}
