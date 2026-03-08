// Passport reader tests: PACE info parsing, BAC key derivation, MRZ vectors.
//
// ## References
// - BSI TR-03110 Part 3, Section A.6.1: PACEInfo structure in EF.CardAccess
//   https://www.bsi.bund.de/EN/Themen/Unternehmen-und-Organisationen/Standards-und-Zertifizierung/Technische-Richtlinien/TR-nach-Thema-sortiert/tr03110/tr-03110.html
// - ICAO Doc 9303 Part 11, Section 9.7: BAC protocol
//   https://www.icao.int/publications/Documents/9303_p11_cons_en.pdf
// - ICAO Doc 9303 Part 11, Appendix D.1: MRZ key derivation test vector
@testable import CoreExtendedNFC
import Foundation
import Testing

struct PassportReaderTests {
    @Test("CardAccess parser extracts advertised PACE info")
    func parseCardAccessPACEInfo() throws {
        let cardAccessData = makeCardAccessData()

        let result = try CardAccessParser.parse(cardAccessData)

        #expect(result.supportsPACE)
        #expect(result.paceInfos.count == 1)
        #expect(result.paceInfos[0].protocolOID == SecurityProtocol.paceECDHGMAESCBCCMAC128.rawValue)
        #expect(result.paceInfos[0].parameterID == 12)
    }

    @Test("Passport reader falls back to BAC when advertised PACE cannot complete")
    func readPassportFallsBackToBACAfterPACEAttempt() async throws {
        let mrzKey = "L898902C<369080619406236"
        let cardAccessData = makeCardAccessData()
        let transport = PassportNegotiationTransport(
            mrzKey: mrzKey,
            cardAccessData: cardAccessData
        )

        let model = try await PassportReader(transport: transport).readPassport(
            mrzKey: mrzKey,
            dataGroups: [],
            performActiveAuth: false
        )

        #expect(model.cardAccess?.supportsPACE == true)
        #expect(model.securityReport.cardAccess.status == .succeeded)
        #expect(model.securityReport.pace.status == .fallback)
        #expect(model.securityReport.bac.status == .succeeded)
        #expect(model.securityReport.activeAuthentication.status == .skipped)
        #expect(transport.sentAPDUs.map(\.ins).contains(0x86))
        #expect(transport.sentAPDUs.map(\.ins).contains(0x84))
        #expect(transport.sentAPDUs.map(\.ins).contains(0x82))
    }

    private func makeCardAccessData() -> Data {
        let oid = ChipAuthenticationHandler.encodeOID(SecurityProtocol.paceECDHGMAESCBCCMAC128.rawValue)
        let oidNode = ASN1Parser.encodeTLV(tag: 0x06, value: oid)
        let versionNode = ASN1Parser.encodeTLV(tag: 0x02, value: Data([0x02]))
        let paramIDNode = ASN1Parser.encodeTLV(tag: 0x02, value: Data([0x0C]))
        let sequence = ASN1Parser.encodeTLV(tag: 0x30, value: oidNode + versionNode + paramIDNode)
        return ASN1Parser.encodeTLV(tag: 0x31, value: sequence)
    }
}

private final class PassportNegotiationTransport: NFCTagTransport, @unchecked Sendable {
    let identifier = Data([0x04, 0x25, 0x11, 0x22, 0x33, 0x44, 0x55])

    private let mrzKey: String
    private let rndICC = Data([0x46, 0x08, 0xF9, 0x19, 0x88, 0x70, 0x22, 0x12])
    private let kICC = Data([
        0x0B, 0x4F, 0x80, 0x32, 0x3E, 0xB3, 0x19, 0x1C,
        0xB0, 0x49, 0x70, 0xCB, 0x40, 0x52, 0x79, 0x0B,
    ])

    private var scriptedResponses: [ResponseAPDU]
    var sentAPDUs: [CommandAPDU] = []

    init(mrzKey: String, cardAccessData: Data) {
        self.mrzKey = mrzKey

        let passwordKey = PACEHandler.derivePasswordKey(
            password: mrzKey,
            keyReference: .mrz,
            mode: .aes128
        )
        let encryptedNonce = try? CryptoUtils.aesEncrypt(
            key: passwordKey,
            message: Data(repeating: 0x11, count: 16),
            iv: Data(count: 16)
        )
        let paceResponse = ResponseAPDU(
            data: ASN1Parser.encodeTLV(
                tag: 0x7C,
                value: ASN1Parser.encodeTLV(tag: 0x80, value: encryptedNonce ?? Data(repeating: 0x00, count: 16))
            ),
            sw1: 0x90,
            sw2: 0x00
        )

        scriptedResponses = [
            ResponseAPDU(data: Data(), sw1: 0x90, sw2: 0x00),
            ResponseAPDU(data: Data(), sw1: 0x90, sw2: 0x00),
            ResponseAPDU(data: Data(cardAccessData.prefix(4)), sw1: 0x90, sw2: 0x00),
            ResponseAPDU(data: cardAccessData, sw1: 0x90, sw2: 0x00),
            ResponseAPDU(data: Data(), sw1: 0x90, sw2: 0x00),
            ResponseAPDU(data: Data(), sw1: 0x90, sw2: 0x00),
            paceResponse,
        ]
    }

    func send(_: Data) async throws -> Data {
        throw NFCError.unsupportedOperation("Raw transport is not used in passport APDU tests")
    }

    func sendAPDU(_ apdu: CommandAPDU) async throws -> ResponseAPDU {
        sentAPDUs.append(apdu)

        switch apdu.ins {
        case 0x84:
            return ResponseAPDU(data: rndICC, sw1: 0x90, sw2: 0x00)
        case 0x82:
            return try mutualAuthenticateResponse(for: apdu)
        default:
            guard !scriptedResponses.isEmpty else {
                throw NFCError.tagConnectionLost
            }
            return scriptedResponses.removeFirst()
        }
    }

    private func mutualAuthenticateResponse(for apdu: CommandAPDU) throws -> ResponseAPDU {
        guard let requestData = apdu.data, requestData.count == 40 else {
            throw NFCError.invalidResponse(apdu.bytes)
        }

        let kseed = KeyDerivation.generateKseed(mrzKey: mrzKey)
        let kenc = KeyDerivation.deriveKey(keySeed: kseed, mode: .enc)
        let kmac = KeyDerivation.deriveKey(keySeed: kseed, mode: .mac)

        let encryptedRequest = Data(requestData.prefix(32))
        let requestMAC = Data(requestData.suffix(8))
        let expectedMAC = try ISO9797MAC.mac(
            key: kmac,
            message: ISO9797Padding.pad(encryptedRequest, blockSize: 8)
        )
        guard requestMAC == expectedMAC else {
            throw NFCError.bacFailed("Mock chip rejected BAC request MAC")
        }

        let decryptedRequest = try CryptoUtils.tripleDESDecrypt(key: kenc, message: encryptedRequest)
        let rndIFD = Data(decryptedRequest[0 ..< 8])
        let rndICCPrime = Data(decryptedRequest[8 ..< 16])
        guard rndICCPrime == rndICC else {
            throw NFCError.bacFailed("Mock chip rejected rndICC")
        }

        var responsePayload = Data()
        responsePayload.append(rndICC)
        responsePayload.append(rndIFD)
        responsePayload.append(kICC)

        let encryptedResponse = try CryptoUtils.tripleDESEncrypt(key: kenc, message: responsePayload)
        let responseMAC = try ISO9797MAC.mac(
            key: kmac,
            message: ISO9797Padding.pad(encryptedResponse, blockSize: 8)
        )
        return ResponseAPDU(data: encryptedResponse + responseMAC, sw1: 0x90, sw2: 0x00)
    }
}
