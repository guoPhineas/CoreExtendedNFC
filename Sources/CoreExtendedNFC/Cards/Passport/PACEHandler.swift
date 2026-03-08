import Foundation

/// PACE (Password Authenticated Connection Establishment) handler
/// per ICAO Doc 9303 Part 11 and BSI TR-03110.
///
/// PACE replaces BAC with a stronger authentication protocol using
/// elliptic curve Diffie-Hellman key agreement. It supports MRZ, CAN,
/// PIN, and PUK as password sources.
///
/// Generic Mapping (GM) protocol flow:
/// 1. MSE:Set AT — select PACE protocol and key reference
/// 2. General Authenticate step 1 — get encrypted nonce from chip
/// 3. Decrypt nonce using password-derived key
/// 4. General Authenticate step 2 — exchange ephemeral DH keys
/// 5. General Authenticate step 3 — exchange mapped DH keys
/// 6. General Authenticate step 4 — exchange authentication tokens
/// 7. Derive session keys → SecureMessagingTransport
///
/// References:
/// - ICAO Doc 9303 Part 11, Section 9.1 (PACE protocol overview)
/// - BSI TR-03110 Part 2, Section 3.4 (PACE Generic Mapping protocol steps)
/// - BSI TR-03110 Part 3, Table A.2 (Standardized Domain Parameters: parameter IDs 8–18)
/// - BSI TR-03110 Part 3, Appendix A.1.1.1 (PACE OID tree: 0.4.0.127.0.7.2.2.4.*)
/// - BSI TR-03110 Part 2, Section 3.4.3 (Key Derivation Function for PACE)
public enum PACEHandler {
    /// PACE key reference (password type).
    public enum KeyReference: UInt8, Sendable {
        /// MRZ-derived password.
        case mrz = 0x01
        /// Card Access Number (CAN) — 6-digit number on the card.
        case can = 0x02
        /// Personal Identification Number (PIN).
        case pin = 0x03
        /// Personal Unblocking Key (PUK).
        case puk = 0x04
    }

    /// Standard domain parameter IDs for ECDH.
    /// Reference: BSI TR-03110 Part 3, Table A.2
    public enum DomainParameterID: Int, Sendable {
        case secp192r1 = 8
        case brainpoolP192r1 = 9
        case secp224r1 = 10
        case brainpoolP224r1 = 11
        case secp256r1 = 12 // P-256 (most common)
        case brainpoolP256r1 = 13
        case brainpoolP320r1 = 14
        case secp384r1 = 15 // P-384
        case brainpoolP384r1 = 16
        case brainpoolP512r1 = 17
        case secp521r1 = 18 // P-521

        /// Whether this is a standard NIST curve supported by CryptoKit.
        public var isNISTCurve: Bool {
            switch self {
            case .secp256r1, .secp384r1, .secp521r1: true
            default: false
            }
        }
    }

    /// Attempt PACE authentication using MRZ-derived password.
    ///
    /// - Parameters:
    ///   - paceInfo: Parsed PACEInfo from DG14.
    ///   - mrzKey: The MRZ key string.
    ///   - transport: The underlying (unauthenticated) NFC tag transport.
    /// - Returns: A `SecureMessagingTransport` with PACE session keys.
    public static func performPACE(
        paceInfo: PACEInfo,
        mrzKey: String,
        transport: any NFCTagTransport
    ) async throws -> SecureMessagingTransport {
        try await performPACE(
            paceInfo: paceInfo,
            password: mrzKey,
            keyReference: .mrz,
            transport: transport
        )
    }

    /// Attempt PACE authentication using CAN (Card Access Number).
    ///
    /// - Parameters:
    ///   - paceInfo: Parsed PACEInfo from DG14.
    ///   - can: The 6-digit Card Access Number.
    ///   - transport: The underlying (unauthenticated) NFC tag transport.
    /// - Returns: A `SecureMessagingTransport` with PACE session keys.
    public static func performPACE(
        paceInfo: PACEInfo,
        can: String,
        transport: any NFCTagTransport
    ) async throws -> SecureMessagingTransport {
        try await performPACE(
            paceInfo: paceInfo,
            password: can,
            keyReference: .can,
            transport: transport
        )
    }

    /// Core PACE implementation.
    ///
    /// - Parameters:
    ///   - paceInfo: Parsed PACEInfo from DG14.
    ///   - password: The password (MRZ key or CAN).
    ///   - keyReference: Which key type to use.
    ///   - transport: The underlying NFC tag transport.
    /// - Returns: A `SecureMessagingTransport` with PACE session keys.
    public static func performPACE(
        paceInfo: PACEInfo,
        password: String,
        keyReference: KeyReference,
        transport: any NFCTagTransport
    ) async throws -> SecureMessagingTransport {
        guard let paceProtocol = paceInfo.securityProtocol else {
            throw NFCError.secureMessagingError("Unknown PACE protocol OID: \(paceInfo.protocolOID)")
        }

        // Determine SM encryption mode from protocol
        let smMode: SMEncryptionMode = if let keyLen = paceProtocol.aesKeyLength {
            switch keyLen {
            case 16: .aes128
            case 24: .aes192
            case 32: .aes256
            default: .aes128
            }
        } else {
            .tripleDES
        }

        // Step 1: MSE:Set AT — select PACE protocol
        let oidData = ChipAuthenticationHandler.encodeOID(paceInfo.protocolOID)
        let mseAPDU = CommandAPDU.mseSetAT(oid: oidData, keyRef: keyReference.rawValue)
        let mseResponse = try await transport.sendAPDU(mseAPDU)

        guard mseResponse.isSuccess else {
            throw NFCError.secureMessagingError(
                "MSE:Set AT for PACE failed: SW=\(String(format: "%04X", mseResponse.statusWord))"
            )
        }

        // Step 2: General Authenticate — get encrypted nonce
        let step1Data = ASN1Parser.encodeTLV(tag: 0x7C, value: Data())
        let step1APDU = CommandAPDU.generalAuthenticate(data: step1Data)
        let step1Response = try await transport.sendAPDU(step1APDU)

        guard step1Response.isSuccess else {
            throw NFCError.secureMessagingError(
                "PACE step 1 (get nonce) failed: SW=\(String(format: "%04X", step1Response.statusWord))"
            )
        }

        // Parse encrypted nonce from response: 7C { 80 <nonce> }
        let encryptedNonce = try parseTag80FromDynamicAuth(step1Response.data)

        // Step 3: Decrypt nonce using password-derived key
        let passwordKey = derivePasswordKey(
            password: password,
            keyReference: keyReference,
            mode: smMode
        )

        let decryptedNonce: Data
        switch smMode {
        case .tripleDES:
            decryptedNonce = try CryptoUtils.tripleDESDecrypt(key: passwordKey, message: encryptedNonce)
        case .aes128, .aes192, .aes256:
            let iv = Data(count: 16) // Zero IV for nonce decryption
            decryptedNonce = try CryptoUtils.aesDecrypt(key: passwordKey, message: encryptedNonce, iv: iv)
        }

        // Steps 4-7 require ECDH key agreement using CryptoKit
        // The full implementation depends on the curve from parameterID
        // For now, we set up the protocol framework

        // Step 4: Generate ephemeral key pair and send to chip
        // Step 5: Receive chip's ephemeral key and compute mapped generator
        // Step 6: Generate mapped key pair, exchange, compute shared secret
        // Step 7: Derive session keys and exchange authentication tokens

        // Note: Full ECDH implementation would use:
        // - CryptoKit P256.KeyAgreement (for secp256r1)
        // - CryptoKit P384.KeyAgreement (for secp384r1)
        // - CryptoKit P521.KeyAgreement (for secp521r1)

        throw NFCError.unsupportedOperation(
            "PACE ECDH key agreement is not yet implemented. "
                + "Steps 1-3 completed (MSE:Set AT, get encrypted nonce, decrypt nonce: \(decryptedNonce.count) bytes). "
                + "Steps 4-7 (ECDH key exchange, mapped generator, session keys, auth tokens) require CryptoKit integration. "
                + "Use BAC as fallback."
        )
    }

    // MARK: - Key Derivation

    /// Derive the password encryption key for PACE nonce decryption.
    ///
    /// For MRZ: K_π = KDF(SHA-1(MRZ_information), 3)
    /// For CAN/PIN/PUK: K_π = KDF(SHA-1(password.utf8), 3)
    static func derivePasswordKey(
        password: String,
        keyReference: KeyReference,
        mode _: SMEncryptionMode
    ) -> Data {
        let passwordData: Data = if keyReference == .mrz {
            // For MRZ, use the existing Kseed derivation
            KeyDerivation.generateKseed(mrzKey: password)
        } else {
            // For CAN/PIN/PUK, hash the password directly
            Data(HashUtils.sha1(Data(password.utf8)).prefix(16))
        }

        // Derive key using the PACE counter (3)
        return KeyDerivation.deriveKey(keySeed: passwordData, mode: .pace)
    }

    /// Derive PACE session keys from the shared secret.
    ///
    /// KSenc = KDF(sharedSecret, 1)
    /// KSmac = KDF(sharedSecret, 2)
    static func derivePACESessionKeys(
        sharedSecret: Data,
        mode: SMEncryptionMode
    ) -> (ksEnc: Data, ksMac: Data) {
        let keyLen = switch mode {
        case .tripleDES: 16
        case .aes128: 16
        case .aes192: 24
        case .aes256: 32
        }

        // Use SHA-256 for AES modes, SHA-1 for 3DES
        let hashFunc: (Data) -> Data = switch mode {
        case .tripleDES:
            HashUtils.sha1
        default:
            HashUtils.sha256
        }

        // KSenc
        var encInput = sharedSecret
        encInput.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        let encHash = hashFunc(encInput)
        let ksEnc = Data(encHash.prefix(keyLen))

        // KSmac
        var macInput = sharedSecret
        macInput.append(contentsOf: [0x00, 0x00, 0x00, 0x02])
        let macHash = hashFunc(macInput)
        let ksMac = Data(macHash.prefix(keyLen))

        return (ksEnc, ksMac)
    }

    /// Compute PACE authentication token.
    ///
    /// T = MAC(KSmac, publicKey_other)
    static func computeAuthToken(
        ksMac: Data,
        publicKeyOther: Data,
        oid: Data,
        mode: SMEncryptionMode
    ) throws -> Data {
        // Build the authentication input:
        // 7F49 { 06 <OID> || 86 <publicKey> }
        var authInput = Data()
        authInput.append(contentsOf: ASN1Parser.encodeTLV(tag: 0x06, value: oid))
        authInput.append(contentsOf: ASN1Parser.encodeTLV(tag: 0x86, value: publicKeyOther))
        let wrappedInput = ASN1Parser.encodeTLV(tag: 0x7F49, value: authInput)

        // Pad and MAC
        let blockSize = mode.blockSize
        let padded = ISO9797Padding.pad(wrappedInput, blockSize: blockSize)

        switch mode {
        case .tripleDES:
            return try ISO9797MAC.mac(key: ksMac, message: padded)
        case .aes128, .aes192, .aes256:
            let fullMAC = try AESCMAC.mac(key: ksMac, message: padded)
            return Data(fullMAC.prefix(8))
        }
    }

    // MARK: - Response Parsing

    /// Parse tag 0x80 from a Dynamic Authentication Data (7C) response.
    private static func parseTag80FromDynamicAuth(_ data: Data) throws -> Data {
        let nodes = try ASN1Parser.parseTLV(data)
        guard let wrapper = nodes.first(where: { $0.tag == 0x7C }) else {
            throw NFCError.secureMessagingError("PACE: Missing 0x7C wrapper in response")
        }
        let children = try ASN1Parser.parseTLV(wrapper.value)
        guard let nonceNode = children.first(where: { $0.tag == 0x80 }) else {
            throw NFCError.secureMessagingError("PACE: Missing tag 0x80 in response")
        }
        return nonceNode.value
    }

    /// Parse tag 0x81 (map nonce public key) from Dynamic Authentication Data.
    static func parseTag81FromDynamicAuth(_ data: Data) throws -> Data {
        let nodes = try ASN1Parser.parseTLV(data)
        guard let wrapper = nodes.first(where: { $0.tag == 0x7C }) else {
            throw NFCError.secureMessagingError("PACE: Missing 0x7C wrapper in response")
        }
        let children = try ASN1Parser.parseTLV(wrapper.value)
        guard let keyNode = children.first(where: { $0.tag == 0x81 }) else {
            throw NFCError.secureMessagingError("PACE: Missing tag 0x81 in response")
        }
        return keyNode.value
    }

    /// Parse tag 0x82 (mapped key agreement public key) from Dynamic Authentication Data.
    static func parseTag82FromDynamicAuth(_ data: Data) throws -> Data {
        let nodes = try ASN1Parser.parseTLV(data)
        guard let wrapper = nodes.first(where: { $0.tag == 0x7C }) else {
            throw NFCError.secureMessagingError("PACE: Missing 0x7C wrapper in response")
        }
        let children = try ASN1Parser.parseTLV(wrapper.value)
        guard let keyNode = children.first(where: { $0.tag == 0x82 }) else {
            throw NFCError.secureMessagingError("PACE: Missing tag 0x82 in response")
        }
        return keyNode.value
    }

    /// Parse tag 0x86 (authentication token) from Dynamic Authentication Data.
    static func parseTag86FromDynamicAuth(_ data: Data) throws -> Data {
        let nodes = try ASN1Parser.parseTLV(data)
        guard let wrapper = nodes.first(where: { $0.tag == 0x7C }) else {
            throw NFCError.secureMessagingError("PACE: Missing 0x7C wrapper in response")
        }
        let children = try ASN1Parser.parseTLV(wrapper.value)
        guard let tokenNode = children.first(where: { $0.tag == 0x86 }) else {
            throw NFCError.secureMessagingError("PACE: Missing tag 0x86 in response")
        }
        return tokenNode.value
    }
}
