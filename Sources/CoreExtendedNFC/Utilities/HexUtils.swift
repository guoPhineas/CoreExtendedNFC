import Foundation

public extension Data {
    /// Compact hex string: "0A1B2C"
    var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }

    /// Space-separated hex: "0A 1B 2C"
    var hexDump: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Multi-line hex dump with offsets:
    /// 0000: 0A 1B 2C 3D 4E 5F 60 71
    var hexDumpFormatted: String {
        var lines: [String] = []
        for offset in stride(from: 0, to: count, by: 8) {
            let end = Swift.min(offset + 8, count)
            let slice = self[offset ..< end]
            let hex = slice.map { String(format: "%02X", $0) }.joined(separator: " ")
            lines.append(String(format: "%04X: %@", offset, hex))
        }
        return lines.joined(separator: "\n")
    }

    /// Initialize from hex string. Returns nil if the string is not valid hex.
    init?(hexString: String) {
        let cleaned = hexString.replacingOccurrences(of: " ", with: "")
        guard cleaned.count.isMultiple(of: 2) else { return nil }

        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index ..< nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
