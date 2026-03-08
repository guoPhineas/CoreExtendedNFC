import Foundation

/// Session material established by DESFire mutual authentication.
public struct DESFireAuthenticationSession: Sendable, Equatable {
    public enum Scheme: String, Sendable {
        case authenticateISO
        case authenticateEV2First
    }

    public let scheme: Scheme
    public let keyNumber: UInt8
    public let sessionENCKey: Data
    public let sessionMACKey: Data
    public let transactionIdentifier: Data?
    public let piccCapabilities: Data
    public let pcdCapabilities: Data
    public let commandCounter: UInt16

    public init(
        scheme: Scheme,
        keyNumber: UInt8,
        sessionENCKey: Data,
        sessionMACKey: Data,
        transactionIdentifier: Data? = nil,
        piccCapabilities: Data = Data(),
        pcdCapabilities: Data = Data(),
        commandCounter: UInt16 = 0
    ) {
        self.scheme = scheme
        self.keyNumber = keyNumber
        self.sessionENCKey = sessionENCKey
        self.sessionMACKey = sessionMACKey
        self.transactionIdentifier = transactionIdentifier
        self.piccCapabilities = piccCapabilities
        self.pcdCapabilities = pcdCapabilities
        self.commandCounter = commandCounter
    }
}
