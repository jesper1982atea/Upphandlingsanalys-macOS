import Foundation
import Testing
@testable import ProcurementRAGCore

@Suite("Procurement RAG")
struct ProcurementRAGTests {
    @Test("Chunking preserves content and creates overlap")
    func chunking() {
        let text = String(repeating: "Detta är ett obligatoriskt krav. ", count: 100)
        let chunks = DocumentProcessor().chunk(text: text)

        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { !$0.isEmpty })
        #expect(chunks[0].count <= 1_500)
    }

    @Test("Search ranks relevant content first")
    func search() {
        let relevant = DocumentChunk(
            id: UUID(),
            documentID: UUID(),
            documentName: "krav.pdf",
            page: 4,
            text: "Leverantören ska uppfylla ISO 27001 och särskilda krav på informationssäkerhet."
        )
        let unrelated = DocumentChunk(
            id: UUID(),
            documentID: UUID(),
            documentName: "krav.pdf",
            page: 8,
            text: "Fakturering sker månadsvis efter godkänd leverans."
        )

        let results = RAGEngine(chunks: [unrelated, relevant]).search("informationssäkerhet ISO")

        #expect(results.first?.chunk.id == relevant.id)
    }

    @Test("Mandatory requirements retain source")
    func requirements() {
        let documentID = UUID()
        let chunk = DocumentChunk(
            id: UUID(),
            documentID: documentID,
            documentName: "upphandling.pdf",
            page: 12,
            text: "Leverantören ska kunna erbjuda support dygnet runt. En introduktion beskriver bakgrunden."
        )

        let requirements = RequirementExtractor().extract(from: [chunk])

        #expect(requirements.count == 1)
        #expect(requirements.first?.category == .mandatory)
        #expect(requirements.first?.documentID == documentID)
        #expect(requirements.first?.page == 12)
    }

    @Test("Products and their requirements are extracted from spreadsheet rows")
    func products() {
        let document = ProcurementDocument(
            id: UUID(),
            name: "anbudspriser.xls",
            sourceURL: URL(fileURLWithPath: "/tmp/anbudspriser.xls"),
            importedAt: .now,
            pageCount: 1,
            characterCount: 100
        )
        let sheet = SpreadsheetSheet(
            name: "Priser",
            rows: [
                ["Artikelnummer", "Produkt", "Obligatoriska krav", "Pris", "Enhet"],
                ["A-101", "Arbetsstol", "Justerbart svankstöd", "2495", "st"],
                ["A-102", "Skrivbord", "Elektriskt höj- och sänkbart", "3995", "st"]
            ]
        )

        let products = ProductExtractor().extract(from: [sheet], document: document)

        #expect(products.count == 2)
        #expect(products.first?.name == "Arbetsstol")
        #expect(products.first?.identifier == "A-101")
        #expect(products.first?.requirements == ["Obligatoriska krav: Justerbart svankstöd"])
        #expect(products.first?.details.contains("Pris: 2495") == true)
        #expect(products.first?.sheetName == "Priser")
        #expect(products.first?.row == 2)
    }
}
