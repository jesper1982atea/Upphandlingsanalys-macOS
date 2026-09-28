import Foundation
import ProcurementRAGCore

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Apple Intelligence är inte tillgängligt på den här Macen. Lokal sökning och kravextraktion fungerar ändå."
    }
}

struct AppleIntelligenceService {
    func answer(question: String, results: [SearchResult]) async throws -> String {
        guard !results.isEmpty else {
            return "Inga relevanta avsnitt hittades i de importerade dokumenten."
        }

        let context = results.prefix(8).enumerated().map { index, result in
            let location = result.chunk.page.map {
                result.chunk.documentName.lowercased().hasSuffix(".xlsx") ? "blad \($0)" : "sida \($0)"
            } ?? "dokument"
            return "[Källa \(index + 1): \(result.chunk.documentName), \(location)]\n\(result.chunk.text)"
        }.joined(separator: "\n\n")

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let prompt = """
            Du analyserar en svensk offentlig upphandling. Besvara frågan enbart utifrån källorna.
            Var tydlig när underlaget inte räcker. Hänvisa till varje påstående med [Källa N].
            Fokusera på verifierbara krav, villkor, datum och belopp. Svara på svenska.

            Fråga:
            \(question)

            Källor:
            \(context)
            """
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
        }
        #endif

        throw AppleIntelligenceError.unavailable
    }

    func requirementSummary(requirements: [Requirement]) async throws -> String {
        let compact = requirements.prefix(100).enumerated().map { index, requirement in
            let page = requirement.page.map {
                requirement.documentName.lowercased().hasSuffix(".xlsx")
                    ? "blad \($0)"
                    : "sida \($0)"
            } ?? "okänd plats"
            return "\(index + 1). [\(requirement.category.rawValue), \(requirement.documentName), \(page)] \(requirement.text)"
        }.joined(separator: "\n")

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let session = LanguageModelSession()
            let response = try await session.respond(to: """
                Sammanställ följande automatiskt identifierade upphandlingskrav på svenska.
                Gruppera dem i obligatoriska krav, utvärderingskrav, avtalskrav och risker.
                Behåll nummerhänvisningen till varje krav. Hitta inte på information.

                \(compact)
                """)
            return response.content
        }
        #endif

        throw AppleIntelligenceError.unavailable
    }

    func summarize(requirement: Requirement, context: [DocumentChunk]) async throws -> String {
        let sourceContext = context.prefix(4).enumerated().map { index, chunk in
            let location = chunk.page.map {
                chunk.documentName.lowercased().hasSuffix(".xlsx")
                    || chunk.documentName.lowercased().hasSuffix(".xls")
                    ? "blad \($0)"
                    : "sida \($0)"
            } ?? "dokumentet"
            return "[Underlag \(index + 1): \(chunk.documentName), \(location)]\n\(chunk.text)"
        }.joined(separator: "\n\n")

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let session = LanguageModelSession()
            let response = try await session.respond(to: """
                Förklara följande krav från en svensk offentlig upphandling på tydlig svenska.
                Skriv 2–4 korta stycken under exakt dessa rubriker:

                **Innebörd:** Vad kravet praktiskt betyder.
                **Leverantören behöver:** Vad leverantören ska göra, uppfylla eller kunna visa.
                **Att kontrollera:** Viktiga oklarheter, bevis eller risker att följa upp.

                Utgå endast från kravet och underlaget. Lägg inte till egna krav, standarder,
                tidsfrister eller antaganden. Skriv "Framgår inte av underlaget" när information
                saknas. Behåll viktiga mått, belopp och villkor exakt.

                Krav:
                \(requirement.text)

                Underlag:
                \(sourceContext)
                """)
            return response.content
        }
        #endif

        throw AppleIntelligenceError.unavailable
    }
}
