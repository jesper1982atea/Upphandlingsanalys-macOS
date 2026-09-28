import Foundation

public struct RAGEngine {
    private let chunks: [DocumentChunk]
    private let tokensByChunk: [[String]]
    private let documentFrequency: [String: Int]
    private let averageLength: Double

    public init(chunks: [DocumentChunk]) {
        self.chunks = chunks
        let tokenized = chunks.map { Self.tokenize($0.text) }
        tokensByChunk = tokenized
        averageLength = tokenized.isEmpty
            ? 1
            : Double(tokenized.reduce(0) { $0 + $1.count }) / Double(tokenized.count)

        var frequency: [String: Int] = [:]
        for tokens in tokenized {
            for token in Set(tokens) {
                frequency[token, default: 0] += 1
            }
        }
        documentFrequency = frequency
    }

    public func search(_ query: String, limit: Int = 12) -> [SearchResult] {
        let queryTokens = Self.tokenize(query)
        guard !queryTokens.isEmpty, !chunks.isEmpty else { return [] }

        let k1 = 1.5
        let b = 0.75
        let count = Double(chunks.count)

        return chunks.indices.compactMap { index -> SearchResult? in
            let tokens = tokensByChunk[index]
            let termFrequency = Dictionary(grouping: tokens, by: { $0 }).mapValues(\.count)
            let lengthNormalization = 1 - b + b * Double(tokens.count) / averageLength

            let score = queryTokens.reduce(0.0) { total, term in
                guard let occurrences = termFrequency[term] else { return total }
                let df = Double(documentFrequency[term, default: 0])
                let idf = log(1 + (count - df + 0.5) / (df + 0.5))
                let tf = Double(occurrences)
                return total + idf * (tf * (k1 + 1)) / (tf + k1 * lengthNormalization)
            }
            guard score > 0 else { return nil }
            return SearchResult(chunk: chunks[index], score: score)
        }
        .sorted { $0.score > $1.score }
        .prefix(limit)
        .map { $0 }
    }

    public static func tokenize(_ text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "sv_SE"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stopWords.contains($0) }
    }

    private static let stopWords: Set<String> = [
        "att", "av", "de", "det", "den", "en", "ett", "for", "fran", "har", "i",
        "med", "och", "om", "pa", "ska", "som", "till", "upp", "vid", "ar"
    ]
}
