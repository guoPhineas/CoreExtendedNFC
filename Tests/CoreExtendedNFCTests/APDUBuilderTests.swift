// APDU builder test suite.
//
// ## References
// - ISO/IEC 7816-4:2020: APDU structure (CLA INS P1 P2 Lc Data Le)
// - ISO/IEC 7816-4: SELECT (INS=A4), READ BINARY (INS=B0)
// - NFC Forum Type 4 Tag: NDEF AID D2760000850101
// - NXP DESFire: ISO 7816 wrapping [90 CMD 00 00 Lc Data 00]
// - libnfc iso7816.h: ISO 7816 APDU defines
//   https://github.com/nfc-tools/libnfc/blob/master/libnfc/iso7816.h
@testable import CoreExtendedNFC
import Foundation
import Testing

struct APDUBuilderTests {
    @Test("SELECT NDEF AID APDU bytes")
    func selectNDEFAid() {
        let ndefAID = Data([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01])
        let apdu = CommandAPDU.select(aid: ndefAID)
        let bytes = apdu.bytes

        // Expected: [00 A4 04 00 07 D2760000850101 00]
        #expect(bytes[0] == 0x00) // CLA
        #expect(bytes[1] == 0xA4) // INS
        #expect(bytes[2] == 0x04) // P1
        #expect(bytes[3] == 0x00) // P2
        #expect(bytes[4] == 0x07) // Lc
        #expect(Data(bytes[5 ..< 12]) == ndefAID)
        #expect(bytes[12] == 0x00) // Le
        #expect(bytes.count == 13)
    }

    @Test("DESFire wrap command with data")
    func desfireWrapWithData() {
        let apdu = CommandAPDU.desfireWrap(command: 0x5A, data: Data([0x01, 0x02, 0x03]))
        let bytes = apdu.bytes

        // Expected: [90 5A 00 00 03 010203 00]
        #expect(bytes[0] == 0x90)
        #expect(bytes[1] == 0x5A)
        #expect(bytes[2] == 0x00)
        #expect(bytes[3] == 0x00)
        #expect(bytes[4] == 0x03) // Lc
        #expect(bytes[5] == 0x01)
        #expect(bytes[6] == 0x02)
        #expect(bytes[7] == 0x03)
        #expect(bytes[8] == 0x00) // Le
    }

    @Test("DESFire wrap command without data")
    func desfireWrapNoData() {
        let apdu = CommandAPDU.desfireWrap(command: 0x6A)
        let bytes = apdu.bytes

        // Expected: [90 6A 00 00 00] — no Lc/data since data is nil
        #expect(bytes[0] == 0x90)
        #expect(bytes[1] == 0x6A)
        #expect(bytes[2] == 0x00)
        #expect(bytes[3] == 0x00)
        #expect(bytes[4] == 0x00) // Le
        #expect(bytes.count == 5)
    }

    @Test("READ BINARY APDU")
    func readBinary() {
        let apdu = CommandAPDU.readBinary(offset: 0x0000, length: 0x0F)
        let bytes = apdu.bytes
        #expect(bytes[0] == 0x00) // CLA
        #expect(bytes[1] == 0xB0) // INS
        #expect(bytes[2] == 0x00) // P1 (offset high)
        #expect(bytes[3] == 0x00) // P2 (offset low)
        #expect(bytes[4] == 0x0F) // Le
    }

    @Test("CoreNFC expected length maps short Le zero to 256")
    func coreNFCExpectedLengthForZeroLe() {
        let apdu = CommandAPDU.internalAuthenticate(data: Data(repeating: 0xAA, count: 8))
        #expect(apdu.le == 0x00)
        #expect(apdu.nfcExpectedResponseLength == 256)
    }

    @Test("CoreNFC expected length maps missing Le to wildcard")
    func coreNFCExpectedLengthForMissingLe() {
        let apdu = CommandAPDU.selectPassportApplication()
        #expect(apdu.le == nil)
        #expect(apdu.nfcExpectedResponseLength == -1)
    }

    @Test("ResponseAPDU success check")
    func responseSuccess() {
        let resp = ResponseAPDU(data: Data([0x01, 0x02]), sw1: 0x90, sw2: 0x00)
        #expect(resp.isSuccess)
        #expect(resp.statusWord == 0x9000)
        #expect(!resp.needsGetResponse)
        #expect(!resp.hasMoreFrames)
    }

    @Test("ResponseAPDU needs GET RESPONSE")
    func responseGetResponse() {
        let resp = ResponseAPDU(data: Data(), sw1: 0x61, sw2: 0x10)
        #expect(!resp.isSuccess)
        #expect(resp.needsGetResponse)
        #expect(resp.sw2 == 0x10) // 16 more bytes available
    }

    @Test("ResponseAPDU DESFire AF chaining")
    func responseAFChaining() {
        let resp = ResponseAPDU(data: Data([0xAA, 0xBB]), sw1: 0x91, sw2: 0xAF)
        #expect(!resp.isSuccess)
        #expect(resp.hasMoreFrames)
    }

    @Test("ResponseAPDU parse from raw bytes")
    func responseFromRaw() throws {
        let raw = Data([0x01, 0x02, 0x03, 0x90, 0x00])
        let resp = ResponseAPDU(rawResponse: raw)
        #expect(resp != nil)
        #expect(resp?.data == Data([0x01, 0x02, 0x03]))
        let parsed = try #require(resp)
        #expect(parsed.isSuccess)
    }

    @Test("ResponseAPDU parse from too-short raw returns nil")
    func responseFromShortRaw() {
        let resp = ResponseAPDU(rawResponse: Data([0x90]))
        #expect(resp == nil)
    }
}
