import Foundation

/// Parsed response from GET_VERSION (0x60) command.
/// Used to distinguish Ultralight variants, NTAG models, and other NXP Type 2 tags.
public struct UltralightVersionResponse: Sendable, Equatable {
    public let header: UInt8
    public let vendorID: UInt8
    public let productType: UInt8
    public let productSubtype: UInt8
    public let majorVersion: UInt8
    public let minorVersion: UInt8
    public let storageSize: UInt8
    public let protocolType: UInt8

    public init(data: Data) throws {
        guard data.count >= 8 else {
            throw NFCError.invalidResponse(data)
        }
        header = data[data.startIndex]
        vendorID = data[data.startIndex + 1]
        productType = data[data.startIndex + 2]
        productSubtype = data[data.startIndex + 3]
        majorVersion = data[data.startIndex + 4]
        minorVersion = data[data.startIndex + 5]
        storageSize = data[data.startIndex + 6]
        protocolType = data[data.startIndex + 7]
    }

    /// Identify the exact card type from version response.
    public var cardType: CardType {
        guard vendorID == 0x04 else { return .mifareUltralight } // 0x04 = NXP

        // productType: 0x03 = Ultralight, 0x04 = NTAG
        switch productType {
        case 0x03:
            // Ultralight family
            switch storageSize {
            case 0x06, 0x0B:
                return .mifareUltralightEV1_MF0UL11 // 48 bytes (pages 0-16)
            case 0x0E:
                return .mifareUltralightEV1_MF0UL21 // 128 bytes (pages 0-40)
            default:
                return .mifareUltralight
            }
        case 0x04:
            // NTAG family
            switch storageSize {
            case 0x06:
                return .ntag210
            case 0x0B:
                return .ntag212
            case 0x0F:
                return .ntag213 // 144 user bytes
            case 0x11:
                return .ntag215 // 504 user bytes
            case 0x13:
                return .ntag216 // 888 user bytes
            default:
                return .ntag213
            }
        default:
            return .mifareUltralight
        }
    }

    /// Total number of pages on the tag.
    public var totalPages: UInt8 {
        switch cardType {
        case .mifareUltralightEV1_MF0UL11: 20
        case .mifareUltralightEV1_MF0UL21: 41
        case .mifareUltralight: 16
        case .mifareUltralightC: 48
        case .ntag210: 16
        case .ntag212: 45
        case .ntag213: 45
        case .ntag215: 135
        case .ntag216: 231
        default: 16
        }
    }

    /// Number of user-writable data pages.
    public var userPages: UInt8 {
        switch cardType {
        case .mifareUltralight: 12 // pages 4-15
        case .mifareUltralightEV1_MF0UL11: 12 // pages 4-15
        case .mifareUltralightEV1_MF0UL21: 32 // pages 4-35
        case .ntag213: 36 // pages 4-39
        case .ntag215: 126 // pages 4-129
        case .ntag216: 222 // pages 4-225
        default: 12
        }
    }
}

public extension UltralightCommands {
    /// GET_VERSION (0x60): Returns 8 bytes identifying the chip.
    func getVersion() async throws -> UltralightVersionResponse {
        let response = try await transport.send(Data([0x60]))
        return try UltralightVersionResponse(data: response)
    }
}
