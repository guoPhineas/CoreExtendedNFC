import Foundation

/// FeliCa memory model: services and blocks.
public enum FeliCaMemory {
    /// FeliCa block size is always 16 bytes.
    public static let blockSize = 16

    /// Service types.
    public enum ServiceType: Sendable {
        case randomReadOnly
        case randomReadWrite
        case cyclicReadOnly
        case cyclicReadWrite
        case purseDirectAccess
        case purseCashback

        /// Service code access bits for common service types.
        public var accessBits: UInt8 {
            switch self {
            case .randomReadOnly: 0x0B
            case .randomReadWrite: 0x09
            case .cyclicReadOnly: 0x0B
            case .cyclicReadWrite: 0x09
            case .purseDirectAccess: 0x17
            case .purseCashback: 0x57
            }
        }
    }
}
