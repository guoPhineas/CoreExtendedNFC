import Foundation

/// Access-control bytes stored in Ultralight C pages 42 and 43.
public struct UltralightCAccessConfiguration: Sendable, Equatable {
    /// First page that requires authentication, or `nil` when protection is disabled.
    public let firstProtectedPage: UInt8?
    /// Raw AUTH1 byte.
    public let auth1: UInt8

    public init(firstProtectedPage: UInt8?, auth1: UInt8) {
        self.firstProtectedPage = firstProtectedPage
        self.auth1 = auth1
    }

    /// Whether authentication is required for writes in the protected range.
    public var requiresAuthenticationForWrites: Bool {
        firstProtectedPage != nil
    }

    /// Whether authentication is required for reads in the protected range.
    public var requiresAuthenticationForReads: Bool {
        firstProtectedPage != nil && (auth1 & 0x01) == 0x01
    }

    /// Human-readable description of the protection mode.
    public var protectionDescription: String {
        guard firstProtectedPage != nil else {
            return "Disabled"
        }
        return requiresAuthenticationForReads ? "Read and write" : "Write-only"
    }
}
