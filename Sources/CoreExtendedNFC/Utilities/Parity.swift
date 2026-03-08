import Foundation

/// Parity calculation utilities ported from libnfc nfc-utils.c.
public enum Parity {
    /// Compute odd parity bit for a single byte.
    /// Uses the bit manipulation trick from libnfc: lookup via constant 0x9669.
    public static func odd(_ byte: UInt8) -> UInt8 {
        let index = (byte ^ (byte >> 4)) & 0x0F
        return UInt8((0x9669 >> index) & 1)
    }

    /// Compute odd parity bit for each byte in the data.
    public static func oddBytes(_ data: Data) -> Data {
        Data(data.map { odd($0) })
    }
}
