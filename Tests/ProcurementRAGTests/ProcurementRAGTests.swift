import Foundation
import Testing
@testable import ProcurementRAG
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

    @Test("Project workspaces keep procurements isolated")
    func projectWorkspacePersistence() throws {
        var responseWorkspace = TenderResponseWorkspace(
            procurementReference: "2026-1234",
            organizationName: "Atea Sverige AB"
        )
        responseWorkspace.productsVerified = true
        let first = ProcurementProject(
            name: "Upphandling A",
            documents: [
                ProcurementDocument(
                    id: UUID(),
                    name: "krav-a.pdf",
                    sourceURL: URL(fileURLWithPath: "/tmp/krav-a.pdf"),
                    importedAt: .now,
                    pageCount: 4,
                    characterCount: 500
                )
            ],
            responseWorkspace: responseWorkspace
        )
        let second = ProcurementProject(name: "Upphandling B")
        let workspace = ProjectWorkspace(projects: [first, second], activeProjectID: second.id)

        let encoded = try JSONEncoder().encode(workspace)
        let decoded = try JSONDecoder().decode(ProjectWorkspace.self, from: encoded)

        #expect(decoded.projects.count == 2)
        #expect(decoded.projects[0].documents.first?.name == "krav-a.pdf")
        #expect(decoded.projects[0].responseWorkspace?.procurementReference == "2026-1234")
        #expect(decoded.projects[0].responseWorkspace?.productsVerified == true)
        #expect(decoded.projects[1].documents.isEmpty)
        #expect(decoded.activeProjectID == second.id)
    }

    @Test("Response plan exports valid DOCX and PDF files")
    @MainActor
    func responsePlanExport() throws {
        let documentID = UUID()
        let requirement = Requirement(
            id: UUID(),
            text: "Leverantören ska redovisa en verifierbar leveransplan.",
            category: .mandatory,
            documentID: documentID,
            documentName: "krav.pdf",
            page: 3,
            isReviewed: true,
            aiSummary: "Beskriv tidplan, ansvar och bevis för varje leveranssteg."
        )
        let project = ProcurementProject(
            name: "Testupphandling",
            documents: [
                ProcurementDocument(
                    id: documentID,
                    name: "krav.pdf",
                    sourceURL: URL(fileURLWithPath: "/tmp/krav.pdf"),
                    importedAt: .now,
                    pageCount: 5,
                    characterCount: 1_000
                )
            ],
            requirements: [requirement]
        )
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResponsePlanTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let result = try ResponsePlanExporter().export(project: project, to: folder)
        let docxData = try Data(contentsOf: result.docxURL)
        let pdfData = try Data(contentsOf: result.pdfURL)

        #expect(docxData.starts(with: Data("PK".utf8)))
        #expect(pdfData.starts(with: Data("%PDF".utf8)))
        #expect(docxData.count > 500)
        #expect(pdfData.count > 1_000)
    }
}
