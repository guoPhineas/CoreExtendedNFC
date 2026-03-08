import Foundation

/// ICAO 9303 key derivation for BAC.
/// Reference: ICAO Doc 9303 Part 11, Section 9.7.1.
/// https://www.icao.int/publications/Documents/9303_p11_cons_en.pdf
/// Cross-ref: JMRTD Util.computeKeySeedForBAC()
/// https://github.com/jmrtd/jmrtd/blob/master/jmrtd/src/main/java/org/jmrtd/Util.java
public enum KeyDerivation {
    /// Key derivation mode counter.
    public enum Mode: UInt8, Sendable {
        /// Encryption key derivation (counter = 1).
        case enc = 1
        /// MAC key derivation (counter = 2).
        case mac = 2
        /// PACE key derivation (counter = 3).
        case pace = 3
    }

    /// Generate `Kseed = SHA-1(MRZKey.utf8)[0..<16]` from the MRZ key string.
    static func generateKseed(mrzKey: String) -> Data {
        let hash = HashUtils.sha1(Data(mrzKey.utf8))
        return Data(hash.prefix(16))
    }

    /// Derive a 16-byte 2-key 3DES key from `keySeed` and the ICAO mode counter.
    static func deriveKey(keySeed: Data, mode: Mode) -> Data {
        var input = keySeed
        input.append(contentsOf: [0x00, 0x00, 0x00, mode.rawValue])
        let hash = HashUtils.sha1(input)

        let ka = adjustParity(Data(hash[0 ..< 8]))
        let kb = adjustParity(Data(hash[8 ..< 16]))
        return ka + kb
    }

    /// Adjust DES key bytes to odd parity.
    static func adjustParity(_ key: Data) -> Data {
        var adjusted = key
        for i in 0 ..< adjusted.count {
            let byte = adjusted[i]
            let bits = (byte >> 1).nonzeroBitCount
            if bits % 2 == 0 {
                adjusted[i] = (byte & 0xFE) | 0x01
            } else {
                adjusted[i] = byte & 0xFE
            }
        }
        return adjusted
    }
}
