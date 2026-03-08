// MIFARE Ultralight / NTAG command test suite.
//
// ## References
// - NXP MF0ICU2 (Ultralight C) datasheet: READ(0x30), WRITE(0xA2)
//   https://www.nxp.com/docs/en/data-sheet/MF0ICU2.pdf
// - NXP MF0UL21 (Ultralight EV1) datasheet: FAST_READ(0x3A), PWD_AUTH(0x1B), GET_VERSION(0x60)
//   https://www.nxp.com/docs/en/data-sheet/MF0ULx1.pdf
// - libnfc nfc-mfultralight.c:
//   https://github.com/nfc-tools/libnfc/blob/master/utils/nfc-mfultralight.c
@testable import CoreExtendedNFC
import Foundation
import Testing

struct UltralightTests {
    // MARK: - Command Building

    @Test("READ command sends correct bytes")
    func readCommand() async throws {
        let mock = MockTransport()
        mock.responses = [Data(repeating: 0xAA, count: 16)]
        let commands = UltralightCommands(transport: mock)

        let data = try await commands.readPages(startPage: 0x04)
        #expect(mock.sentCommands[0] == Data([0x30, 0x04]))
        #expect(data.count == 16)
    }

    @Test("WRITE command sends correct bytes")
    func writeCommand() async throws {
        let mock = MockTransport()
        mock.responses = [Data([0x0A])] // ACK
        let commands = UltralightCommands(transport: mock)

        try await commands.writePage(0x04, data: Data([0x01, 0x02, 0x03, 0x04]))
        #expect(mock.sentCommands[0] == Data([0xA2, 0x04, 0x01, 0x02, 0x03, 0x04]))
    }

    @Test("WRITE rejects non-4-byte data")
    func writeRejectsWrongSize() async {
        let mock = MockTransport()
        let commands = UltralightCommands(transport: mock)

        await #expect(throws: NFCError.self) {
            try await commands.writePage(0x04, data: Data([0x01, 0x02]))
        }
    }

    @Test("FAST_READ command sends correct bytes")
    func fastReadCommand() async throws {
        let mock = MockTransport()
        // 3 pages = 12 bytes
        mock.responses = [Data(repeating: 0xBB, count: 12)]
        let commands = UltralightCommands(transport: mock)

        let data = try await commands.fastRead(from: 4, to: 6)
        #expect(mock.sentCommands[0] == Data([0x3A, 0x04, 0x06]))
        #expect(data.count == 12)
    }

    @Test("GET_VERSION command sends 0x60")
    func getVersionCommand() async throws {
        let mock = MockTransport()
        // NTAG213 version response
        mock.responses = [Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, 0x0F, 0x03])]
        let commands = UltralightCommands(transport: mock)

        let version = try await commands.getVersion()
        #expect(mock.sentCommands[0] == Data([0x60]))
        #expect(version.cardType == .ntag213)
    }

    // MARK: - Version Parsing

    @Test("Parse NTAG213 version response")
    func parseNTAG213() throws {
        let data = Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, 0x0F, 0x03])
        let version = try UltralightVersionResponse(data: data)
        #expect(version.vendorID == 0x04) // NXP
        #expect(version.productType == 0x04) // NTAG
        #expect(version.storageSize == 0x0F)
        #expect(version.cardType == .ntag213)
        #expect(version.totalPages == 45)
        #expect(version.userPages == 36)
    }

    @Test("Parse NTAG215 version response")
    func parseNTAG215() throws {
        let data = Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, 0x11, 0x03])
        let version = try UltralightVersionResponse(data: data)
        #expect(version.cardType == .ntag215)
        #expect(version.totalPages == 135)
        #expect(version.userPages == 126)
    }

    @Test("Parse NTAG216 version response")
    func parseNTAG216() throws {
        let data = Data([0x00, 0x04, 0x04, 0x02, 0x01, 0x00, 0x13, 0x03])
        let version = try UltralightVersionResponse(data: data)
        #expect(version.cardType == .ntag216)
        #expect(version.totalPages == 231)
        #expect(version.userPages == 222)
    }

    @Test("Parse Ultralight EV1 MF0UL11 version response")
    func parseULEV1_11() throws {
        let data = Data([0x00, 0x04, 0x03, 0x01, 0x01, 0x00, 0x0B, 0x03])
        let version = try UltralightVersionResponse(data: data)
        #expect(version.productType == 0x03) // Ultralight
        #expect(version.cardType == .mifareUltralightEV1_MF0UL11)
    }

    @Test("Parse Ultralight EV1 MF0UL21 version response")
    func parseULEV1_21() throws {
        let data = Data([0x00, 0x04, 0x03, 0x01, 0x01, 0x00, 0x0E, 0x03])
        let version = try UltralightVersionResponse(data: data)
        #expect(version.cardType == .mifareUltralightEV1_MF0UL21)
    }

    // MARK: - Memory Map

    @Test("NTAG213 memory map")
    func ntag213MemoryMap() {
        let map = UltralightMemoryMap.forType(.ntag213)
        #expect(map.totalPages == 45)
        #expect(map.userDataStart == 4)
        #expect(map.userDataEnd == 39)
        #expect(map.configStart == 41)
        #expect(map.dynamicLockStart == 40)
    }

    @Test("NTAG215 memory map")
    func ntag215MemoryMap() {
        let map = UltralightMemoryMap.forType(.ntag215)
        #expect(map.totalPages == 135)
        #expect(map.userDataStart == 4)
        #expect(map.userDataEnd == 129)
        #expect(map.configStart == 131)
    }

    @Test("Ultralight basic memory map")
    func ultralightMemoryMap() {
        let map = UltralightMemoryMap.forType(.mifareUltralight)
        #expect(map.totalPages == 16)
        #expect(map.userDataStart == 4)
        #expect(map.userDataEnd == 15)
        #expect(map.configStart == nil)
    }

    @Test("Ultralight C memory map excludes secret key pages from config range")
    func ultralightCMemoryMap() {
        let map = UltralightMemoryMap.forType(.mifareUltralightC)
        #expect(map.totalPages == 48)
        #expect(map.userDataStart == 4)
        #expect(map.userDataEnd == 39)
        #expect(map.dynamicLockStart == 40)
        #expect(map.configStart == 42)
    }

    // MARK: - PWD_AUTH

    @Test("PWD_AUTH sends correct bytes")
    func pwdAuth() async throws {
        let mock = MockTransport()
        mock.responses = [Data([0xAB, 0xCD])] // PACK response
        let commands = UltralightCommands(transport: mock)

        let pack = try await commands.passwordAuth(password: Data([0x01, 0x02, 0x03, 0x04]))
        #expect(mock.sentCommands[0] == Data([0x1B, 0x01, 0x02, 0x03, 0x04]))
        #expect(pack == Data([0xAB, 0xCD]))
    }

    @Test("Ultralight C AUTHENTICATE performs the 3DES challenge flow")
    func ultralightCAuthenticate() async throws {
        let key = try #require(Data(hexString: "49454D4B41455242214E4143554F5946"))
        let rndA = try #require(Data(hexString: "0011223344556677"))
        let rndB = try #require(Data(hexString: "214E4143554F5946"))

        let encryptedRndB = try CryptoUtils.tripleDESEncrypt(key: key, message: rndB)
        let challengeCiphertext = try CryptoUtils.tripleDESEncrypt(
            key: key,
            message: Self.concat(rndA, Self.rotateLeft(rndB)),
            iv: encryptedRndB
        )
        let finalResponse = try CryptoUtils.tripleDESEncrypt(
            key: key,
            message: Self.rotateLeft(rndA),
            iv: Data(challengeCiphertext.suffix(8))
        )

        let mock = MockTransport()
        mock.responses = [
            Data([0xAF]) + encryptedRndB,
            Data([0x00]) + finalResponse,
        ]
        let commands = UltralightCommands(transport: mock)

        let session = try await commands.authenticateUltralightC(key: key, randomA: rndA)

        #expect(session.randomA == rndA)
        #expect(session.randomB == rndB)
        #expect(mock.sentCommands[0] == Data([0x1A, 0x00]))
        #expect(mock.sentCommands[1] == Data([0xAF]) + challengeCiphertext)
    }

    @Test("Ultralight C access configuration parses AUTH0 and AUTH1")
    func ultralightCAccessConfiguration() async throws {
        let mock = MockTransport()
        mock.responses = [
            Data([
                0x90, 0x91, 0x92, 0x93,
                0x94, 0x95, 0x96, 0x97,
                0x10, 0x00, 0x00, 0x00,
                0x01, 0x00, 0x00, 0x00,
            ]),
        ]
        let commands = UltralightCommands(transport: mock)

        let config = try await commands.readUltralightCAccessConfiguration()

        #expect(config.firstProtectedPage == 0x10)
        #expect(config.requiresAuthenticationForWrites)
        #expect(config.requiresAuthenticationForReads)
        #expect(config.protectionDescription == "Read and write")
        #expect(mock.sentCommands[0] == Data([0x30, 0x28]))
    }

    private static func rotateLeft(_ data: Data) -> Data {
        guard let first = data.first else { return Data() }
        return concat(Data(data.dropFirst()), Data([first]))
    }

    private static func concat(_ parts: Data...) -> Data {
        parts.reduce(into: Data()) { result, part in
            result.append(part)
        }
    }
}
