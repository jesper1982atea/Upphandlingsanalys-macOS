import Foundation
import PDFKit

public enum DocumentProcessingError: LocalizedError {
    case unsupportedFile(URL)
    case unreadableFile(URL)
    case emptyDocument(URL)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url):
            "Filtypen stöds inte: \(url.lastPathComponent)"
        case .unreadableFile(let url):
            "Kunde inte läsa \(url.lastPathComponent)."
        case .emptyDocument(let url):
            "Inget läsbart innehåll hittades i \(url.lastPathComponent)."
        }
    }
}

public struct DocumentProcessor {
    private let chunkSize = 1_500
    private let overlap = 250

    public init() {}

    public func process(url: URL) throws -> (ProcurementDocument, [DocumentChunk]) {
        let pages = try extractPages(from: url)
        let document = ProcurementDocument(
            id: UUID(),
            name: url.lastPathComponent,
            sourceURL: url,
            importedAt: .now,
            pageCount: pages.count,
            characterCount: pages.reduce(0) { $0 + $1.count }
        )

        let chunks = pages.enumerated().flatMap { index, text in
            chunk(text: text).map {
                DocumentChunk(
                    id: UUID(),
                    documentID: document.id,
                    documentName: document.name,
                    page: pages.count > 1 ? index + 1 : nil,
                    text: $0
                )
            }
        }

        guard !chunks.isEmpty else {
            throw DocumentProcessingError.emptyDocument(url)
        }
        return (document, chunks)
    }

    public func chunk(text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        var chunks: [String] = []
        var start = normalized.startIndex

        while start < normalized.endIndex {
            let proposedEnd = normalized.index(start, offsetBy: chunkSize, limitedBy: normalized.endIndex)
                ?? normalized.endIndex
            var end = proposedEnd

            if proposedEnd < normalized.endIndex,
               let boundary = normalized[start..<proposedEnd].lastIndex(where: { ".!?\n".contains($0) }),
               normalized.distance(from: boundary, to: proposedEnd) < 400 {
                end = normalized.index(after: boundary)
            }

            let value = normalized[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                chunks.append(value)
            }
            guard end < normalized.endIndex else { break }

            let nextStart = normalized.index(end, offsetBy: -min(overlap, normalized.distance(from: start, to: end)))
            start = nextStart > start ? nextStart : end
        }
        return chunks
    }

    private func extractPages(from url: URL) throws -> [String] {
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let pdf = PDFDocument(url: url) else {
                throw DocumentProcessingError.unreadableFile(url)
            }
            return (0..<pdf.pageCount).compactMap { index in
                pdf.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
        case "txt", "md":
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw DocumentProcessingError.unreadableFile(url)
            }
            return [text]
        case "xls", "xlsx":
            return try SpreadsheetReader().read(url: url).compactMap { sheet in
                let rows = sheet.rows.compactMap { row -> String? in
                    let values = row.map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    }.filter { !$0.isEmpty }
                    return values.isEmpty ? nil : values.joined(separator: " | ")
                }
                guard !rows.isEmpty else { return nil }
                return "\(sheet.name)\n" + rows.joined(separator: "\n")
            }
        default:
            throw DocumentProcessingError.unsupportedFile(url)
        }
    }
}
