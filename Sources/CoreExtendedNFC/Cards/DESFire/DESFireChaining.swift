import Foundation

extension DESFireCommands {
    /// Send command and collect all AF (Additional Frame) responses into a single buffer.
    func sendWithChaining(_ cmd: UInt8, data: Data?) async throws -> Data {
        NFCLog.debug("DESFire CMD \(String(format: "0x%02X", cmd))\(data.map { " data=\($0.hexDump)" } ?? "")", source: "DESFire")
        let apdu = CommandAPDU.desfireWrap(command: cmd, data: data)
        var response = try await transport.sendAPDU(apdu)
        var result = response.data

        // Keep sending AF frames while the card indicates more data
        var afCount = 0
        while response.hasMoreFrames {
            afCount += 1
            let afAPDU = CommandAPDU.desfireWrap(command: Self.ADDITIONAL_FRAME)
            response = try await transport.sendAPDU(afAPDU)
            result.append(response.data)
        }

        if afCount > 0 {
            NFCLog.debug("DESFire AF chaining: \(afCount) frame(s), total \(result.count) bytes", source: "DESFire")
        }

        // Check final status
        guard response.sw1 == 0x91, response.sw2 == 0x00 else {
            if let status = DESFireStatus(rawValue: response.sw2) {
                NFCLog.error("DESFire error: \(status)", source: "DESFire")
                throw NFCError.desfireError(status)
            }
            throw NFCError.unexpectedStatusWord(response.sw1, response.sw2)
        }

        return result
    }
}
