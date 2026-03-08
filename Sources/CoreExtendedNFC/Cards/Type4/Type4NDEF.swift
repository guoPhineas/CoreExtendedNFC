import Foundation

/// Type 4 Capability Container parsed from CC file.
public struct Type4CC: Sendable {
    /// CC file length.
    public let ccLen: UInt16
    /// Mapping version.
    public let mappingVersion: UInt8
    /// Maximum R-APDU data size (MLe).
    public let mle: UInt16
    /// Maximum C-APDU data size (MLc).
    public let mlc: UInt16
    /// NDEF file control TLV — file ID.
    public let ndefFileID: Data
    /// Maximum NDEF file size.
    public let ndefMaxSize: UInt16
    /// Read access: 0x00 = free.
    public let readAccess: UInt8
    /// Write access: 0x00 = free, 0xFF = denied.
    public let writeAccess: UInt8

    /// Parse a CC file (minimum 15 bytes for T4T v2.0).
    public init(data: Data) throws {
        guard data.count >= 15 else {
            throw NFCError.invalidResponse(data)
        }
        let d = Array(data)
        ccLen = UInt16(d[0]) << 8 | UInt16(d[1])
        mappingVersion = d[2]
        mle = UInt16(d[3]) << 8 | UInt16(d[4])
        mlc = UInt16(d[5]) << 8 | UInt16(d[6])

        // NDEF File Control TLV: T=0x04, L=0x06, then V
        guard d[7] == 0x04, d[8] == 0x06 else {
            throw NFCError.invalidResponse(data)
        }
        ndefFileID = Data([d[9], d[10]])
        ndefMaxSize = UInt16(d[11]) << 8 | UInt16(d[12])
        readAccess = d[13]
        writeAccess = d[14]
    }
}

/// Type 4 NDEF tag reader.
/// Ported from libnfc examples/nfc-emulate-forum-tag4.c.
public struct Type4Reader: Sendable {
    public let transport: any NFCTagTransport

    public init(transport: any NFCTagTransport) {
        self.transport = transport
    }

    /// Full NDEF read sequence:
    /// SELECT AID → SELECT CC → READ CC → SELECT NDEF → READ NDEF.
    public func readNDEF() async throws -> Data {
        NFCLog.info("Type 4 NDEF read", source: "Type4")
        // 1. SELECT NDEF application
        let selectAID = CommandAPDU.select(aid: Type4Constants.ndefAID)
        let aidResp = try await transport.sendAPDU(selectAID)
        guard aidResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(aidResp.sw1, aidResp.sw2)
        }

        // 2. SELECT CC file
        let selectCC = CommandAPDU.selectFile(id: Type4Constants.ccFileID)
        let ccSelectResp = try await transport.sendAPDU(selectCC)
        guard ccSelectResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(ccSelectResp.sw1, ccSelectResp.sw2)
        }

        // 3. READ CC file
        let readCC = CommandAPDU.readBinary(offset: 0, length: 15)
        let ccResp = try await transport.sendAPDU(readCC)
        guard ccResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(ccResp.sw1, ccResp.sw2)
        }
        let cc = try Type4CC(data: ccResp.data)

        // 4. SELECT NDEF file
        let selectNDEF = CommandAPDU.selectFile(id: cc.ndefFileID)
        let ndefSelectResp = try await transport.sendAPDU(selectNDEF)
        guard ndefSelectResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(ndefSelectResp.sw1, ndefSelectResp.sw2)
        }

        // 5. Read NDEF length (first 2 bytes)
        let readLen = CommandAPDU.readBinary(offset: 0, length: 2)
        let lenResp = try await transport.sendAPDU(readLen)
        guard lenResp.isSuccess, lenResp.data.count >= 2 else {
            throw NFCError.invalidResponse(lenResp.data)
        }
        let ndefLen = Int(lenResp.data.uint16BE)
        guard ndefLen > 0 else { return Data() }
        NFCLog.debug("NDEF length=\(ndefLen), reading in chunks (MLe=\(cc.mle))", source: "Type4")

        // 6. Read NDEF message in chunks
        let maxRead = min(Int(cc.mle), 255)
        var ndefData = Data()
        var offset: UInt16 = 2 // skip length bytes

        while ndefData.count < ndefLen {
            let remaining = ndefLen - ndefData.count
            let readSize = UInt8(min(remaining, maxRead))
            let readAPDU = CommandAPDU.readBinary(offset: offset, length: readSize)
            let resp = try await transport.sendAPDU(readAPDU)
            guard resp.isSuccess else {
                throw NFCError.unexpectedStatusWord(resp.sw1, resp.sw2)
            }
            ndefData.append(resp.data)
            offset += UInt16(resp.data.count)
        }

        return Data(ndefData.prefix(ndefLen))
    }

    /// Read and parse the Capability Container.
    public func readCapabilityContainer() async throws -> Type4CC {
        let selectAID = CommandAPDU.select(aid: Type4Constants.ndefAID)
        let aidResp = try await transport.sendAPDU(selectAID)
        guard aidResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(aidResp.sw1, aidResp.sw2)
        }

        let selectCC = CommandAPDU.selectFile(id: Type4Constants.ccFileID)
        let ccSelectResp = try await transport.sendAPDU(selectCC)
        guard ccSelectResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(ccSelectResp.sw1, ccSelectResp.sw2)
        }

        let readCC = CommandAPDU.readBinary(offset: 0, length: 15)
        let ccResp = try await transport.sendAPDU(readCC)
        guard ccResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(ccResp.sw1, ccResp.sw2)
        }

        return try Type4CC(data: ccResp.data)
    }

    /// Write NDEF message to Type 4 tag.
    public func writeNDEF(_ message: Data) async throws {
        NFCLog.info("Type 4 NDEF write: \(message.count) bytes", source: "Type4")
        // 1. SELECT NDEF application
        let selectAID = CommandAPDU.select(aid: Type4Constants.ndefAID)
        let aidResp = try await transport.sendAPDU(selectAID)
        guard aidResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(aidResp.sw1, aidResp.sw2)
        }

        // 2. Read CC to get NDEF file info and limits
        let selectCC = CommandAPDU.selectFile(id: Type4Constants.ccFileID)
        let ccSelectResp = try await transport.sendAPDU(selectCC)
        guard ccSelectResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(ccSelectResp.sw1, ccSelectResp.sw2)
        }
        let readCC = CommandAPDU.readBinary(offset: 0, length: 15)
        let ccResp = try await transport.sendAPDU(readCC)
        guard ccResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(ccResp.sw1, ccResp.sw2)
        }
        let cc = try Type4CC(data: ccResp.data)

        guard cc.writeAccess == 0x00 else {
            throw NFCError.tagLocked
        }
        guard message.count + 2 <= cc.ndefMaxSize else {
            throw NFCError.unsupportedOperation("NDEF message too large for tag")
        }

        // 3. SELECT NDEF file
        let selectNDEF = CommandAPDU.selectFile(id: cc.ndefFileID)
        let ndefResp = try await transport.sendAPDU(selectNDEF)
        guard ndefResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(ndefResp.sw1, ndefResp.sw2)
        }

        // 4. Write NDEF length = 0 (indicates write in progress)
        let zeroLen = CommandAPDU.updateBinary(offset: 0, data: Data([0x00, 0x00]))
        let zeroResp = try await transport.sendAPDU(zeroLen)
        guard zeroResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(zeroResp.sw1, zeroResp.sw2)
        }

        // 5. Write NDEF data in chunks
        let maxWrite = min(Int(cc.mlc), 255)
        var offset: UInt16 = 2
        var remaining = message
        while !remaining.isEmpty {
            let chunkSize = min(remaining.count, maxWrite)
            let chunk = Data(remaining.prefix(chunkSize))
            let writeAPDU = CommandAPDU.updateBinary(offset: offset, data: chunk)
            let writeResp = try await transport.sendAPDU(writeAPDU)
            guard writeResp.isSuccess else {
                throw NFCError.unexpectedStatusWord(writeResp.sw1, writeResp.sw2)
            }
            remaining = Data(remaining.dropFirst(chunkSize))
            offset += UInt16(chunkSize)
        }

        // 6. Write actual NDEF length
        let lenBytes = Data([
            UInt8((message.count >> 8) & 0xFF),
            UInt8(message.count & 0xFF),
        ])
        let lenAPDU = CommandAPDU.updateBinary(offset: 0, data: lenBytes)
        let lenResp = try await transport.sendAPDU(lenAPDU)
        guard lenResp.isSuccess else {
            throw NFCError.unexpectedStatusWord(lenResp.sw1, lenResp.sw2)
        }
    }
}
