import Foundation

/// Normalized high-level capability flags for a detected card or dump.
public enum CardCapability: String, Sendable, Equatable, Hashable, CaseIterable, Codable {
    case readable = "Readable"
    case writable = "Writable"
    case authenticationRequired = "Authentication Required"
    case partiallyReadable = "Partially Readable"
    case identificationOnly = "Identification Only"
}

/// Shared summary surface for dumps, suitable for UI and export metadata.
public struct DumpSummary: Sendable, Equatable, Codable {
    public let userSummary: String
    public let technicalSummary: String
    public let capabilities: [CardCapability]
    public let facts: [MemoryDump.Fact]

    public init(
        userSummary: String,
        technicalSummary: String,
        capabilities: [CardCapability],
        facts: [MemoryDump.Fact]
    ) {
        self.userSummary = userSummary
        self.technicalSummary = technicalSummary
        self.capabilities = capabilities
        self.facts = facts
    }
}
