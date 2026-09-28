import Foundation

public struct RequirementExtractor {
    private let mandatoryTerms = [
        "ska", "måste", "skall", "obligatorisk", "krav på", "får inte", "accepteras inte"
    ]
    private let evaluationTerms = [
        "bör", "merit", "utvärderas", "mervärde", "poäng", "tilldelningskriter"
    ]
    private let contractualTerms = [
        "avtal", "vite", "leverans", "uppsägning", "betalningsvillkor", "sekretess"
    ]

    public init() {}

    public func extract(from chunks: [DocumentChunk]) -> [Requirement] {
        var seen = Set<String>()
        var output: [Requirement] = []

        for chunk in chunks {
            for sentence in sentences(in: chunk.text) {
                let normalized = sentence
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                guard let category = category(for: normalized) else { continue }

                let key = normalized
                    .components(separatedBy: .whitespacesAndNewlines)
                    .joined(separator: " ")
                guard key.count >= 18, seen.insert(key).inserted else { continue }

                output.append(Requirement(
                    id: UUID(),
                    text: sentence,
                    category: category,
                    documentID: chunk.documentID,
                    documentName: chunk.documentName,
                    page: chunk.page,
                    isReviewed: false
                ))
            }
        }
        return output
    }

    private func sentences(in text: String) -> [String] {
        var values: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.bySentences, .substringNotRequired]) {
            _, range, _, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                values.append(sentence)
            }
        }
        return values
    }

    private func category(for text: String) -> RequirementCategory? {
        if mandatoryTerms.contains(where: text.contains) {
            return .mandatory
        }
        if evaluationTerms.contains(where: text.contains) {
            return .evaluation
        }
        if contractualTerms.contains(where: text.contains) {
            return .contractual
        }
        return nil
    }
}
