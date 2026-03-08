import Foundation

/// Session material established by a MIFARE Ultralight C authentication exchange.
public struct UltralightCAuthenticationSession: Sendable, Equatable {
    public let randomA: Data
    public let randomB: Data

    public init(randomA: Data, randomB: Data) {
        self.randomA = randomA
        self.randomB = randomB
    }
}
