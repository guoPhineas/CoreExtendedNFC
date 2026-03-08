import Foundation

/// High-level Type 4 tag operations.
public struct Type4Tag: Sendable {
    public let transport: any NFCTagTransport
    private let reader: Type4Reader

    public init(transport: any NFCTagTransport) {
        self.transport = transport
        reader = Type4Reader(transport: transport)
    }

    /// Read NDEF message from a Type 4A/4B tag.
    public func readNDEF() async throws -> Data {
        try await reader.readNDEF()
    }

    /// Write NDEF message to a Type 4A/4B tag.
    public func writeNDEF(_ message: Data) async throws {
        try await reader.writeNDEF(message)
    }

    /// Read the Capability Container.
    public func readCC() async throws -> Type4CC {
        try await reader.readCapabilityContainer()
    }
}
