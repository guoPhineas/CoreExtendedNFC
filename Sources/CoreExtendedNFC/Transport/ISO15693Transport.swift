import CoreNFC
import Foundation

/// Transport adapter wrapping `NFCISO15693Tag`.
public final class ISO15693Transport: ISO15693TagTransporting, @unchecked Sendable {
    private let tag: NFCISO15693Tag

    public var identifier: Data {
        tag.identifier
    }

    public var icManufacturerCode: Int {
        tag.icManufacturerCode
    }

    public var icSerialNumber: Data {
        tag.icSerialNumber
    }

    public init(tag: NFCISO15693Tag) {
        self.tag = tag
    }

    public func send(_ data: Data) async throws -> Data {
        guard !data.isEmpty else {
            throw NFCError.unsupportedOperation("ISO 15693 raw send requires at least one byte (command code)")
        }
        NFCLog.debug("→ SEND \(data.hexDump)", source: "ISO15693")
        let commandCode = Int(data[0])
        let parameters: Data? = data.count > 1 ? Data(data[1...]) : nil
        let response: Data = try await withCheckedThrowingContinuation { continuation in
            tag.sendRequest(
                requestFlags: Int(NFCISO15693RequestFlag.highDataRate.rawValue),
                commandCode: commandCode,
                data: parameters
            ) { result in
                switch result {
                case let .success((_, responseData)):
                    continuation.resume(returning: responseData ?? Data())
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
        NFCLog.debug("← RECV \(response.hexDump)", source: "ISO15693")
        return response
    }

    public func sendAPDU(_: CommandAPDU) async throws -> ResponseAPDU {
        throw NFCError.unsupportedOperation("ISO 15693 does not use ISO 7816 APDUs")
    }

    /// Read a single block.
    public func readBlock(_ number: UInt8) async throws -> Data {
        NFCLog.debug("→ READ_BLOCK #\(number)", source: "ISO15693")
        let data = try await tag.readSingleBlock(requestFlags: [.highDataRate], blockNumber: number)
        NFCLog.debug("← BLOCK #\(number) \(data.hexDump)", source: "ISO15693")
        return data
    }

    /// Write a single block.
    public func writeBlock(_ number: UInt8, data: Data) async throws {
        NFCLog.debug("→ WRITE_BLOCK #\(number) \(data.hexDump)", source: "ISO15693")
        try await tag.writeSingleBlock(
            requestFlags: [.highDataRate],
            blockNumber: number,
            dataBlock: data
        )
        NFCLog.debug("← WRITE_BLOCK #\(number) OK", source: "ISO15693")
    }

    /// Read multiple contiguous blocks.
    public func readBlocks(range: NSRange) async throws -> [Data] {
        NFCLog.debug("→ READ_BLOCKS \(range.location)..\(range.location + range.length - 1)", source: "ISO15693")
        let blocks = try await tag.readMultipleBlocks(requestFlags: [.highDataRate], blockRange: range)
        NFCLog.debug("← READ_BLOCKS \(blocks.count) block(s)", source: "ISO15693")
        return blocks
    }

    /// Get UID, block size, block count, and related system info.
    public func getSystemInfo() async throws -> ISO15693SystemInfo {
        NFCLog.debug("→ GET_SYSTEM_INFO", source: "ISO15693")
        let systemInfo = try await tag.systemInfo(requestFlags: [.highDataRate])
        let info = ISO15693SystemInfo(
            uid: systemInfo.uniqueIdentifier,
            dsfid: UInt8(systemInfo.dataStorageFormatIdentifier),
            afi: UInt8(systemInfo.applicationFamilyIdentifier),
            blockSize: systemInfo.blockSize,
            blockCount: systemInfo.totalBlocks,
            icReference: UInt8(systemInfo.icReference)
        )
        NFCLog.debug("← SYSTEM_INFO blocks=\(info.blockCount) size=\(info.blockSize)", source: "ISO15693")
        return info
    }

    /// Get locked flags for a range of blocks.
    public func getBlockSecurityStatus(range: NSRange) async throws -> [Bool] {
        let statuses = try await tag.getMultipleBlockSecurityStatus(
            requestFlags: [.highDataRate],
            blockRange: range
        )
        return statuses.map { $0 != 0 }
    }

    public func writeAFI(_ afi: UInt8) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            tag.writeAFI(requestFlags: [.highDataRate], afi: afi) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func lockAFI() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            tag.lockAFI(requestFlags: [.highDataRate]) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func writeDSFID(_ dsfid: UInt8) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            tag.writeDSFID(requestFlags: [.highDataRate], dsfid: dsfid) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func lockDSFID() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            tag.lockDSFID(requestFlags: [.highDataRate]) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func customCommand(code: Int, parameters: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            tag.customCommand(
                requestFlags: [.highDataRate],
                customCommandCode: code,
                customRequestParameters: parameters
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    public func challenge(cryptoSuiteIdentifier: Int, message: Data) async throws {
        try await tag.challenge(
            requestFlags: [.highDataRate],
            cryptoSuiteIdentifier: cryptoSuiteIdentifier,
            message: message
        )
    }

    public func authenticate(
        cryptoSuiteIdentifier: Int,
        message: Data
    ) async throws -> ISO15693SecurityResponse {
        let (flags, response) = try await tag.authenticate(
            requestFlags: [.highDataRate],
            cryptoSuiteIdentifier: cryptoSuiteIdentifier,
            message: message
        )
        return ISO15693SecurityResponse(
            responseFlags: Int(flags.rawValue),
            data: response
        )
    }

    public func keyUpdate(
        keyIdentifier: Int,
        message: Data
    ) async throws -> ISO15693SecurityResponse {
        let (flags, response) = try await tag.keyUpdate(
            requestFlags: [.highDataRate],
            keyIdentifier: keyIdentifier,
            message: message
        )
        return ISO15693SecurityResponse(
            responseFlags: Int(flags.rawValue),
            data: response
        )
    }
}
