// Hex/byte/parity utility test suite.
//
// ## References
// - libnfc nfc-utils.c: hex conversion and parity utilities
//   https://github.com/nfc-tools/libnfc/blob/master/utils/nfc-utils.c
// - DES odd parity: each byte must have odd number of 1-bits (FIPS 46-3)
@testable import CoreExtendedNFC
import Foundation
import Testing

struct HexUtilsTests {
    @Test("Data to hex string")
    func dataToHex() {
        let data = Data([0x0A, 0x1B, 0x2C])
        #expect(data.hexString == "0A1B2C")
    }

    @Test("Data to hex dump with spaces")
    func dataToHexDump() {
        let data = Data([0x0A, 0x1B, 0x2C])
        #expect(data.hexDump == "0A 1B 2C")
    }

    @Test("Empty data to hex")
    func emptyHex() {
        let data = Data()
        #expect(data.hexString == "")
        #expect(data.hexDump == "")
    }

    @Test("Hex string to data")
    func hexToData() {
        let data = Data(hexString: "0A1B2C")
        #expect(data == Data([0x0A, 0x1B, 0x2C]))
    }

    @Test("Hex string with spaces to data")
    func hexWithSpaces() {
        let data = Data(hexString: "0A 1B 2C")
        #expect(data == Data([0x0A, 0x1B, 0x2C]))
    }

    @Test("Invalid hex string returns nil")
    func invalidHex() {
        #expect(Data(hexString: "ZZ") == nil)
        #expect(Data(hexString: "0A1") == nil) // odd length
    }

    @Test("Round-trip hex conversion")
    func roundTrip() {
        let original = Data([0x00, 0xFF, 0x80, 0x7F, 0x01])
        let hex = original.hexString
        let restored = Data(hexString: hex)
        #expect(restored == original)
    }

    @Test("Formatted hex dump has offsets")
    func formattedDump() {
        let data = Data(repeating: 0xAA, count: 20)
        let formatted = data.hexDumpFormatted
        #expect(formatted.contains("0000:"))
        #expect(formatted.contains("0010:"))
    }
}

struct ByteUtilsTests {
    @Test("UInt16 big-endian")
    func uint16BE() {
        let data = Data([0x01, 0x02])
        #expect(data.uint16BE == 0x0102)
    }

    @Test("UInt16 little-endian")
    func uint16LE() {
        let data = Data([0x01, 0x02])
        #expect(data.uint16LE == 0x0201)
    }

    @Test("UInt32 big-endian")
    func uint32BE() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        #expect(data.uint32BE == 0x0102_0304)
    }

    @Test("UInt32 little-endian")
    func uint32LE() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        #expect(data.uint32LE == 0x0403_0201)
    }

    @Test("Short data returns 0")
    func shortData() {
        let data = Data([0x01])
        #expect(data.uint16BE == 0)
        #expect(data.uint32BE == 0)
    }
}

struct ParityTests {
    @Test("Odd parity of 0x00 is 1 (0 bits set, need 1 to make odd)")
    func parityZero() {
        #expect(Parity.odd(0x00) == 1)
    }

    @Test("Odd parity of 0x01 is 0 (1 bit set, already odd)")
    func parityOne() {
        #expect(Parity.odd(0x01) == 0)
    }

    @Test("Odd parity of 0xFF is 1 (8 bits set, need 1 to make odd)")
    func parityAllOnes() {
        #expect(Parity.odd(0xFF) == 1)
    }

    @Test("Odd parity of 0x03 is 1 (2 bits set, need 1 to make odd)")
    func parityTwo() {
        #expect(Parity.odd(0x03) == 1)
    }

    @Test("Odd parity bytes")
    func parityBytes() {
        let data = Data([0x00, 0x01, 0xFF])
        let result = Parity.oddBytes(data)
        #expect(result[0] == 1) // 0 bits → parity 1
        #expect(result[1] == 0) // 1 bit → parity 0
        #expect(result[2] == 1) // 8 bits → parity 1
    }
}
