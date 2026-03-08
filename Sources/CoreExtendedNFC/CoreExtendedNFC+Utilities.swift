import Foundation

// MARK: - Standalone Utilities

public extension CoreExtendedNFC {
    // MARK: Card Identification

    /// Identify a card type from its ATQA and SAK bytes (no NFC session needed).
    static func identifyCard(atqa: Data, sak: UInt8) -> CardType {
        CardIdentifier.identify(atqa: atqa, sak: sak)
    }

    // MARK: MRZ Utilities

    /// Compute the MRZ key for passport BAC authentication (no NFC session needed).
    static func computeMRZKey(
        documentNumber: String,
        dateOfBirth: String,
        dateOfExpiry: String
    ) -> String {
        MRZKeyGenerator.computeMRZKey(
            documentNumber: documentNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
    }

    /// Calculate the ICAO 9303 check digit for a given MRZ field.
    static func mrzCheckDigit(_ input: String) -> Character {
        MRZKeyGenerator.checkDigit(input)
    }

    // MARK: CRC

    /// Compute CRC_A (ISO 14443-3A) over the given bytes.
    static func crcA(_ data: Data) -> (UInt8, UInt8) {
        ISO14443.crcA(data)
    }

    /// Compute CRC_B (ISO 14443-3B) over the given bytes.
    static func crcB(_ data: Data) -> (UInt8, UInt8) {
        ISO14443.crcB(data)
    }

    // MARK: ATS Parsing

    /// Parse an Answer To Select (ATS) response from an ISO 14443-4A tag.
    static func parseATS(_ data: Data) -> ATSInfo {
        ISO14443.parseATS(data)
    }

    // MARK: Raw Transport

    /// Send a raw command to a tag and return the response bytes.
    static func sendRawCommand(
        _ command: Data,
        transport: any NFCTagTransport
    ) async throws -> Data {
        try await transport.send(command)
    }

    /// Send an ISO 7816-4 APDU and return the parsed response.
    static func sendAPDU(
        _ apdu: CommandAPDU,
        transport: any NFCTagTransport
    ) async throws -> ResponseAPDU {
        try await transport.sendAPDU(apdu)
    }

    // MARK: ASN.1 / TLV

    /// Parse BER-TLV encoded data (ITU-T X.690).
    static func parseTLV(_ data: Data) throws -> [TLVNode] {
        try ASN1Parser.parseTLV(data)
    }

    /// Encode a TLV node (tag + length + value).
    static func encodeTLV(tag: UInt, value: Data) -> Data {
        ASN1Parser.encodeTLV(tag: tag, value: value)
    }

    // MARK: Memory Map

    /// Get the memory layout for a given Ultralight/NTAG card type.
    static func ultralightMemoryMap(for type: CardType) -> UltralightMemoryMap {
        UltralightMemoryMap.forType(type)
    }

    // MARK: Access Bits

    /// Decode MIFARE Classic access bits from the 3 access-control bytes.
    static func decodeAccessBits(_ bytes: Data) -> [AccessBits.BlockAccess]? {
        AccessBits.decode(bytes)
    }
}
