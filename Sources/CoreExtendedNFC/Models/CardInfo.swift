import Foundation

/// Information about a detected NFC card.
public struct CardInfo: Sendable, Codable, Equatable {
    /// Identified card type.
    public let type: CardType
    /// Card UID (unique identifier).
    public let uid: Data
    /// ATQA (Answer To reQuest of type A) — ISO 14443A only.
    public let atqa: Data?
    /// SAK (Select Acknowledge) — ISO 14443A only.
    public let sak: UInt8?
    /// ATS (Answer To Select) — ISO 14443-4 only.
    public let ats: ATSInfo?
    /// Historical bytes from ATS.
    public let historicalBytes: Data?
    /// Initially selected ISO 7816 AID, if CoreNFC provided one.
    public let initialSelectedAID: String?
    /// System code — FeliCa only.
    public let systemCode: Data?
    /// IDm (Manufacture ID) — FeliCa only.
    public let idm: Data?
    /// IC manufacturer code — ISO 15693 only.
    public let icManufacturer: Int?

    public init(
        type: CardType,
        uid: Data,
        atqa: Data? = nil,
        sak: UInt8? = nil,
        ats: ATSInfo? = nil,
        historicalBytes: Data? = nil,
        initialSelectedAID: String? = nil,
        systemCode: Data? = nil,
        idm: Data? = nil,
        icManufacturer: Int? = nil
    ) {
        self.type = type
        self.uid = uid
        self.atqa = atqa
        self.sak = sak
        self.ats = ats
        self.historicalBytes = historicalBytes
        self.initialSelectedAID = initialSelectedAID
        self.systemCode = systemCode
        self.idm = idm
        self.icManufacturer = icManufacturer
    }
}
