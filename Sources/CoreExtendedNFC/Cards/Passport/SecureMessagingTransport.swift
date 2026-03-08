import Foundation

/// Encryption mode for Secure Messaging sessions.
///
/// - `tripleDES`: Used after BAC authentication. 8-byte SSC, Retail MAC, 3DES-CBC.
/// - `aes128/192/256`: Used after PACE or Chip Authentication. AES-CBC + AES-CMAC.
///
/// ## SSC and IV Conventions
///
/// The Send Sequence Counter (SSC) is always an 8-byte big-endian counter,
/// incremented by 1 before each protect and unprotect operation.
///
/// For AES modes, the SSC is padded to 16 bytes by prepending 8 zero bytes:
///   `paddedSSC = [0x00]*8 || SSC`
///
/// The AES IV is computed as: `IV = AES-ECB-Encrypt(KSenc, paddedSSC)`
///
/// MAC computation uses AES-CMAC over `pad(paddedSSC || cmdHeader || DO'87 || DO'97)`,
/// truncated to 8 bytes.
///
/// References:
/// - ICAO Doc 9303 Part 11, Section 9.8 (Secure Messaging)
/// - ICAO Doc 9303 Part 11, Section 9.8.6.1 (AES Secure Messaging — SSC padding, IV derivation)
/// - BSI TR-03110 Part 3, Section D.3 (AES Secure Messaging with AES-CMAC)
/// - NIST SP 800-38B (AES-CMAC specification)
/// - ISO/IEC 9797-1, MAC Algorithm 3 (Retail MAC for 3DES mode)
/// - JMRTD source: AESSecureMessagingWrapper.java, DESedeSecureMessagingWrapper.java
public enum SMEncryptionMode: Sendable {
    case tripleDES
    case aes128
    case aes192
    case aes256

    /// Block size for the cipher.
    var blockSize: Int {
        switch self {
        case .tripleDES: 8
        case .aes128, .aes192, .aes256: 16
        }
    }

    /// SSC (Send Sequence Counter) length in bytes.
    /// Always 8 bytes — for AES, the SSC is zero-padded to 16 bytes when used.
    var sscLength: Int {
        8
    }

    /// MAC length in bytes (truncated output).
    var macLength: Int {
        8
    }
}

/// ICAO 9303 Secure Messaging transport wrapper.
///
/// Wraps an existing `NFCTagTransport` and automatically encrypts/MACs
/// all outgoing APDUs and verifies/decrypts all incoming responses
/// per ICAO Doc 9303 Part 11.
///
/// Supports both 3DES mode (after BAC) and AES mode (after PACE/CA).
///
/// Conforms to `NFCTagTransport` so it can be used transparently
/// in place of the original transport after authentication.
public final class SecureMessagingTransport: NFCTagTransport, @unchecked Sendable {
    private let underlying: any NFCTagTransport
    private let ksEnc: Data
    private let ksMac: Data
    private var ssc: Data
    private let mode: SMEncryptionMode

    public var identifier: Data {
        underlying.identifier
    }

    public init(
        transport: any NFCTagTransport,
        ksEnc: Data,
        ksMac: Data,
        ssc: Data,
        mode: SMEncryptionMode = .tripleDES
    ) {
        underlying = transport
        self.ksEnc = ksEnc
        self.ksMac = ksMac
        self.ssc = ssc
        self.mode = mode
    }

    public func send(_: Data) async throws -> Data {
        throw NFCError.unsupportedOperation("Use sendAPDU for Secure Messaging")
    }

    /// Protect the APDU, send via underlying transport (with GET RESPONSE chaining),
    /// then unprotect the response.
    public func sendAPDU(_ apdu: CommandAPDU) async throws -> ResponseAPDU {
        incrementSSC()
        let protectedAPDU = try protect(apdu)

        // Send and handle GET RESPONSE (0x61) chaining at the raw level
        var response = try await underlying.sendAPDU(protectedAPDU)
        var fullData = response.data

        while response.needsGetResponse {
            let getResp = CommandAPDU.getResponse(length: response.sw2)
            response = try await underlying.sendAPDU(getResp)
            fullData.append(response.data)
        }

        let assembledResponse = ResponseAPDU(data: fullData, sw1: response.sw1, sw2: response.sw2)

        incrementSSC()
        return try unprotect(assembledResponse)
    }

    // MARK: - Protect (Encrypt + MAC outgoing APDU)

    /// Build a protected APDU with DO'87 (encrypted data), DO'97 (Le), and DO'8E (MAC).
    private func protect(_ apdu: CommandAPDU) throws -> CommandAPDU {
        let blockSize = mode.blockSize

        // Masked CLA: set SM bits
        let maskedCLA = apdu.cla | 0x0C

        // Command header for MAC calculation: maskedCLA || INS || P1 || P2
        let cmdHeader = ISO9797Padding.pad(Data([maskedCLA, apdu.ins, apdu.p1, apdu.p2]), blockSize: blockSize)

        var do87 = Data()
        var do97 = Data()

        // DO'87: encrypted data (if present)
        if let inputData = apdu.data, !inputData.isEmpty {
            let paddedData = ISO9797Padding.pad(inputData, blockSize: blockSize)

            let encrypted: Data
            switch mode {
            case .tripleDES:
                encrypted = try CryptoUtils.tripleDESEncrypt(key: ksEnc, message: paddedData)
            case .aes128, .aes192, .aes256:
                // AES-CBC with IV = AES-ECB(KSenc, paddedSSC)
                let iv = try computeAESIV()
                encrypted = try CryptoUtils.aesEncrypt(key: ksEnc, message: paddedData, iv: iv)
            }

            // Build DO'87': tag || length || 0x01 || encrypted
            var do87Value = Data([0x01]) // Padding content indicator
            do87Value.append(encrypted)
            do87.append(0x87) // Tag
            do87.append(contentsOf: ASN1Parser.encodeLength(do87Value.count))
            do87.append(do87Value)
        }

        // DO'97: expected response length (if Le is present)
        if let le = apdu.le {
            do97.append(0x97) // Tag
            do97.append(0x01) // Length = 1
            do97.append(le)
        }

        // Compute MAC over: pad(paddedSSC || cmdHeader || DO'87 || DO'97)
        // For 3DES: paddedSSC = SSC (8 bytes)
        // For AES: paddedSSC = [0x00]*8 || SSC (16 bytes)
        let paddedSSC: Data = switch mode {
        case .tripleDES:
            ssc
        case .aes128, .aes192, .aes256:
            Data(repeating: 0x00, count: 8) + ssc
        }

        var macInput = paddedSSC
        macInput.append(cmdHeader)
        if !do87.isEmpty { macInput.append(do87) }
        if !do97.isEmpty { macInput.append(do97) }
        let paddedMacInput = ISO9797Padding.pad(macInput, blockSize: blockSize)
        let cc = try computeMAC(paddedMacInput)

        // DO'8E': MAC
        var do8e = Data([0x8E, UInt8(mode.macLength)]) // Tag + Length
        do8e.append(cc)

        // Assemble protected APDU data: DO'87 || DO'97 || DO'8E
        var protectedData = Data()
        protectedData.append(do87)
        protectedData.append(do97)
        protectedData.append(do8e)

        return CommandAPDU(
            cla: maskedCLA,
            ins: apdu.ins,
            p1: apdu.p1,
            p2: apdu.p2,
            data: protectedData,
            le: 0x00
        )
    }

    // MARK: - Unprotect (Verify MAC + Decrypt incoming response)

    /// Unprotect a secure messaging response: verify DO'8E MAC, decrypt DO'87 data.
    private func unprotect(_ response: ResponseAPDU) throws -> ResponseAPDU {
        let blockSize = mode.blockSize
        let data = response.data

        // Parse Data Objects from response
        var do87Value = Data()
        var do99Value = Data()
        var do8eValue = Data()
        var offset = 0

        while offset < data.count {
            guard offset < data.count else { break }
            let tag = data[offset]
            offset += 1

            guard offset < data.count else { break }
            let (length, lenBytes) = try ASN1Parser.parseLength(data, at: offset)
            offset += lenBytes

            guard offset + length <= data.count else { break }
            let value = Data(data[offset ..< offset + length])
            offset += length

            switch tag {
            case 0x87:
                do87Value = value
            case 0x99:
                do99Value = value
            case 0x8E:
                do8eValue = value
            default:
                break
            }
        }

        // DO'99 contains SW1 || SW2
        guard do99Value.count == 2 else {
            throw NFCError.secureMessagingError("Missing or invalid DO'99 (status word)")
        }
        let sw1 = do99Value[0]
        let sw2 = do99Value[1]

        // Verify MAC: pad(paddedSSC || DO'87 (full TLV) || DO'99 (full TLV))
        if !do8eValue.isEmpty {
            // Build paddedSSC matching protect() convention
            let paddedSSC: Data = switch mode {
            case .tripleDES:
                ssc
            case .aes128, .aes192, .aes256:
                Data(repeating: 0x00, count: 8) + ssc
            }

            var macInput = paddedSSC
            if !do87Value.isEmpty {
                macInput.append(0x87)
                macInput.append(contentsOf: ASN1Parser.encodeLength(do87Value.count))
                macInput.append(do87Value)
            }
            // Append DO'99 as TLV
            macInput.append(0x99)
            macInput.append(0x02)
            macInput.append(do99Value)

            let paddedMacInput = ISO9797Padding.pad(macInput, blockSize: blockSize)
            let computedMAC = try computeMAC(paddedMacInput)

            guard computedMAC == do8eValue else {
                throw NFCError.secureMessagingError("MAC verification failed")
            }
        }

        // Decrypt DO'87 if present
        var plaintext = Data()
        if !do87Value.isEmpty {
            // Skip padding content indicator byte (0x01)
            guard do87Value.count > 1, do87Value[0] == 0x01 else {
                throw NFCError.secureMessagingError("Invalid DO'87: missing padding content indicator")
            }
            let encrypted = Data(do87Value[1...])

            let decrypted: Data
            switch mode {
            case .tripleDES:
                decrypted = try CryptoUtils.tripleDESDecrypt(key: ksEnc, message: encrypted)
            case .aes128, .aes192, .aes256:
                let iv = try computeAESIV()
                decrypted = try CryptoUtils.aesDecrypt(key: ksEnc, message: encrypted, iv: iv)
            }
            plaintext = ISO9797Padding.unpad(decrypted)
        }

        return ResponseAPDU(data: plaintext, sw1: sw1, sw2: sw2)
    }

    // MARK: - MAC Computation

    /// Compute MAC using the appropriate algorithm for the current mode.
    private func computeMAC(_ paddedData: Data) throws -> Data {
        switch mode {
        case .tripleDES:
            return try ISO9797MAC.mac(key: ksMac, message: paddedData)
        case .aes128, .aes192, .aes256:
            // AES-CMAC returns 16 bytes, truncate to 8 for Secure Messaging
            let fullMAC = try AESCMAC.mac(key: ksMac, message: paddedData)
            return Data(fullMAC.prefix(8))
        }
    }

    /// Compute AES IV = AES-ECB(KSenc, paddedSSC).
    /// paddedSSC = [0x00]*8 || SSC (8 bytes → 16 bytes for AES block size)
    private func computeAESIV() throws -> Data {
        let paddedSSC = Data(repeating: 0x00, count: 8) + ssc
        return try CryptoUtils.aesECBEncrypt(key: ksEnc, message: paddedSSC)
    }

    // MARK: - SSC

    /// Increment the Send Sequence Counter by 1.
    private func incrementSSC() {
        // Treat SSC as a big-endian integer and add 1
        var carry: UInt16 = 1
        for i in stride(from: ssc.count - 1, through: 0, by: -1) {
            let sum = UInt16(ssc[i]) + carry
            ssc[i] = UInt8(sum & 0xFF)
            carry = sum >> 8
            if carry == 0 { break }
        }
    }
}
