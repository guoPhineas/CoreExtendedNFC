import CoreNFC
import Foundation

/// Transport adapter wrapping `NFCISO7816Tag`.
public final class ISO7816Transport: ISO7816TagTransporting, @unchecked Sendable {
    private let tag: NFCISO7816Tag

    public var identifier: Data {
        tag.identifier
    }

    public var initialAID: String {
        tag.initialSelectedAID
    }

    public init(tag: NFCISO7816Tag) {
        self.tag = tag
    }

    public func send(_: Data) async throws -> Data {
        throw NFCError.unsupportedOperation("Use sendAPDU for ISO 7816 tags")
    }

    public func sendAPDU(_ apdu: CommandAPDU) async throws -> ResponseAPDU {
        NFCLog.debug("→ APDU \(apdu.bytes.hexDump)", source: "ISO7816")
        let nfcAPDU = NFCISO7816APDU(
            instructionClass: apdu.cla,
            instructionCode: apdu.ins,
            p1Parameter: apdu.p1,
            p2Parameter: apdu.p2,
            data: apdu.data ?? Data(),
            expectedResponseLength: apdu.nfcExpectedResponseLength
        )
        let (data, sw1, sw2) = try await tag.sendCommand(apdu: nfcAPDU)
        NFCLog.debug("← SW:\(String(format: "%02X%02X", sw1, sw2)) \(data.hexDump)", source: "ISO7816")
        return ResponseAPDU(data: data, sw1: sw1, sw2: sw2)
    }

    /// Send an APDU and follow `GET RESPONSE` chaining when needed.
    public func sendAPDUWithChaining(_ apdu: CommandAPDU) async throws -> ResponseAPDU {
        var response = try await sendAPDU(apdu)
        var fullData = response.data
        var chainCount = 0

        while response.needsGetResponse {
            chainCount += 1
            let getResp = CommandAPDU.getResponse(length: response.sw2)
            response = try await sendAPDU(getResp)
            fullData.append(response.data)
        }

        if chainCount > 0 {
            NFCLog.debug("Chaining complete: \(chainCount) GET RESPONSE(s), total \(fullData.count) bytes", source: "ISO7816")
        }

        return ResponseAPDU(data: fullData, sw1: response.sw1, sw2: response.sw2)
    }
}
