import Foundation

public struct ProductExtractor {
    public init() {}

    public func extract(
        from sheets: [SpreadsheetSheet],
        document: ProcurementDocument
    ) -> [ProcurementProduct] {
        sheets.flatMap { sheet in
            extract(from: sheet, document: document)
        }
    }

    private func extract(
        from sheet: SpreadsheetSheet,
        document: ProcurementDocument
    ) -> [ProcurementProduct] {
        let headerIndices = sheet.rows.prefix(80).indices.filter {
            headerScore(sheet.rows[$0]) >= 2
        }
        guard !headerIndices.isEmpty else { return [] }

        return headerIndices.enumerated().flatMap { position, headerIndex in
            let endIndex = position + 1 < headerIndices.count
                ? headerIndices[position + 1]
                : sheet.rows.endIndex
            return extractTable(
                from: sheet,
                document: document,
                headerIndex: headerIndex,
                endIndex: endIndex
            )
        }
    }

    private func extractTable(
        from sheet: SpreadsheetSheet,
        document: ProcurementDocument,
        headerIndex: Int,
        endIndex: Int
    ) -> [ProcurementProduct] {
        let headers = sheet.rows[headerIndex].map(normalizeHeader)
        guard let nameColumn = findColumn(in: headers, matching: nameTerms) else { return [] }

        let identifierColumn = findColumn(in: headers, matching: identifierTerms)
        let requirementColumns = headers.indices.filter { index in
            index != nameColumn &&
            requirementTerms.contains { headers[index].contains($0) }
        }

        return sheet.rows[(headerIndex + 1)..<endIndex].enumerated().compactMap { offset, row in
            guard nameColumn < row.count else { return nil }
            let rawName = clean(row[nameColumn])
            let parsedName = parseNameAndRequirements(rawName)
            let name = parsedName.name
            guard name.count > 1,
                  name.rangeOfCharacter(from: .letters) != nil,
                  !ignoredRowNames.contains(normalizeHeader(name)) else {
                return nil
            }

            let identifier = identifierColumn.flatMap { index in
                index < row.count ? nonEmpty(row[index]) : nil
            }
            let columnRequirements = requirementColumns.compactMap { index -> String? in
                guard index < row.count, let value = nonEmpty(row[index]) else { return nil }
                let header = displayHeader(sheet.rows[headerIndex], at: index)
                return header.isEmpty ? value : "\(header): \(value)"
            }
            let requirements = parsedName.requirements + columnRequirements
            let excluded = Set(
                [nameColumn] + requirementColumns + (identifierColumn.map { [$0] } ?? [])
            )
            let details = row.indices.compactMap { index -> String? in
                guard !excluded.contains(index), let value = nonEmpty(row[index]) else { return nil }
                let header = displayHeader(sheet.rows[headerIndex], at: index)
                return header.isEmpty ? value : "\(header): \(value)"
            }

            return ProcurementProduct(
                id: UUID(),
                name: name,
                identifier: identifier,
                details: details,
                requirements: requirements,
                documentID: document.id,
                documentName: document.name,
                sheetName: sheet.name,
                row: headerIndex + offset + 2
            )
        }
    }

    private func headerScore(_ row: [String]) -> Int {
        row.map(normalizeHeader).reduce(0) { score, value in
            let recognized = (nameTerms + identifierTerms + requirementTerms + contextTerms).contains {
                value.contains($0)
            }
            return score + (recognized ? 1 : 0)
        }
    }

    private func findColumn(in headers: [String], matching terms: [String]) -> Int? {
        for term in terms {
            if let exact = headers.firstIndex(of: term) {
                return exact
            }
        }
        for term in terms {
            if let partial = headers.firstIndex(where: { $0.contains(term) }) {
                return partial
            }
        }
        return nil
    }

    private func displayHeader(_ row: [String], at index: Int) -> String {
        guard index < row.count else { return "" }
        return clean(row[index])
    }

    private func normalizeHeader(_ value: String) -> String {
        clean(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "sv_SE"))
            .lowercased()
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nonEmpty(_ value: String) -> String? {
        let value = clean(value)
        return value.isEmpty ? nil : value
    }

    private func parseNameAndRequirements(_ value: String) -> (name: String, requirements: [String]) {
        let lines = value
            .components(separatedBy: .newlines)
            .map(clean)
            .filter { !$0.isEmpty }
        guard let name = lines.first else { return ("", []) }
        return (name, Array(lines.dropFirst()))
    }

    private let nameTerms = [
        "efterfragad vara", "efterfragad tjanst", "mobiltelefonmodell",
        "produktnamn", "produkt", "benamning", "artikelnamn", "vara", "tjanst", "sortiment"
    ]
    private let identifierTerms = [
        "artikelnummer", "artikelnr", "produktnummer", "produktnr", "position", "pos", "id"
    ]
    private let requirementTerms = [
        "krav", "specifikation", "egenskap", "obligatorisk", "minimum", "beskrivning"
    ]
    private let contextTerms = [
        "pris", "enhet", "antal", "kvantitet", "valuta", "leverantor"
    ]
    private let ignoredRowNames: Set<String> = [
        "totalt", "summa", "delsumma", "subtotal", "total"
    ]
}
