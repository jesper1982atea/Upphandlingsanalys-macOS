import AppKit
import Combine
import Foundation
import ProcurementRAGCore
import UniformTypeIdentifiers

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var documents: [ProcurementDocument] = []
    @Published private(set) var chunks: [DocumentChunk] = []
    @Published var requirements: [Requirement] = []
    @Published private(set) var products: [ProcurementProduct] = []
    @Published var searchResults: [SearchResult] = []
    @Published var query = ""
    @Published var generatedAnswer = ""
    @Published var requirementSummary = ""
    @Published var selection: AppSection? = .overview
    @Published var selectedRequirementCategory: RequirementCategory?
    @Published var selectedRequirementDocumentID: UUID?
    @Published var requirementFilter = ""
    @Published var requirementReviewFilter = RequirementReviewFilter.all
    @Published var productFilter = ""
    @Published var onlineProductFilter = ""
    @Published private(set) var summarizingRequirementIDs: Set<UUID> = []
    @Published var selectedSourceChunkID: UUID?
    @Published var selectedDocumentPage: Int?
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let processor = DocumentProcessor()
    private let extractor = RequirementExtractor()
    private let intelligence = AppleIntelligenceService()
    private let persistenceURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        persistenceURL = appSupport
            .appendingPathComponent("ProcurementRAG", isDirectory: true)
            .appendingPathComponent("library.json")
        load()
        backfillProductsIfNeeded()
    }

    func chooseAndImportDocuments() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .pdf,
            .plainText,
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "xls")!,
            UTType(filenameExtension: "xlsx")!
        ]
        panel.message = "Välj upphandlingsdokument i PDF-, Excel-, TXT- eller Markdown-format"

        guard panel.runModal() == .OK else { return }
        importDocuments(at: panel.urls)
    }

    func chooseAndImportFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.prompt = "Läs in mapp"
        panel.message = "Alla PDF-, Excel-, TXT- och Markdown-filer i mappen och dess undermappar läses in"

        guard panel.runModal() == .OK, let folder = panel.url else { return }

        do {
            let urls = try supportedDocumentURLs(in: folder)
            guard !urls.isEmpty else {
                errorMessage = "Mappen innehåller inga PDF-, Excel-, TXT- eller Markdown-filer."
                return
            }
            importDocuments(at: urls)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importDocuments(at urls: [URL]) {
        let existingPaths = Set(documents.map { $0.sourceURL.standardizedFileURL.path })
        let newURLs = urls.filter { !existingPaths.contains($0.standardizedFileURL.path) }
        guard !newURLs.isEmpty else {
            errorMessage = "Alla filer är redan inlästa."
            return
        }

        isWorking = true
        errorMessage = nil

        Task {
            let output = await Task.detached(priority: .userInitiated) {
                var processed: [(ProcurementDocument, [DocumentChunk], [ProcurementProduct])] = []
                var failures: [String] = []

                for url in newURLs {
                    do {
                        let (document, chunks) = try DocumentProcessor().process(url: url)
                        let fileProducts: [ProcurementProduct]
                        if ["xls", "xlsx"].contains(url.pathExtension.lowercased()) {
                            let sheets = try SpreadsheetReader().read(url: url)
                            fileProducts = ProductExtractor().extract(from: sheets, document: document)
                        } else {
                            fileProducts = []
                        }
                        processed.append((document, chunks, fileProducts))
                    } catch {
                        failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
                return (processed, failures)
            }.value

            for (document, newChunks, newProducts) in output.0 {
                documents.append(document)
                chunks.append(contentsOf: newChunks)
                requirements.append(contentsOf: extractor.extract(from: newChunks))
                products.append(contentsOf: newProducts)
            }

            do {
                try save()
            } catch {
                errorMessage = error.localizedDescription
            }

            if !output.1.isEmpty {
                let preview = output.1.prefix(5).joined(separator: "\n")
                let remaining = output.1.count - min(output.1.count, 5)
                errorMessage = remaining > 0
                    ? "\(preview)\n…och \(remaining) ytterligare filer kunde inte läsas."
                    : preview
            }
            isWorking = false
        }
    }

    func search() {
        searchResults = RAGEngine(chunks: chunks).search(query)
        generatedAnswer = ""
    }

    func showSource(_ chunk: DocumentChunk) {
        selectedSourceChunkID = chunk.id
        selectedDocumentPage = chunk.page
        selection = .document(chunk.documentID)
    }

    func showRequirementSource(_ requirement: Requirement) {
        let candidates = chunks.filter { chunk in
            chunk.documentID == requirement.documentID
                && (requirement.page == nil || chunk.page == requirement.page)
        }
        let match = RAGEngine(chunks: candidates)
            .search(requirement.text, limit: 1)
            .first?
            .chunk
        if let match {
            showSource(match)
        } else {
            selectedSourceChunkID = nil
            selectedDocumentPage = requirement.page
            selection = .document(requirement.documentID)
        }
    }

    func generateAnswer() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if searchResults.isEmpty {
            search()
        }
        let currentResults = searchResults
        isWorking = true
        errorMessage = nil

        Task {
            do {
                generatedAnswer = try await intelligence.answer(question: query, results: currentResults)
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func summarizeRequirements() {
        guard !requirements.isEmpty else { return }
        isWorking = true
        errorMessage = nil

        Task {
            do {
                requirementSummary = try await intelligence.requirementSummary(requirements: requirements)
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func summarizeRequirement(_ requirement: Requirement) {
        guard !summarizingRequirementIDs.contains(requirement.id) else { return }
        summarizingRequirementIDs.insert(requirement.id)
        errorMessage = nil

        Task {
            do {
                try await generateAndStoreSummary(for: requirement)
            } catch {
                errorMessage = error.localizedDescription
            }
            summarizingRequirementIDs.remove(requirement.id)
        }
    }

    func summarizeRequirementsIndividually(_ selectedRequirements: [Requirement]) {
        let pending = selectedRequirements.filter {
            $0.aiSummary == nil && !summarizingRequirementIDs.contains($0.id)
        }
        guard !pending.isEmpty else { return }
        errorMessage = nil

        Task {
            for requirement in pending {
                summarizingRequirementIDs.insert(requirement.id)
                do {
                    try await generateAndStoreSummary(for: requirement)
                } catch {
                    errorMessage = error.localizedDescription
                    summarizingRequirementIDs.remove(requirement.id)
                    break
                }
                summarizingRequirementIDs.remove(requirement.id)
            }
        }
    }

    func clearRequirementSummary(_ requirement: Requirement) {
        guard let index = requirements.firstIndex(where: { $0.id == requirement.id }) else { return }
        requirements[index].aiSummary = nil
        do {
            try save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateAndStoreSummary(for requirement: Requirement) async throws {
        let relevantChunks = RAGEngine(
            chunks: chunks.filter { $0.documentID == requirement.documentID }
        )
        .search(requirement.text, limit: 4)
        .map(\.chunk)
        let summary = try await intelligence.summarize(
            requirement: requirement,
            context: relevantChunks
        )
        guard let index = requirements.firstIndex(where: { $0.id == requirement.id }) else {
            return
        }
        requirements[index].aiSummary = summary
        try save()
    }

    func toggleReviewed(_ requirement: Requirement) {
        guard let index = requirements.firstIndex(where: { $0.id == requirement.id }) else { return }
        requirements[index].isReviewed.toggle()
        do {
            try save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeDocument(_ document: ProcurementDocument) {
        documents.removeAll { $0.id == document.id }
        chunks.removeAll { $0.documentID == document.id }
        requirements.removeAll { $0.documentID == document.id }
        products.removeAll { $0.documentID == document.id }
        searchResults.removeAll { $0.chunk.documentID == document.id }
        do {
            try save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let library = try? JSONDecoder().decode(PersistedLibrary.self, from: data) else {
            return
        }
        documents = library.documents
        chunks = library.chunks
        requirements = library.requirements
        products = library.products
    }

    private func save() throws {
        let folder = persistenceURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(
            PersistedLibrary(
                documents: documents,
                chunks: chunks,
                requirements: requirements,
                products: products
            )
        )
        try data.write(to: persistenceURL, options: .atomic)
    }

    private func backfillProductsIfNeeded() {
        let spreadsheetDocuments = documents.filter {
            ["xls", "xlsx"].contains($0.sourceURL.pathExtension.lowercased())
        }
        guard !spreadsheetDocuments.isEmpty else { return }

        Task {
            let extracted = await Task.detached(priority: .utility) {
                spreadsheetDocuments.flatMap { document -> [ProcurementProduct] in
                    guard let sheets = try? SpreadsheetReader().read(url: document.sourceURL) else {
                        return []
                    }
                    return ProductExtractor().extract(from: sheets, document: document)
                }
            }.value
            products = extracted
            do {
                try save()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func supportedDocumentURLs(in folder: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let supportedExtensions: Set<String> = ["pdf", "xls", "xlsx", "txt", "md"]
        var urls: [URL] = []

        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true,
                  values.isHidden != true,
                  supportedExtensions.contains(url.pathExtension.lowercased()) else {
                continue
            }
            urls.append(url)
        }

        return urls.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }
}
