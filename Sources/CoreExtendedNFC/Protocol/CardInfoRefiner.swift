import Foundation

enum CardInfoRefiner {
    static func refine(
        _ info: CardInfo,
        transport: any NFCTagTransport
    ) async throws -> CardInfo {
        switch info.type {
        case .mifareUltralight:
            try await refineUltralight(info, transport: transport)
        case .smartMX:
            try await refineISO7816(info, transport: transport)
        default:
            info
        }
    }

    private static func refineUltralight(
        _ info: CardInfo,
        transport: any NFCTagTransport
    ) async throws -> CardInfo {
        let commands = UltralightCommands(transport: transport)
        do {
            let version = try await commands.getVersion()
            return updated(info, type: version.cardType)
        } catch {
            return info
        }
    }

    private static func refineISO7816(
        _ info: CardInfo,
        transport: any NFCTagTransport
    ) async throws -> CardInfo {
        if let type = detectFromMetadata(initialAID: info.initialSelectedAID, historicalBytes: info.historicalBytes) {
            return updated(info, type: type)
        }

        guard let iso7816Transport = transport as? any ISO7816TagTransporting else {
            return info
        }

        if let detectedType = await detectByProbing(transport: iso7816Transport) {
            return updated(info, type: detectedType)
        }

        return info
    }

    private static func detectFromMetadata(
        initialAID: String?,
        historicalBytes: Data?
    ) -> CardType? {
        if let hintedType = ISO7816Application.match(aid: initialAID)?.hintedCardType {
            return hintedType
        }

        if let historicalBytes {
            if historicalBytes.range(of: PassportConstants.eMRTDAID) != nil {
                return .ePassport
            }
            if historicalBytes.range(of: Type4Constants.ndefAID) != nil {
                return .type4NDEF
            }
        }

        return nil
    }

    private static func detectByProbing(
        transport: any ISO7816TagTransporting
    ) async -> CardType? {
        // Keep a successful passport SELECT as a fallback signal only.
        // Some ISO 7816 tags are permissive about AID selection, so returning
        // ePassport immediately would misclassify Type 4 NDEF tags.
        var passportSelectSucceeded = false
        do {
            let response = try await transport.sendAPDU(CommandAPDU.selectPassportApplication())
            passportSelectSucceeded = response.isSuccess
        } catch {}

        do {
            _ = try await Type4Reader(transport: transport).readCapabilityContainer()
            return .type4NDEF
        } catch {}

        do {
            let version = try await DESFireCommands(transport: transport).getVersion()
            return version.cardType
        } catch {}

        if passportSelectSucceeded {
            return .ePassport
        }

        return nil
    }

    private static func updated(_ info: CardInfo, type: CardType) -> CardInfo {
        CardInfo(
            type: type,
            uid: info.uid,
            atqa: info.atqa,
            sak: info.sak,
            ats: info.ats,
            historicalBytes: info.historicalBytes,
            initialSelectedAID: info.initialSelectedAID,
            systemCode: info.systemCode,
            idm: info.idm,
            icManufacturer: info.icManufacturer
        )
    }
}
