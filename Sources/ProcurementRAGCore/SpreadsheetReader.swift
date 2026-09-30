import CoreXLSX
import Foundation
import LibXLS

public struct SpreadsheetSheet: Sendable {
    public let name: String
    public let rows: [[String]]

    public init(name: String, rows: [[String]]) {
        self.name = name
        self.rows = rows
    }
}

public struct SpreadsheetReader {
    public init() {}

    public func read(url: URL) throws -> [SpreadsheetSheet] {
        var output: [SpreadsheetSheet]?
        var readingError: Error?
        var coordinationError: NSError?

        NSFileCoordinator().coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            do {
                output = try readCoordinated(url: coordinatedURL)
            } catch {
                readingError = error
            }
        }

        if let readingError {
            throw readingError
        }
        if let coordinationError {
            throw DocumentProcessingError.fileAccessFailed(
                url,
                coordinationError.localizedDescription
            )
        }
        guard let output else {
            throw DocumentProcessingError.unreadableFile(url)
        }
        return output
    }

    func readCoordinated(url: URL) throws -> [SpreadsheetSheet] {
        switch url.pathExtension.lowercased() {
        case "xlsx":
            return try readXLSX(url: url)
        case "xls":
            return try readXLS(url: url)
        default:
            throw DocumentProcessingError.unsupportedFile(url)
        }
    }

    private func readXLSX(url: URL) throws -> [SpreadsheetSheet] {
        guard let file = XLSXFile(filepath: url.path) else {
            throw DocumentProcessingError.unreadableFile(url)
        }
        let sharedStrings = try file.parseSharedStrings()
        let paths = try file.parseWorksheetPaths()

        return try paths.enumerated().map { index, path in
            let worksheet = try file.parseWorksheet(at: path)
            let rows = worksheet.data?.rows.map { row in
                row.cells.map { cell in
                    if let sharedStrings {
                        if let value = cell.stringValue(sharedStrings) {
                            return value
                        }
                        let richText = cell.richStringValue(sharedStrings)
                            .compactMap(\.text)
                            .joined()
                        if !richText.isEmpty {
                            return richText
                        }
                    }
                    return cell.inlineString?.text ?? cell.value ?? ""
                }
            } ?? []
            return SpreadsheetSheet(name: "Kalkylblad \(index + 1)", rows: rows)
        }
    }

    private func readXLS(url: URL) throws -> [SpreadsheetSheet] {
        let workbook = try XLSWorkbook(filePath: url.path)
        return try (0..<workbook.sheetCount).map { index in
            let sheet = try workbook.sheet(at: index)
            let rows = sheet.stringRows.map { row in
                row.map { $0 ?? "" }
            }
            return SpreadsheetSheet(name: sheet.name, rows: rows)
        }
    }
}
