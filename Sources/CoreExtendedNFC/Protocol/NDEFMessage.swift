import Foundation

/// NFC Forum NDEF Type Name Format values.
public enum NDEFTypeNameFormat: UInt8, Sendable, Equatable {
    case empty = 0x00
    case wellKnown = 0x01
    case mimeMedia = 0x02
    case absoluteURI = 0x03
    case external = 0x04
    case unknown = 0x05
    case unchanged = 0x06
    case reserved = 0x07
}

/// Parsed representation of an NDEF message.
public struct NDEFMessage: Sendable, Equatable {
    public let records: [NDEFRecord]

    public init(records: [NDEFRecord]) {
        self.records = records
    }

    public init(data: Data) throws {
        records = try NDEFRecord.parseMessage(data)
    }

    public var data: Data {
        NDEFRecord.serializeMessage(records)
    }

    public static func text(_ text: String, languageCode: String = "en") -> NDEFMessage {
        NDEFMessage(records: [.text(text, languageCode: languageCode)])
    }

    public static func uri(_ uri: String) -> NDEFMessage {
        NDEFMessage(records: [.uri(uri)])
    }
}

/// Parsed representation of one NDEF record.
public struct NDEFRecord: Sendable, Equatable {
    public enum Payload: Sendable, Equatable {
        case empty
        case text(languageCode: String, text: String)
        case uri(String)
        case mime(type: String, data: Data)
        case smartPoster(uri: String?, title: String?)
        case external(type: String, data: Data)
        case unknown(data: Data)
    }

    public let typeNameFormat: NDEFTypeNameFormat
    public let type: Data
    public let identifier: Data
    public let payload: Data

    public init(
        typeNameFormat: NDEFTypeNameFormat,
        type: Data,
        identifier: Data = Data(),
        payload: Data
    ) {
        self.typeNameFormat = typeNameFormat
        self.type = type
        self.identifier = identifier
        self.payload = payload
    }

    public var parsedPayload: Payload {
        switch typeNameFormat {
        case .empty:
            return .empty
        case .wellKnown:
            if type == Data([0x54]) {
                return Self.parseTextPayload(payload)
            }
            if type == Data([0x55]) {
                return Self.parseURIPayload(payload)
            }
            if type == Data([0x53, 0x70]) {
                return Self.parseSmartPoster(payload)
            }
        case .mimeMedia:
            return .mime(type: String(data: type, encoding: .utf8) ?? type.hexString, data: payload)
        case .absoluteURI:
            return .uri(String(data: payload, encoding: .utf8) ?? payload.hexString)
        case .external:
            return .external(type: String(data: type, encoding: .utf8) ?? type.hexString, data: payload)
        case .unknown, .unchanged, .reserved:
            break
        }

        return .unknown(data: payload)
    }

    public var displayType: String {
        switch parsedPayload {
        case .empty:
            "Empty"
        case .text:
            "Text"
        case .uri:
            "URI"
        case let .mime(type, _):
            "MIME: \(type)"
        case .smartPoster:
            "Smart Poster"
        case let .external(type, _):
            "External: \(type)"
        case .unknown:
            type.isEmpty ? "Unknown" : "Type \(String(data: type, encoding: .utf8) ?? type.hexString)"
        }
    }

    public var displayValue: String {
        switch parsedPayload {
        case .empty:
            return "No payload"
        case let .text(languageCode, text):
            return "[\(languageCode)] \(text)"
        case let .uri(uri):
            return uri
        case let .mime(type, data):
            return "\(type) (\(data.count) bytes)"
        case let .smartPoster(uri, title):
            let resolvedTitle = title ?? "Untitled"
            return [resolvedTitle, uri].compactMap(\.self).joined(separator: " · ")
        case let .external(_, data):
            return "\(data.count) bytes"
        case let .unknown(data):
            return "\(data.count) bytes"
        }
    }

    public static func text(_ text: String, languageCode: String = "en") -> NDEFRecord {
        let language = Data(languageCode.utf8)
        let encodedText = Data(text.utf8)
        let status = UInt8(language.count & 0x3F)
        return NDEFRecord(
            typeNameFormat: .wellKnown,
            type: Data([0x54]),
            payload: Data([status]) + language + encodedText
        )
    }

    public static func uri(_ uri: String) -> NDEFRecord {
        let (prefixCode, suffix) = abbreviateURI(uri)
        return NDEFRecord(
            typeNameFormat: .wellKnown,
            type: Data([0x55]),
            payload: Data([prefixCode]) + Data(suffix.utf8)
        )
    }

    public static func mime(type: String, data: Data) -> NDEFRecord {
        NDEFRecord(typeNameFormat: .mimeMedia, type: Data(type.utf8), payload: data)
    }

    public static func external(type: String, data: Data) -> NDEFRecord {
        NDEFRecord(typeNameFormat: .external, type: Data(type.utf8), payload: data)
    }

    public static func smartPoster(uri: String, title: String? = nil) -> NDEFRecord {
        var embeddedRecords = [NDEFRecord.uri(uri)]
        if let title {
            embeddedRecords.append(.text(title))
        }
        return NDEFRecord(
            typeNameFormat: .wellKnown,
            type: Data([0x53, 0x70]),
            payload: serializeMessage(embeddedRecords)
        )
    }

    static func parseMessage(_ data: Data) throws -> [NDEFRecord] {
        var records: [NDEFRecord] = []
        var offset = 0
        var sawMessageBegin = false
        var sawMessageEnd = false

        while offset < data.count {
            let header = data[offset]
            offset += 1

            let messageBegin = (header & 0x80) != 0
            let messageEnd = (header & 0x40) != 0
            let chunkFlag = (header & 0x20) != 0
            let shortRecord = (header & 0x10) != 0
            let idLengthPresent = (header & 0x08) != 0
            let tnfValue = header & 0x07

            guard !chunkFlag else {
                throw NFCError.unsupportedOperation("Chunked NDEF records are not supported")
            }
            guard let tnf = NDEFTypeNameFormat(rawValue: tnfValue) else {
                throw NFCError.invalidResponse(Data([tnfValue]))
            }
            guard offset < data.count else {
                throw NFCError.invalidResponse(data)
            }

            let typeLength = Int(data[offset])
            offset += 1

            let payloadLength: Int
            if shortRecord {
                guard offset < data.count else {
                    throw NFCError.invalidResponse(data)
                }
                payloadLength = Int(data[offset])
                offset += 1
            } else {
                guard offset + 4 <= data.count else {
                    throw NFCError.invalidResponse(data)
                }
                payloadLength = Int(Data(data[offset ..< offset + 4]).uint32BE)
                offset += 4
            }

            let identifierLength: Int
            if idLengthPresent {
                guard offset < data.count else {
                    throw NFCError.invalidResponse(data)
                }
                identifierLength = Int(data[offset])
                offset += 1
            } else {
                identifierLength = 0
            }

            guard offset + typeLength + identifierLength + payloadLength <= data.count else {
                throw NFCError.invalidResponse(data)
            }

            let type = Data(data[offset ..< offset + typeLength])
            offset += typeLength
            let identifier = Data(data[offset ..< offset + identifierLength])
            offset += identifierLength
            let payload = Data(data[offset ..< offset + payloadLength])
            offset += payloadLength

            sawMessageBegin = sawMessageBegin || messageBegin
            sawMessageEnd = sawMessageEnd || messageEnd

            records.append(
                NDEFRecord(
                    typeNameFormat: tnf,
                    type: type,
                    identifier: identifier,
                    payload: payload
                )
            )

            if messageEnd {
                break
            }
        }

        guard sawMessageBegin, sawMessageEnd, !records.isEmpty else {
            throw NFCError.invalidResponse(data)
        }

        return records
    }

    static func serializeMessage(_ records: [NDEFRecord]) -> Data {
        records.enumerated().reduce(into: Data()) { result, pair in
            let (index, record) = pair
            let messageBegin = index == 0
            let messageEnd = index == records.count - 1
            let shortRecord = record.payload.count < 256
            let hasIdentifier = !record.identifier.isEmpty

            var header = record.typeNameFormat.rawValue
            if messageBegin { header |= 0x80 }
            if messageEnd { header |= 0x40 }
            if shortRecord { header |= 0x10 }
            if hasIdentifier { header |= 0x08 }

            result.append(header)
            result.append(UInt8(record.type.count))
            if shortRecord {
                result.append(UInt8(record.payload.count))
            } else {
                let length = UInt32(record.payload.count)
                result.append(contentsOf: [
                    UInt8((length >> 24) & 0xFF),
                    UInt8((length >> 16) & 0xFF),
                    UInt8((length >> 8) & 0xFF),
                    UInt8(length & 0xFF),
                ])
            }
            if hasIdentifier {
                result.append(UInt8(record.identifier.count))
            }
            result.append(record.type)
            if hasIdentifier {
                result.append(record.identifier)
            }
            result.append(record.payload)
        }
    }

    private static func parseTextPayload(_ payload: Data) -> Payload {
        guard let status = payload.first else {
            return .unknown(data: payload)
        }
        let usesUTF16 = (status & 0x80) != 0
        let languageLength = Int(status & 0x3F)
        guard payload.count >= 1 + languageLength else {
            return .unknown(data: payload)
        }

        let languageData = Data(payload[1 ..< 1 + languageLength])
        let textData = Data(payload.dropFirst(1 + languageLength))
        let languageCode = String(data: languageData, encoding: .utf8) ?? "und"
        let encoding: String.Encoding = usesUTF16 ? .utf16 : .utf8
        let text = String(data: textData, encoding: encoding) ?? textData.hexString
        return .text(languageCode: languageCode, text: text)
    }

    private static func parseURIPayload(_ payload: Data) -> Payload {
        guard let prefixCode = payload.first else {
            return .unknown(data: payload)
        }
        let suffix = String(data: payload.dropFirst(), encoding: .utf8) ?? payload.dropFirst().hexString
        let prefix = uriPrefixMap[Int(prefixCode)]
        return .uri(prefix + suffix)
    }

    private static func parseSmartPoster(_ payload: Data) -> Payload {
        guard let nestedMessage = try? NDEFMessage(data: payload) else {
            return .unknown(data: payload)
        }
        let uri = nestedMessage.records.compactMap { record -> String? in
            if case let .uri(value) = record.parsedPayload {
                return value
            }
            return nil
        }.first
        let title = nestedMessage.records.compactMap { record -> String? in
            if case let .text(_, value) = record.parsedPayload {
                return value
            }
            return nil
        }.first
        return .smartPoster(uri: uri, title: title)
    }

    private static func abbreviateURI(_ uri: String) -> (UInt8, String) {
        for (index, prefix) in uriPrefixMap.enumerated().reversed() where !prefix.isEmpty {
            if uri.hasPrefix(prefix) {
                return (UInt8(index), String(uri.dropFirst(prefix.count)))
            }
        }
        return (0x00, uri)
    }

    private static let uriPrefixMap: [String] = [
        "",
        "http://www.",
        "https://www.",
        "http://",
        "https://",
        "tel:",
        "mailto:",
        "ftp://anonymous:anonymous@",
        "ftp://ftp.",
        "ftps://",
        "sftp://",
        "smb://",
        "nfs://",
        "ftp://",
        "dav://",
        "news:",
        "telnet://",
        "imap:",
        "rtsp://",
        "urn:",
        "pop:",
        "sip:",
        "sips:",
        "tftp:",
        "btspp://",
        "btl2cap://",
        "btgoep://",
        "tcpobex://",
        "irdaobex://",
        "file://",
        "urn:epc:id:",
        "urn:epc:tag:",
        "urn:epc:pat:",
        "urn:epc:raw:",
        "urn:epc:",
        "urn:nfc:",
    ]
}
