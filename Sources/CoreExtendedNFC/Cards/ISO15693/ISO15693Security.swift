import Foundation

/// Normalized response payload for ISO 15693 security operations.
public struct ISO15693SecurityResponse: Sendable, Equatable {
    /// Raw ISO 15693 response flag bits returned by CoreNFC.
    public let responseFlags: Int
    /// Response payload bytes returned by the tag.
    public let data: Data

    public init(responseFlags: Int, data: Data) {
        self.responseFlags = responseFlags
        self.data = data
    }
}

/// High-level ISO 15693 security and configuration operations.
public struct ISO15693SecurityManager: Sendable {
    public let transport: any ISO15693TagTransporting

    public init(transport: any ISO15693TagTransporting) {
        self.transport = transport
    }

    /// Update AFI and optionally lock it afterwards.
    public func configureAFI(_ afi: UInt8, lock: Bool = false) async throws {
        try await transport.writeAFI(afi)
        if lock {
            try await transport.lockAFI()
        }
    }

    /// Update DSFID and optionally lock it afterwards.
    public func configureDSFID(_ dsfid: UInt8, lock: Bool = false) async throws {
        try await transport.writeDSFID(dsfid)
        if lock {
            try await transport.lockDSFID()
        }
    }

    /// Send a manufacturer-specific custom command.
    public func customCommand(code: Int, parameters: Data = Data()) async throws -> Data {
        try await transport.customCommand(code: code, parameters: parameters)
    }

    /// Start or continue a challenge flow for the selected crypto suite.
    public func challenge(
        cryptoSuiteIdentifier: Int,
        message: Data = Data()
    ) async throws {
        try await transport.challenge(
            cryptoSuiteIdentifier: cryptoSuiteIdentifier,
            message: message
        )
    }

    /// Authenticate using the selected ISO 15693 crypto suite.
    public func authenticate(
        cryptoSuiteIdentifier: Int,
        message: Data
    ) async throws -> ISO15693SecurityResponse {
        try await transport.authenticate(
            cryptoSuiteIdentifier: cryptoSuiteIdentifier,
            message: message
        )
    }

    /// Update a security key on tags that support the ISO 15693 key update primitive.
    public func keyUpdate(
        keyIdentifier: Int,
        message: Data
    ) async throws -> ISO15693SecurityResponse {
        try await transport.keyUpdate(
            keyIdentifier: keyIdentifier,
            message: message
        )
    }
}
