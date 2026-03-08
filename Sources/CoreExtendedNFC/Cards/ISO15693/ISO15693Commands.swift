import Foundation

/// ISO 15693 system information parsed from GET_SYSTEM_INFO response.
public struct ISO15693SystemInfo: Sendable {
    /// Tag UID (8 bytes).
    public let uid: Data
    /// Data Storage Format ID.
    public let dsfid: UInt8
    /// Application Family ID.
    public let afi: UInt8
    /// Bytes per block.
    public let blockSize: Int
    /// Total number of blocks.
    public let blockCount: Int
    /// IC reference code.
    public let icReference: UInt8
}

/// ISO 15693 tag reader operations.
public struct ISO15693Reader: Sendable {
    public let transport: any ISO15693TagTransporting

    public init(transport: any ISO15693TagTransporting) {
        self.transport = transport
    }
}
