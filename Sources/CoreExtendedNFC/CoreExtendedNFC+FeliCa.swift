import Foundation

// MARK: - FeliCa Operations

public extension CoreExtendedNFC {
    // MARK: Service Discovery

    /// Probe common FeliCa service codes to discover available services.
    static func probeFeliCaServices(
        maxServiceIndex: Int = 15,
        transport: any NFCTagTransport
    ) async throws -> [FeliCaCommands.ServiceProbe] {
        guard let felicaTransport = transport as? any FeliCaTagTransporting else {
            throw NFCError.unsupportedOperation("FeliCa operations require a FeliCa transport")
        }
        return try await FeliCaCommands(transport: felicaTransport)
            .probeCommonServices(maxServiceIndex: maxServiceIndex)
    }

    /// Read data from discovered plain (non-encrypted) services.
    static func readFeliCaPlainServices(
        _ services: [FeliCaCommands.ServiceProbe],
        maxBlocksPerService: Int = 4,
        excluding excludedServiceCodes: Set<Data> = [],
        transport: any NFCTagTransport
    ) async throws -> [FeliCaCommands.ServiceSnapshot] {
        guard let felicaTransport = transport as? any FeliCaTagTransporting else {
            throw NFCError.unsupportedOperation("FeliCa operations require a FeliCa transport")
        }
        return await FeliCaCommands(transport: felicaTransport)
            .readPlainServices(
                services,
                maxBlocksPerService: maxBlocksPerService,
                excluding: excludedServiceCodes
            )
    }

    // MARK: Block-Level Operations

    /// Read contiguous blocks from a FeliCa Type 3 tag.
    static func readFeliCaBlocks(
        from startBlock: Int,
        count: Int,
        transport: any NFCTagTransport
    ) async throws -> Data {
        guard let felicaTransport = transport as? any FeliCaTagTransporting else {
            throw NFCError.unsupportedOperation("FeliCa operations require a FeliCa transport")
        }
        return try await FeliCaType3Reader(transport: felicaTransport)
            .readBlocks(from: startBlock, count: count, maxPerRead: 4)
    }

    /// Write blocks to a FeliCa Type 3 tag.
    static func writeFeliCaBlocks(
        startingAt startBlock: Int,
        blocks: [Data],
        transport: any NFCTagTransport
    ) async throws {
        guard let felicaTransport = transport as? any FeliCaTagTransporting else {
            throw NFCError.unsupportedOperation("FeliCa operations require a FeliCa transport")
        }
        try await FeliCaType3Reader(transport: felicaTransport)
            .writeBlocks(startingAt: startBlock, blocks: blocks, maxPerWrite: 4)
    }

    // MARK: Type 3 NDEF Attribute

    /// Read the FeliCa Type 3 attribute information block.
    static func readFeliCaAttributeInfo(
        transport: any NFCTagTransport
    ) async throws -> FeliCaAttributeInfo {
        guard let felicaTransport = transport as? any FeliCaTagTransporting else {
            throw NFCError.unsupportedOperation("FeliCa operations require a FeliCa transport")
        }
        return try await FeliCaType3Reader(transport: felicaTransport)
            .readAttributeInfo()
    }
}
