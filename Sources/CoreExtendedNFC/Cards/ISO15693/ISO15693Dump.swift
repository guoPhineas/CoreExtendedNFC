import Foundation

/// ISO 15693 full tag dump operations.
public extension ISO15693Reader {
    /// Read all blocks using the ISO15693 transport.
    func readAllBlocks(transport: any ISO15693TagTransporting) async throws -> MemoryDump {
        let sysInfo = try await transport.getSystemInfo()

        let blockCount = sysInfo.blockCount
        let blockSize = sysInfo.blockSize

        var blocks: [MemoryDump.Block] = []

        for i in 0 ..< blockCount {
            let data = try await transport.readBlock(UInt8(i))
            blocks.append(MemoryDump.Block(number: i, data: Data(data.prefix(blockSize))))
        }

        let cardInfo = CardInfo(
            type: .iso15693_generic,
            uid: transport.identifier,
            icManufacturer: transport.icManufacturerCode
        )

        return MemoryDump(cardInfo: cardInfo, blocks: blocks)
    }

    /// Write a single block using the ISO15693 transport.
    func writeBlock(_ number: UInt8, data: Data, transport: ISO15693Transport) async throws {
        try await transport.writeBlock(number, data: data)
    }
}
