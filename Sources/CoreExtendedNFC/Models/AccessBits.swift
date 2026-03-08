import Foundation

/// Decodes MIFARE Classic sector trailer access bytes into per-block permissions.
public struct AccessBits: Sendable {
    /// Access conditions for a single block.
    public struct BlockAccess: Sendable, Equatable {
        /// C1 bit for this block.
        public let c1: Bool
        /// C2 bit for this block.
        public let c2: Bool
        /// C3 bit for this block.
        public let c3: Bool

        /// Combined access bits as a 3-bit value (C1 | C2<<1 | C3<<2).
        public var condition: UInt8 {
            (c1 ? 1 : 0) | (c2 ? 2 : 0) | (c3 ? 4 : 0)
        }
    }

    /// Decodes the sector trailer access bytes.
    /// Expects bytes 6-9 and returns access for blocks 0-2 plus the trailer block.
    /// Returns `nil` when the complement bits are invalid.
    public static func decode(_ bytes: Data) -> [BlockAccess]? {
        guard bytes.count >= 3 else { return nil }

        let byte6 = bytes[bytes.startIndex]
        let byte7 = bytes[bytes.startIndex + 1]
        let byte8 = bytes[bytes.startIndex + 2]

        let c1 = (byte7 >> 4) & 0x0F
        let c2 = byte8 & 0x0F
        let c3 = (byte8 >> 4) & 0x0F

        let c1_inv = byte6 & 0x0F
        let c2_inv = (byte6 >> 4) & 0x0F
        let c3_inv = byte7 & 0x0F

        guard c1 ^ c1_inv == 0x0F,
              c2 ^ c2_inv == 0x0F,
              c3 ^ c3_inv == 0x0F
        else {
            return nil
        }

        var result: [BlockAccess] = []
        for block in 0 ..< 4 {
            let b1: Bool = (c1 >> block) & 1 == 1
            let b2: Bool = (c2 >> block) & 1 == 1
            let b3: Bool = (c3 >> block) & 1 == 1
            result.append(BlockAccess(c1: b1, c2: b2, c3: b3))
        }
        return result
    }

    /// Default access bits (most permissive): 0xFF 0x07 0x80 0x69
    public static let defaultBytes = Data([0xFF, 0x07, 0x80, 0x69])
}
