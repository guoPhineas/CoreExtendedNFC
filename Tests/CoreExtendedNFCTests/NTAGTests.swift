// NTAG (213/215/216) test suite.
//
// ## References
// - NXP NTAG213/215/216 datasheet: GET_VERSION response, memory maps
//   https://www.nxp.com/docs/en/data-sheet/NTAG213_215_216.pdf
// - NXP NT3H2111/2211 (NTAG I2C) datasheet
// - NTAG213: 144 bytes user memory (pages 4-39)
// - NTAG215: 504 bytes user memory (pages 4-129)
// - NTAG216: 888 bytes user memory (pages 4-225)
@testable import CoreExtendedNFC
import Foundation
import Testing

struct NTAGTests {
    @Test("READ_SIG sends 0x3C 0x00")
    func readSignature() async throws {
        let mock = MockTransport()
        mock.responses = [Data(repeating: 0xEE, count: 32)]
        let commands = UltralightCommands(transport: mock)

        let sig = try await commands.readSignature()
        #expect(mock.sentCommands[0] == Data([0x3C, 0x00]))
        #expect(sig.count == 32)
    }

    @Test("READ_CNT sends 0x39 and parses 3-byte LE counter")
    func readCounter() async throws {
        let mock = MockTransport()
        // Counter value: 0x01 + 0x02<<8 + 0x03<<16 = 197121
        mock.responses = [Data([0x01, 0x02, 0x03])]
        let commands = UltralightCommands(transport: mock)

        let count = try await commands.readCounter()
        #expect(mock.sentCommands[0] == Data([0x39, 0x02]))
        #expect(count == 197_121)
    }

    @Test("NTAG variant detection from GET_VERSION")
    func variantDetection() throws {
        let ntag213Data = Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, 0x0F, 0x03])
        let version = try UltralightVersionResponse(data: ntag213Data)
        #expect(NTAGVariant.detect(from: version) == .ntag213)
    }

    @Test("NTAG memory map static accessors")
    func memoryMapAccessors() {
        #expect(UltralightMemoryMap.ntag213.totalPages == 45)
        #expect(UltralightMemoryMap.ntag215.totalPages == 135)
        #expect(UltralightMemoryMap.ntag216.totalPages == 231)
    }
}
