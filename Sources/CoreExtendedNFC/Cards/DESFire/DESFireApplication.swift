import Foundation

/// DESFire version info (from GET_VERSION, 3 frames: HW + SW + UID).
public struct DESFireVersionInfo: Sendable {
    public let hardwareVendorID: UInt8
    public let hardwareType: UInt8
    public let hardwareSubType: UInt8
    public let hardwareMajorVersion: UInt8
    public let hardwareMinorVersion: UInt8
    public let hardwareStorageSize: UInt8
    public let hardwareProtocol: UInt8

    public let softwareVendorID: UInt8
    public let softwareType: UInt8
    public let softwareSubType: UInt8
    public let softwareMajorVersion: UInt8
    public let softwareMinorVersion: UInt8
    public let softwareStorageSize: UInt8
    public let softwareProtocol: UInt8

    public let uid: Data // 7 bytes
    public let batchNumber: Data // 5 bytes
    public let productionWeek: UInt8
    public let productionYear: UInt8

    public init(data: Data) throws {
        // GET_VERSION returns 28 bytes (7 HW + 7 SW + 14 UID/batch)
        guard data.count == 28 else {
            throw NFCError.invalidResponse(data)
        }
        let d = Array(data)
        hardwareVendorID = d[0]
        hardwareType = d[1]
        hardwareSubType = d[2]
        hardwareMajorVersion = d[3]
        hardwareMinorVersion = d[4]
        hardwareStorageSize = d[5]
        hardwareProtocol = d[6]

        softwareVendorID = d[7]
        softwareType = d[8]
        softwareSubType = d[9]
        softwareMajorVersion = d[10]
        softwareMinorVersion = d[11]
        softwareStorageSize = d[12]
        softwareProtocol = d[13]

        uid = Data(d[14 ..< 21])
        batchNumber = Data(d[21 ..< 26])
        productionWeek = d[26]
        productionYear = d[27]
    }

    /// Determine DESFire variant from version info.
    public var cardType: CardType {
        switch hardwareMajorVersion {
        case 0: .mifareDesfire
        case 1: .mifareDesfireEV1
        case 2: .mifareDesfireEV2
        case 3: .mifareDesfireEV3
        default: .mifareDesfire
        }
    }
}

public extension DESFireCommands {
    /// GET_VERSION: Returns hardware, software, and UID info.
    func getVersion() async throws -> DESFireVersionInfo {
        let data = try await sendCommand(Self.GET_VERSION)
        return try DESFireVersionInfo(data: data)
    }

    /// GET_APPLICATION_IDS: List all application AIDs (3 bytes each).
    func getApplicationIDs() async throws -> [Data] {
        let data = try await sendCommand(Self.GET_APPLICATION_IDS)
        guard data.count.isMultiple(of: 3) else {
            throw NFCError.invalidResponse(data)
        }

        var aids: [Data] = []
        for i in stride(from: 0, to: data.count, by: 3) {
            aids.append(Data(data[i ..< i + 3]))
        }
        return aids
    }

    /// SELECT_APPLICATION: Select an application by 3-byte AID.
    func selectApplication(_ aid: Data) async throws {
        guard aid.count == 3 else {
            throw NFCError.unsupportedOperation("AID must be 3 bytes")
        }
        _ = try await sendCommand(Self.SELECT_APPLICATION, data: aid)
    }

    /// GET_FILE_IDS: List file IDs in the currently selected application.
    func getFileIDs() async throws -> [UInt8] {
        let data = try await sendCommand(Self.GET_FILE_IDS)
        return Array(data)
    }
}
