import Foundation

/// NTAG-specific commands extending the Ultralight command set.
public extension UltralightCommands {
    /// READ_SIG (0x3C 0x00): Read 32-byte ECC signature from NXP chip.
    /// The signature can be verified against NXP's public key to prove chip authenticity.
    func readSignature() async throws -> Data {
        let response = try await transport.send(Data([0x3C, 0x00]))
        guard response.count >= 32 else {
            throw NFCError.invalidResponse(response)
        }
        return Data(response.prefix(32))
    }

    /// READ_CNT (0x39 counter): Read 3-byte NFC counter.
    /// Counter 0x02 is the NFC counter (auto-incremented on each field activation if enabled).
    func readCounter(counterID: UInt8 = 0x02) async throws -> UInt32 {
        let response = try await transport.send(Data([0x39, counterID]))
        guard response.count >= 3 else {
            throw NFCError.invalidResponse(response)
        }
        // Counter is 3 bytes, little-endian
        return UInt32(response[0])
            | UInt32(response[1]) << 8
            | UInt32(response[2]) << 16
    }
}
