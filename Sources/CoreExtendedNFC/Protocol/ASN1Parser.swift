import Foundation

/// A parsed BER-TLV node.
///
/// Reference: ITU-T X.690 (2021) BER/DER encoding rules.
/// https://www.itu.int/rec/T-REC-X.690
public struct TLVNode: Sendable, Equatable {
    /// Tag value (1, 2, or 3 bytes encoded as UInt).
    public let tag: UInt

    /// Decoded length of the value.
    public let length: Int

    /// Raw value bytes.
    public let value: Data

    /// Whether the first tag byte marks this as a constructed node.
    public var isConstructed: Bool {
        let firstTagByte: UInt = if tag <= 0xFF {
            tag
        } else if tag <= 0xFFFF {
            tag >> 8
        } else {
            tag >> 16
        }

        return (firstTagByte & 0x20) != 0
    }

    /// Parse the value as a sequence of child TLV nodes.
    /// Only valid for constructed nodes.
    public func children() throws -> [TLVNode] {
        try ASN1Parser.parseTLV(value)
    }
}

/// BER-TLV parser used by ICAO 9303 data groups and related ASN.1 payloads.
///
/// Supports:
/// - Multi-byte tags (e.g., 0x5F1F, 0x7F61)
/// - Multi-byte lengths (short form, 0x81 XX, 0x82 XX XX, 0x83 XX XX XX)
/// - Recursive parsing of constructed nodes
public enum ASN1Parser {
    /// Parse all TLV nodes from the given data.
    public static func parseTLV(_ data: Data) throws -> [TLVNode] {
        var nodes: [TLVNode] = []
        var offset = 0

        while offset < data.count {
            // Skip zero padding.
            if data[offset] == 0x00 {
                offset += 1
                continue
            }

            let (tag, tagBytes) = try parseTag(data, at: offset)
            offset += tagBytes

            guard offset < data.count else {
                throw NFCError.dataGroupParseFailed("Unexpected end of data after tag \(String(format: "0x%02X", tag))")
            }

            let (length, lengthBytes) = try parseLength(data, at: offset)
            offset += lengthBytes

            guard offset + length <= data.count else {
                throw NFCError.dataGroupParseFailed(
                    "TLV length \(length) exceeds data at offset \(offset), available \(data.count - offset)"
                )
            }

            let value = Data(data[offset ..< offset + length])
            offset += length

            nodes.append(TLVNode(tag: tag, length: length, value: value))
        }

        return nodes
    }

    /// Parse a tag at the given offset. Returns (tag, bytesConsumed).
    public static func parseTag(_ data: Data, at offset: Int) throws -> (UInt, Int) {
        guard offset < data.count else {
            throw NFCError.dataGroupParseFailed("Cannot parse tag: offset \(offset) out of bounds")
        }

        let firstByte = data[offset]

        // Single-byte tag: lower 5 bits are not all 1.
        if (firstByte & 0x1F) != 0x1F {
            return (UInt(firstByte), 1)
        }

        // Multi-byte tag: lower 5 bits are all 1.
        guard offset + 1 < data.count else {
            throw NFCError.dataGroupParseFailed("Incomplete multi-byte tag at offset \(offset)")
        }

        var tag = UInt(firstByte)
        var pos = offset + 1

        // Continuation bytes keep bit 8 set.
        repeat {
            guard pos < data.count else {
                throw NFCError.dataGroupParseFailed("Incomplete multi-byte tag at offset \(offset)")
            }
            tag = (tag << 8) | UInt(data[pos])
            pos += 1
        } while data[pos - 1] & 0x80 != 0

        return (tag, pos - offset)
    }

    /// Parse a BER length at the given offset. Returns (length, bytesConsumed).
    public static func parseLength(_ data: Data, at offset: Int) throws -> (Int, Int) {
        guard offset < data.count else {
            throw NFCError.dataGroupParseFailed("Cannot parse length: offset \(offset) out of bounds")
        }

        let firstByte = data[offset]

        // Short form: bit 8 is 0.
        if firstByte & 0x80 == 0 {
            return (Int(firstByte), 1)
        }

        // Long form: low 7 bits encode the number of length bytes.
        let numBytes = Int(firstByte & 0x7F)

        // Indefinite length is not supported.
        guard numBytes > 0 else {
            throw NFCError.dataGroupParseFailed("Indefinite length not supported")
        }

        guard offset + 1 + numBytes <= data.count else {
            throw NFCError.dataGroupParseFailed("Incomplete length encoding at offset \(offset)")
        }

        var length = 0
        for i in 0 ..< numBytes {
            length = (length << 8) | Int(data[offset + 1 + i])
        }

        return (length, 1 + numBytes)
    }

    /// Encode a length value to BER format.
    public static func encodeLength(_ length: Int) -> Data {
        if length < 0x80 {
            Data([UInt8(length)])
        } else if length <= 0xFF {
            Data([0x81, UInt8(length)])
        } else if length <= 0xFFFF {
            Data([0x82, UInt8(length >> 8), UInt8(length & 0xFF)])
        } else {
            Data([
                0x83,
                UInt8((length >> 16) & 0xFF),
                UInt8((length >> 8) & 0xFF),
                UInt8(length & 0xFF),
            ])
        }
    }

    /// Encode a complete TLV structure.
    public static func encodeTLV(tag: UInt, value: Data) -> Data {
        var result = Data()

        // Encode tag
        if tag <= 0xFF {
            result.append(UInt8(tag))
        } else if tag <= 0xFFFF {
            result.append(UInt8(tag >> 8))
            result.append(UInt8(tag & 0xFF))
        } else {
            result.append(UInt8((tag >> 16) & 0xFF))
            result.append(UInt8((tag >> 8) & 0xFF))
            result.append(UInt8(tag & 0xFF))
        }

        result.append(encodeLength(value.count))
        result.append(value)
        return result
    }

    /// Find the first node with the given tag in a parsed TLV sequence.
    public static func findTag(_ tag: UInt, in nodes: [TLVNode]) -> TLVNode? {
        for node in nodes {
            if node.tag == tag {
                return node
            }
            if node.isConstructed, let children = try? node.children() {
                if let found = findTag(tag, in: children) {
                    return found
                }
            }
        }
        return nil
    }
}
