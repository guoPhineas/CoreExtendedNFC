import Foundation

/// Constants for eMRTD (electronic Machine Readable Travel Document) operations.
///
/// Reference: ICAO Doc 9303 Part 10
public enum PassportConstants {
    /// ICAO LDS1 eMRTD Application AID: A0 00 00 02 47 10 01
    public static let eMRTDAID = Data([0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01])

    /// Maximum bytes to read per READ BINARY command.
    /// Conservative value for maximum compatibility across chips.
    public static let maxReadLength = 0xA0 // 160 bytes

    /// Secure Messaging Data Object tags.
    public enum SM {
        /// Encrypted data (padding-content indicator byte prepended).
        public static let do87Tag: UInt8 = 0x87
        /// Status word of the response.
        public static let do99Tag: UInt8 = 0x99
        /// Cryptographic checksum (MAC).
        public static let do8eTag: UInt8 = 0x8E
    }

    /// DG2 (face image) TLV tags per ISO 19794-5.
    public enum DG2Tags {
        public static let biometricInfoGroupTemplate: UInt = 0x7F61
        public static let biometricInfoTemplate: UInt = 0x7F60
        public static let biometricHeader: UInt = 0xA1
        public static let biometricData: UInt = 0x5F2E
        public static let biometricDataConstructed: UInt = 0x7F2E
    }
}
