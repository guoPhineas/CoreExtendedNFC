import Foundation

/// All errors thrown by CoreExtendedNFC operations.
public enum NFCError: Error, Sendable {
    // MARK: Transport

    case nfcNotAvailable
    case sessionTimeout
    case tagConnectionLost
    case tagNotSupported
    case sessionInvalidated(String)

    // MARK: Protocol

    case crcMismatch
    case invalidResponse(Data)
    case unexpectedStatusWord(UInt8, UInt8)

    // MARK: MIFARE

    case authenticationFailed
    case writeFailed(page: UInt8)
    case tagLocked

    // MARK: DESFire

    case desfireError(DESFireStatus)

    // MARK: FeliCa

    case felicaBlockReadFailed(statusFlag: Int)
    case felicaBlockWriteFailed(statusFlag: Int)

    // MARK: Passport

    case bacFailed(String)
    case secureMessagingError(String)
    case dataGroupNotAvailable(String)
    case dataGroupParseFailed(String)
    case cryptoError(String)

    // MARK: General

    case notOperableOnIOS(CardType)
    case unsupportedOperation(String)
}
