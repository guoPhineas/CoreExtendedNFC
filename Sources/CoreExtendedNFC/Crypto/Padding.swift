import Foundation

/// ISO/IEC 9797-1 Method 2 padding used by ICAO 9303 secure messaging.
/// Reference: ISO/IEC 9797-1:2011, Padding Method 2.
public enum ISO9797Padding {
    /// Append `0x80`, then `0x00` bytes until the result is a multiple of `blockSize`.
    static func pad(_ data: Data, blockSize: Int) -> Data {
        var padded = data
        padded.append(0x80)
        while padded.count % blockSize != 0 {
            padded.append(0x00)
        }
        return padded
    }

    /// Remove ISO/IEC 9797-1 Method 2 padding if present.
    static func unpad(_ data: Data) -> Data {
        guard !data.isEmpty else { return data }
        var idx = data.count - 1
        while idx >= 0, data[idx] == 0x00 {
            idx -= 1
        }
        guard idx >= 0, data[idx] == 0x80 else {
            return data
        }
        return data.prefix(idx)
    }
}
