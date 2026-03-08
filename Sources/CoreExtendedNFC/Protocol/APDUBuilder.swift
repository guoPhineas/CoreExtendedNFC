import Foundation

/// ISO 7816-4 Command APDU.
public struct CommandAPDU: Sendable, Equatable {
    public let cla: UInt8
    public let ins: UInt8
    public let p1: UInt8
    public let p2: UInt8
    public let data: Data?
    public let le: UInt8?

    public init(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, data: Data? = nil, le: UInt8? = nil) {
        self.cla = cla
        self.ins = ins
        self.p1 = p1
        self.p2 = p2
        self.data = data
        self.le = le
    }

    /// Encode to raw bytes: `[CLA, INS, P1, P2, (Lc, Data...,) (Le)]`.
    public var bytes: Data {
        var result = Data([cla, ins, p1, p2])
        if let data, !data.isEmpty {
            result.append(UInt8(data.count))
            result.append(data)
        }
        if let le {
            result.append(le)
        }
        return result
    }

    /// CoreNFC rejects `0` here. In short APDU encoding, `Le == 0x00` means 256 bytes.
    var nfcExpectedResponseLength: Int {
        guard let le else { return -1 }
        return le == 0x00 ? 256 : Int(le)
    }

    /// Wrap a DESFire native command in ISO 7816 framing.
    /// Format: [0x90, CMD, 0x00, 0x00, LEN, DATA..., 0x00]
    public static func desfireWrap(command: UInt8, data: Data? = nil) -> CommandAPDU {
        CommandAPDU(
            cla: 0x90,
            ins: command,
            p1: 0x00,
            p2: 0x00,
            data: data,
            le: 0x00
        )
    }

    // MARK: - Common APDUs

    /// SELECT by AID (DF name).
    public static func select(aid: Data) -> CommandAPDU {
        CommandAPDU(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00, data: aid, le: 0x00)
    }

    /// SELECT by file ID.
    public static func selectFile(id: Data) -> CommandAPDU {
        CommandAPDU(cla: 0x00, ins: 0xA4, p1: 0x00, p2: 0x0C, data: id)
    }

    /// READ BINARY from current file.
    public static func readBinary(offset: UInt16, length: UInt8) -> CommandAPDU {
        CommandAPDU(
            cla: 0x00,
            ins: 0xB0,
            p1: UInt8((offset >> 8) & 0x7F),
            p2: UInt8(offset & 0xFF),
            le: length
        )
    }

    /// UPDATE BINARY to current file.
    public static func updateBinary(offset: UInt16, data: Data) -> CommandAPDU {
        CommandAPDU(
            cla: 0x00,
            ins: 0xD6,
            p1: UInt8((offset >> 8) & 0x7F),
            p2: UInt8(offset & 0xFF),
            data: data
        )
    }

    /// GET RESPONSE for chained responses (`SW1 == 0x61`).
    public static func getResponse(length: UInt8) -> CommandAPDU {
        CommandAPDU(cla: 0x00, ins: 0xC0, p1: 0x00, p2: 0x00, le: length)
    }
}

/// ISO 7816-4 Response APDU.
public struct ResponseAPDU: Sendable, Equatable {
    public let data: Data
    public let sw1: UInt8
    public let sw2: UInt8

    public init(data: Data, sw1: UInt8, sw2: UInt8) {
        self.data = data
        self.sw1 = sw1
        self.sw2 = sw2
    }

    /// Parse a raw response where the last 2 bytes are SW1 and SW2.
    public init?(rawResponse: Data) {
        guard rawResponse.count >= 2 else { return nil }
        data = rawResponse.dropLast(2)
        sw1 = rawResponse[rawResponse.endIndex - 2]
        sw2 = rawResponse[rawResponse.endIndex - 1]
    }

    /// Status word as combined UInt16.
    public var statusWord: UInt16 {
        UInt16(sw1) << 8 | UInt16(sw2)
    }

    /// `true` when `SW1 == 0x90` and `SW2 == 0x00`.
    public var isSuccess: Bool {
        sw1 == 0x90 && sw2 == 0x00
    }

    /// `true` when more data is available via GET RESPONSE.
    public var needsGetResponse: Bool {
        sw1 == 0x61
    }

    /// `true` when the card requests a DESFire Additional Frame.
    public var hasMoreFrames: Bool {
        sw1 == 0x91 && sw2 == 0xAF
    }
}
