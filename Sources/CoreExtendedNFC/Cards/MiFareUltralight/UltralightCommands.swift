import Foundation

/// MIFARE Ultralight / NTAG command builder and sender.
/// Ported from libnfc utils/nfc-mfultralight.c and utils/mifare.h.
public struct UltralightCommands: Sendable {
    public let transport: any NFCTagTransport

    public init(transport: any NFCTagTransport) {
        self.transport = transport
    }

    /// READ (0x30): Read 4 pages (16 bytes) starting at `startPage`.
    public func readPages(startPage: UInt8) async throws -> Data {
        let response = try await transport.send(Data([0x30, startPage]))
        guard response.count >= 16 else {
            throw NFCError.invalidResponse(response)
        }
        return response
    }

    /// WRITE (0xA2): Write 4 bytes to a single page.
    public func writePage(_ page: UInt8, data: Data) async throws {
        guard data.count == 4 else {
            throw NFCError.unsupportedOperation("Write data must be exactly 4 bytes")
        }
        var command = Data([0xA2, page])
        command.append(data)
        let response = try await transport.send(command)
        // ACK is 0x0A (single byte)
        if let firstByte = response.first, firstByte != 0x0A {
            throw NFCError.writeFailed(page: page)
        }
    }

    /// FAST_READ (0x3A): Read a range of pages [start...end] inclusive.
    /// Returns (end - start + 1) × 4 bytes.
    public func fastRead(from start: UInt8, to end: UInt8) async throws -> Data {
        let response = try await transport.send(Data([0x3A, start, end]))
        let expectedLength = Int(end - start + 1) * 4
        guard response.count >= expectedLength else {
            throw NFCError.invalidResponse(response)
        }
        return Data(response.prefix(expectedLength))
    }

    /// COMPATIBILITY WRITE (0xA0): Write 4 bytes using 16-byte frame (Classic-compatible).
    public func compatibilityWrite(_ page: UInt8, data: Data) async throws {
        guard data.count == 4 else {
            throw NFCError.unsupportedOperation("Write data must be exactly 4 bytes")
        }
        var command = Data([0xA0, page])
        command.append(data)
        // Pad to 16 bytes total payload
        command.append(Data(repeating: 0x00, count: 12))
        let response = try await transport.send(command)
        if let firstByte = response.first, firstByte != 0x0A {
            throw NFCError.writeFailed(page: page)
        }
    }
}
