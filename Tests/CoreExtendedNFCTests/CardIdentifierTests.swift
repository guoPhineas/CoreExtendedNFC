// Card identifier (ATQA+SAK) test suite.
//
// ## References
// - ISO/IEC 14443-3A: ATQA (Answer to Request Type A) format
// - NXP AN10833: MIFARE type identification by ATQA + SAK
//   https://www.nxp.com/docs/en/application-note/AN10833.pdf
// - libnfc target-subr.c: ATQA+SAK→card type lookup table
//   https://github.com/nfc-tools/libnfc/blob/master/libnfc/target-subr.c
@testable import CoreExtendedNFC
import Foundation
import Testing

struct CardIdentifierTests {
    @Test("MIFARE Ultralight: ATQA 0x0044, SAK 0x00")
    func identifyUltralight() {
        let type = CardIdentifier.identify(atqa: Data([0x00, 0x44]), sak: 0x00)
        #expect(type == .mifareUltralight)
        #expect(type.family == .mifareUltralight)
    }

    @Test("MIFARE Classic 1K: ATQA 0x0004, SAK 0x08")
    func identifyClassic1K() {
        let type = CardIdentifier.identify(atqa: Data([0x00, 0x04]), sak: 0x08)
        #expect(type == .mifareClassic1K)
        #expect(type.family == .mifareClassic)
        #expect(type.isOperableOnIOS == false)
    }

    @Test("MIFARE Classic 4K: ATQA 0x0002, SAK 0x18")
    func identifyClassic4K() {
        let type = CardIdentifier.identify(atqa: Data([0x00, 0x02]), sak: 0x18)
        #expect(type == .mifareClassic4K)
        #expect(type.isOperableOnIOS == false)
    }

    @Test("MIFARE Mini: ATQA 0x0004, SAK 0x09")
    func identifyMini() {
        let type = CardIdentifier.identify(atqa: Data([0x00, 0x04]), sak: 0x09)
        #expect(type == .mifareMini)
    }

    @Test("MIFARE DESFire: ATQA 0x0344, SAK 0x20")
    func identifyDESFire() {
        let type = CardIdentifier.identify(atqa: Data([0x03, 0x44]), sak: 0x20)
        #expect(type == .mifareDesfire)
        #expect(type.family == .mifareDesfire)
        #expect(type.isOperableOnIOS == true)
    }

    @Test("MIFARE Plus SL2 2K: ATQA 0x0004, SAK 0x10")
    func identifyPlusSL2() {
        let type = CardIdentifier.identify(atqa: Data([0x00, 0x04]), sak: 0x10)
        #expect(type == .mifarePlusSL2_2K)
        #expect(type.family == .mifarePlus)
    }

    @Test("MIFARE Plus SL2 4K: ATQA 0x0002, SAK 0x11")
    func identifyPlusSL2_4K() {
        let type = CardIdentifier.identify(atqa: Data([0x00, 0x02]), sak: 0x11)
        #expect(type == .mifarePlusSL2_4K)
    }

    @Test("Unknown card returns unknown with ATQA/SAK")
    func identifyUnknown() {
        let type = CardIdentifier.identify(atqa: Data([0xFF, 0xFF]), sak: 0x55)
        if case let .unknown(atqa, sak) = type {
            #expect(atqa == Data([0xFF, 0xFF]))
            #expect(sak == 0x55)
        } else {
            #expect(Bool(false), "Expected unknown card type")
        }
    }

    @Test("Card type descriptions are non-empty")
    func descriptionsNonEmpty() {
        let types: [CardType] = [
            .mifareUltralight, .mifareClassic1K, .mifareDesfire,
            .ntag213, .felicaLite, .iso15693_generic,
        ]
        for type in types {
            #expect(!type.description.isEmpty)
        }
    }
}
