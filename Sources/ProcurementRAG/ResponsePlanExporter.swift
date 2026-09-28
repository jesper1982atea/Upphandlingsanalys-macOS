import AppKit
import Foundation
import ProcurementRAGCore
import ZIPFoundation

@MainActor
struct ResponsePlanExporter {
    struct ExportResult {
        let docxURL: URL
        let pdfURL: URL
    }

    func export(project: ProcurementProject, to folder: URL) throws -> ExportResult {
        let baseName = sanitizedFileName("\(project.name) - svarsplan")
        let docxURL = folder.appendingPathComponent(baseName).appendingPathExtension("docx")
        let pdfURL = folder.appendingPathComponent(baseName).appendingPathExtension("pdf")
        let plan = ResponsePlan(project: project)

        try writeDOCX(plan: plan, to: docxURL)
        try writePDF(plan: plan, to: pdfURL)
        return ExportResult(docxURL: docxURL, pdfURL: pdfURL)
    }

    private func writeDOCX(plan: ResponsePlan, to destination: URL) throws {
        let fileManager = FileManager.default
        let workingFolder = fileManager.temporaryDirectory
            .appendingPathComponent("ProcurementRAG-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: workingFolder) }

        let relationshipsFolder = workingFolder.appendingPathComponent("_rels", isDirectory: true)
        let wordFolder = workingFolder.appendingPathComponent("word", isDirectory: true)
        try fileManager.createDirectory(at: relationshipsFolder, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: wordFolder, withIntermediateDirectories: true)

        try contentTypesXML.write(
            to: workingFolder.appendingPathComponent("[Content_Types].xml"),
            atomically: true,
            encoding: .utf8
        )
        try relationshipsXML.write(
            to: relationshipsFolder.appendingPathComponent(".rels"),
            atomically: true,
            encoding: .utf8
        )
        try documentXML(for: plan).write(
            to: wordFolder.appendingPathComponent("document.xml"),
            atomically: true,
            encoding: .utf8
        )

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.zipItem(at: workingFolder, to: destination, shouldKeepParent: false)
    }

    private func writePDF(plan: ResponsePlan, to destination: URL) throws {
        let attributed = try NSAttributedString(
            data: Data(html(for: plan).utf8),
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.paperSize = NSSize(width: 595, height: 842)
        printInfo.topMargin = 42
        printInfo.bottomMargin = 42
        printInfo.leftMargin = 48
        printInfo.rightMargin = 48
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destination

        let contentWidth = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 842))
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textStorage?.setAttributedString(attributed)
        textView.sizeToFit()

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard operation.run() else {
            throw ExportError.pdfCreationFailed
        }
    }

    private func documentXML(for plan: ResponsePlan) -> String {
        let body = plan.blocks.map { block in
            switch block {
            case .heading(let text, let level):
                return paragraphXML(text, style: level == 1 ? "Title" : "Heading\(min(level, 3))")
            case .paragraph(let text):
                return paragraphXML(text)
            case .bullet(let text):
                return paragraphXML("• \(text)")
            case .pageBreak:
                return "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
            }
        }
        .joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            \(body)
            <w:sectPr>
              <w:pgSz w:w="11906" w:h="16838"/>
              <w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>
            </w:sectPr>
          </w:body>
        </w:document>
        """
    }

    private func paragraphXML(_ text: String, style: String? = nil) -> String {
        let styleXML = style.map { "<w:pPr><w:pStyle w:val=\"\($0)\"/></w:pPr>" } ?? ""
        return "<w:p>\(styleXML)<w:r><w:t xml:space=\"preserve\">\(xmlEscaped(text))</w:t></w:r></w:p>"
    }

    private func html(for plan: ResponsePlan) -> String {
        let content = plan.blocks.map { block in
            switch block {
            case .heading(let text, let level):
                return "<h\(level)>\(htmlEscaped(text))</h\(level)>"
            case .paragraph(let text):
                return "<p>\(htmlEscaped(text))</p>"
            case .bullet(let text):
                return "<div class=\"bullet\">• \(htmlEscaped(text))</div>"
            case .pageBreak:
                return "<div class=\"page-break\"></div>"
            }
        }
        .joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="sv"><head><meta charset="utf-8">
        <style>
        body { font-family: -apple-system, Helvetica, Arial, sans-serif; color: #172033; font-size: 11pt; line-height: 1.45; }
        h1 { color: #3548c8; font-size: 27pt; margin: 0 0 14pt; }
        h2 { color: #273577; font-size: 18pt; margin: 22pt 0 8pt; border-bottom: 1px solid #d9def5; padding-bottom: 5pt; }
        h3 { color: #3548c8; font-size: 13pt; margin: 14pt 0 5pt; }
        p { margin: 4pt 0 9pt; }
        .bullet { margin: 3pt 0 3pt 14pt; }
        .page-break { page-break-before: always; }
        </style></head><body>\(content)</body></html>
        """
    }

    private func sanitizedFileName(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    private func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func htmlEscaped(_ value: String) -> String {
        xmlEscaped(value)
    }

    private let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    </Types>
    """

    private let relationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """

    enum ExportError: LocalizedError {
        case pdfCreationFailed

        var errorDescription: String? {
            "PDF-filen kunde inte skapas."
        }
    }
}

private struct ResponsePlan {
    enum Block {
        case heading(String, Int)
        case paragraph(String)
        case bullet(String)
        case pageBreak
    }

    let project: ProcurementProject

    var blocks: [Block] {
        var result: [Block] = [
            .heading("Svarsplan – \(project.name)", 1),
            .paragraph("Genererad \(Date.now.formatted(date: .long, time: .shortened))"),
            .paragraph("Denna plan sammanställer hur anbudsarbetet bör genomföras. Varje krav ska verifieras mot originalkällan innan svaret lämnas."),
            .heading("Lägesbild", 2),
            .bullet("\(project.documents.count) dokument och \(project.chunks.count) sökbara avsnitt"),
            .bullet("\(project.requirements.count) identifierade krav, varav \(reviewedCount) granskade"),
            .bullet("\(project.products.count) produkt- och tjänsterader"),
            .bullet("\(mandatoryCount) obligatoriska krav kräver ett entydigt svar och bevis"),
            .heading("Rekommenderad arbetsordning", 2),
            .heading("1. Kvalificera upphandlingen", 3),
            .bullet("Bekräfta sista svarsdag, formkrav, obligatoriska bilagor och behörig undertecknare."),
            .bullet("Tilldela ansvarig person till varje obligatoriskt krav och varje kommersiell bilaga."),
            .heading("2. Bygg svarsmatrisen", 3),
            .bullet("Besvara varje krav med Uppfylls, Uppfylls med förbehåll eller Uppfylls inte."),
            .bullet("Koppla bevis, dokumentnamn, sida eller kalkylbladsrad till varje svar."),
            .heading("3. Säkra produkt- och prisunderlag", 3),
            .bullet("Verifiera artikelnummer, livscykel, tillgänglighet, garantier och samtliga tekniska minimikrav."),
            .bullet("Markera attribut som kräver tillverkarintyg eller leverantörsförsäkran."),
            .heading("4. Kvalitetssäkra och lämna in", 3),
            .bullet("Genomför oberoende kontroll av alla obligatoriska krav och bilagor."),
            .bullet("Kontrollera att priser, reservationer och svar är konsekventa i samtliga dokument."),
            .pageBreak,
            .heading("Krav- och svarsmatris", 1)
        ]

        for category in RequirementCategory.allCases {
            let requirements = project.requirements.filter { $0.category == category }
            guard !requirements.isEmpty else { continue }
            result.append(.heading(category.rawValue, 2))
            for (index, requirement) in requirements.enumerated() {
                result.append(.heading("\(index + 1). \(requirement.isReviewed ? "Granskad" : "Att granska")", 3))
                result.append(.paragraph(requirement.text))
                result.append(.bullet("Källa: \(sourceLabel(requirement))"))
                if let summary = requirement.aiSummary, !summary.isEmpty {
                    result.append(.bullet("Svarsstöd: \(summary)"))
                } else {
                    result.append(.bullet("Svarsstöd: Beskriv hur kravet uppfylls och bifoga verifierbart bevis."))
                }
            }
        }

        result.append(.pageBreak)
        result.append(.heading("Dokument- och produktkontroll", 1))
        result.append(.heading("Källdokument", 2))
        for document in project.documents {
            let unit = ["xls", "xlsx"].contains(document.sourceURL.pathExtension.lowercased())
                ? "kalkylblad"
                : "sidor"
            result.append(.bullet("\(document.name) – \(document.pageCount) \(unit)"))
        }
        result.append(.heading("Produkter och tjänster", 2))
        for product in project.products {
            let identifier = product.identifier.map { " – \($0)" } ?? ""
            result.append(.bullet("\(product.name)\(identifier): \(product.requirements.count) produktspecifika krav, \(product.sheetName) rad \(product.row)"))
        }
        result.append(.heading("Slutlig kontroll", 2))
        result.append(.bullet("Alla obligatoriska krav är granskade och besvarade utan motsägelser."))
        result.append(.bullet("Alla hänvisningar går till rätt dokument, sida, blad eller rad."))
        result.append(.bullet("Produktbevis, priser, leveranstider och giltighetstider är aktuella."))
        result.append(.bullet("Behörig beslutsfattare har godkänt slutversionen före inlämning."))
        return result
    }

    private var reviewedCount: Int {
        project.requirements.filter(\.isReviewed).count
    }

    private var mandatoryCount: Int {
        project.requirements.filter { $0.category == .mandatory }.count
    }

    private func sourceLabel(_ requirement: Requirement) -> String {
        if let page = requirement.page {
            return "\(requirement.documentName), sida/blad \(page)"
        }
        return requirement.documentName
    }
}
