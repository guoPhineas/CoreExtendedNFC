import Foundation

/// Chip Authentication (CA) handler.
///
/// CA authenticates the chip by key agreement with the public key advertised in DG14.
/// A completed exchange replaces the BAC session keys with stronger session keys.
///
/// References: ICAO 9303 Part 11 §7, BSI TR-03110, JMRTD `ChipAuthenticationHandler`.
public enum ChipAuthenticationHandler {
    /// Perform Chip Authentication and return a new Secure Messaging transport.
    ///
    /// - Parameters:
    ///   - securityInfos: Parsed DG14 SecurityInfos.
    ///   - transport: Current Secure Messaging transport.
    /// - Returns: A new `SecureMessagingTransport` with stronger session keys,
    ///   or nil if CA is not supported.
    public static func performCA(
        securityInfos: SecurityInfos,
        transport: SecureMessagingTransport
    ) async throws -> SecureMessagingTransport? {
        // Find CA info and matching public key
        guard let caInfo = securityInfos.chipAuthInfos.first,
              findMatchingPublicKey(
                  caInfo: caInfo,
                  publicKeys: securityInfos.chipAuthPublicKeyInfos
              ) != nil
        else {
            return nil
        }

        guard let caProtocol = caInfo.securityProtocol else {
            throw NFCError.secureMessagingError("Unknown CA protocol OID: \(caInfo.protocolOID)")
        }

        // Step 1: MSE:Set AT with CA OID
        let oidData = encodeOID(caInfo.protocolOID)
        let mseAPDU = CommandAPDU.mseSetAT(
            oid: oidData,
            privateKeyRef: caInfo.keyID.map { UInt8($0) }
        )
        let mseResponse = try await transport.sendAPDU(mseAPDU)

        // 6982 = security status not satisfied (acceptable, some chips don't require MSE for CA)
        // 6A88 = referenced data not found (also acceptable — proceed to key agreement)
        if !mseResponse.isSuccess, mseResponse.statusWord != 0x6982,
           mseResponse.statusWord != 0x6A88
        {
            throw NFCError.secureMessagingError(
                "MSE:Set AT for CA failed: SW=\(String(format: "%04X", mseResponse.statusWord))"
            )
        }

        // Step 2: Only ECDH-based CA is currently supported.
        guard caProtocol.isECDH else {
            return nil
        }

        let gaAPDU = try buildCAGeneralAuthenticate()
        let gaResponse = try await transport.sendAPDU(gaAPDU)

        guard gaResponse.isSuccess else {
            throw NFCError.secureMessagingError(
                "General Authenticate for CA failed: SW=\(String(format: "%04X", gaResponse.statusWord))"
            )
        }

        // ECDH key agreement is still stubbed, so CA falls back to the existing BAC session.

        return nil
    }

    // MARK: - Private

    /// Find the ChipAuthenticationPublicKeyInfo that matches the CA info.
    private static func findMatchingPublicKey(
        caInfo: ChipAuthenticationInfo,
        publicKeys: [ChipAuthenticationPublicKeyInfo]
    ) -> ChipAuthenticationPublicKeyInfo? {
        if let keyID = caInfo.keyID {
            return publicKeys.first { $0.keyID == keyID }
        }
        return publicKeys.first
    }

    /// Build a General Authenticate APDU for Chip Authentication.
    private static func buildCAGeneralAuthenticate() throws -> CommandAPDU {
        let dynamicAuthData = ASN1Parser.encodeTLV(tag: 0x7C, value: Data())
        return CommandAPDU.generalAuthenticate(data: dynamicAuthData, isLast: true)
    }

    /// Encode an OID string (dotted decimal) to DER format.
    static func encodeOID(_ oidString: String) -> Data {
        let components = oidString.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else { return Data() }

        var encoded = Data()
        // First two components encoded as single byte
        encoded.append(UInt8(components[0] * 40 + components[1]))

        // Remaining components: base-128 variable-length encoding
        for i in 2 ..< components.count {
            var value = components[i]
            if value < 128 {
                encoded.append(UInt8(value))
            } else {
                var bytes: [UInt8] = []
                while value > 0 {
                    bytes.insert(UInt8(value & 0x7F), at: 0)
                    value >>= 7
                }
                // Set continuation bit on all but last byte
                for j in 0 ..< bytes.count - 1 {
                    bytes[j] |= 0x80
                }
                encoded.append(contentsOf: bytes)
            }
        }

        return encoded
    }

    /// Derive session keys from ECDH shared secret for CA.
    ///
    /// KDF: SHA-X(sharedSecret || counter)
    /// where counter = 00000001 for enc, 00000002 for mac
    static func deriveCASessionKeys(
        sharedSecret: Data,
        mode: SMEncryptionMode
    ) -> (ksEnc: Data, ksMac: Data) {
        let keyLen = switch mode {
        case .tripleDES: 16
        case .aes128: 16
        case .aes192: 24
        case .aes256: 32
        }

        // KDF for enc key
        var encInput = sharedSecret
        encInput.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        let encHash = HashUtils.sha256(encInput)
        let ksEnc = Data(encHash.prefix(keyLen))

        // KDF for mac key
        var macInput = sharedSecret
        macInput.append(contentsOf: [0x00, 0x00, 0x00, 0x02])
        let macHash = HashUtils.sha256(macInput)
        let ksMac = Data(macHash.prefix(keyLen))

        return (ksEnc, ksMac)
    }
}
