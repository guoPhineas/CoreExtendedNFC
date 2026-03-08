import Foundation

/// NTAG memory maps.
/// NTAG uses the same UltralightMemoryMap; this file provides convenience accessors.
public extension UltralightMemoryMap {
    /// NTAG213: 45 pages, user 4-39, config 41-44.
    static let ntag213 = forType(.ntag213)
    /// NTAG215: 135 pages, user 4-129, config 131-134.
    static let ntag215 = forType(.ntag215)
    /// NTAG216: 231 pages, user 4-225, config 227-230.
    static let ntag216 = forType(.ntag216)
}
