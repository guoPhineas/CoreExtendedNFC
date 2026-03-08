import Foundation

/// Identifies card type from ATQA and SAK bytes.
/// Ported from libnfc target-subr.c lookup tables.
public enum CardIdentifier {
    /// Identify a card from its ATQA (2 bytes) and SAK (1 byte).
    /// Note: Ultralight and NTAG share the same ATQA/SAK — use GET_VERSION (0x60) to distinguish.
    public static func identify(atqa: Data, sak: UInt8) -> CardType {
        guard atqa.count >= 2 else { return .unknown(atqa: atqa, sak: sak) }

        let atqaValue = UInt16(atqa[atqa.startIndex]) << 8 | UInt16(atqa[atqa.startIndex + 1])

        // Match the most specific ATQA+SAK combinations first.
        // Reference: NXP AN10833 "MIFARE Type Identification Procedure"

        // MIFARE DESFire: ATQA 0x0344, SAK 0x20
        if atqaValue == 0x0344, sak == 0x20 {
            return .mifareDesfire
        }

        // MIFARE Ultralight / Ultralight C / NTAG: ATQA 0x0044, SAK 0x00
        // Cannot distinguish Ultralight vs NTAG from ATQA/SAK alone — needs GET_VERSION.
        if atqaValue == 0x0044, sak == 0x00 {
            return .mifareUltralight
        }

        // MIFARE Mini: ATQA 0x0004 (mask 0xFF0F), SAK 0x09
        if atqaValue & 0xFF0F == 0x0004, sak == 0x09 {
            return .mifareMini
        }

        // MIFARE Classic 1K: ATQA 0x0004 (mask 0xFF0F), SAK 0x08
        if atqaValue & 0xFF0F == 0x0004, sak == 0x08 {
            return .mifareClassic1K
        }

        // MIFARE Classic 4K: ATQA 0x0002 (mask 0xFF0F), SAK 0x18
        if atqaValue & 0xFF0F == 0x0002, sak == 0x18 {
            return .mifareClassic4K
        }

        // MIFARE Plus uses several ATQA values; SAK selects the security level.
        let isPlusATQA = (atqaValue == 0x0004 || atqaValue == 0x0002
            || atqaValue == 0x0044 || atqaValue == 0x0042)
        if isPlusATQA {
            switch sak {
            case 0x08: return .mifarePlusSL1_2K
            case 0x18: return .mifarePlusSL1_4K
            case 0x10: return .mifarePlusSL2_2K
            case 0x11: return .mifarePlusSL2_4K
            case 0x20:
                // SAK 0x20 with non-DESFire ATQA maps to MIFARE Plus SL3.
                if atqaValue == 0x0004 || atqaValue == 0x0044 {
                    return .mifarePlusSL3_2K
                } else {
                    return .mifarePlusSL3_4K
                }
            default:
                break
            }
        }

        // SmartMX matches a broader ATQA mask with SAK 0x00.
        let isSmartMXATQA = (atqaValue & 0xF0FF == 0x0004
            || atqaValue & 0xF0FF == 0x0002
            || atqaValue & 0xF0FF == 0x0048)
        if isSmartMXATQA, sak == 0x00 {
            return .smartMX
        }

        // SAK-only fallback matching
        switch sak {
        case 0x00:
            return .mifareUltralight
        case 0x08:
            return .mifareClassic1K
        case 0x09:
            return .mifareMini
        case 0x18:
            return .mifareClassic4K
        case 0x20:
            return .mifareDesfire
        default:
            return .unknown(atqa: atqa, sak: sak)
        }
    }
}
