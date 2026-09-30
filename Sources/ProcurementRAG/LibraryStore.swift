import AppKit
import Combine
import Foundation
import ProcurementRAGCore
import UniformTypeIdentifiers

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var projects: [ProcurementProject] = []
    @Published private(set) var activeProjectID: UUID?
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
    @Published var responseWorkspace = TenderResponseWorkspace()
    @Published private(set) var summarizingRequirementIDs: Set<UUID> = []
    @Published var selectedSourceChunkID: UUID?
    @Published var selectedDocumentPage: Int?
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let processor = DocumentProcessor()
    private let extractor = RequirementExtractor()
    private let intelligence = AppleIntelligenceService()
    private let responsePlanExporter = ResponsePlanExporter()
    private let persistenceURL: URL
    private var pendingResponseSave: Task<Void, Never>?

    var activeProject: ProcurementProject? {
        guard let activeProjectID else { return nil }
        return currentProjectSnapshot(
            basedOn: projects.first { $0.id == activeProjectID }
        )
    }

    var unansweredRequirementCount: Int {
        requirements.filter {
            let response = responseWorkspace.requirementResponses[$0.id] ?? RequirementResponse()
            return response.status == .unanswered
                || response.responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || response.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || response.owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    var responseMissingCount: Int {
        var count = 0
        let requiredTexts = [
            responseWorkspace.procurementReference,
            responseWorkspace.contractingAuthority,
            responseWorkspace.submissionDeadline,
            responseWorkspace.scopeSummary,
            responseWorkspace.organizationName,
            responseWorkspace.organizationNumber,
            responseWorkspace.contactName,
            responseWorkspace.contactEmail,
            responseWorkspace.bidLead,
            responseWorkspace.pricingOwner,
            responseWorkspace.legalApprover,
            responseWorkspace.offerSummary,
            responseWorkspace.deliveryPlan,
            responseWorkspace.securityResponse,
            responseWorkspace.sustainabilityResponse
        ]
        count += requiredTexts.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        count += unansweredRequirementCount
        count += responseWorkspace.productsVerified ? 0 : 1
        count += responseWorkspace.pricingComplete ? 0 : 1
        count += responseWorkspace.deliveryConfirmed ? 0 : 1
        count += responseWorkspace.requiredAttachmentsComplete ? 0 : 1
        count += responseWorkspace.legalReviewComplete ? 0 : 1
        count += responseWorkspace.qualityReviewComplete ? 0 : 1
        return count
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        persistenceURL = appSupport
            .appendingPathComponent("ProcurementRAG", isDirectory: true)
            .appendingPathComponent("library.json")
        load()
        backfillProductsIfNeeded()
    }

    func chooseAndCreateProject() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Skapa projekt"
        panel.message = "Välj upphandlingens huvudmapp. Projektet får samma namn som mappen."

        guard panel.runModal() == .OK, let folder = panel.url else { return }
        createProject(name: folder.lastPathComponent, sourceFolder: folder)

        do {
            let urls = try supportedDocumentURLs(in: folder)
            if urls.isEmpty {
                errorMessage = "Projektet skapades, men mappen innehåller inga dokument som stöds."
            } else {
                importDocuments(at: urls)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createProject(name: String, sourceFolder: URL? = nil) {
        persistActiveProjectInMemory()
        let project = ProcurementProject(name: name, sourceFolder: sourceFolder)
        projects.append(project)
        activeProjectID = project.id
        loadProject(project)
        selection = .overview
        try? save()
    }

    func switchProject(to projectID: UUID) {
        guard projectID != activeProjectID,
              let project = projects.first(where: { $0.id == projectID }) else {
            return
        }
        persistActiveProjectInMemory()
        activeProjectID = projectID
        loadProject(project)
        resetTransientState()
        selection = .overview
        try? save()
    }

    func renameActiveProject(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let activeProjectID,
              let index = projects.firstIndex(where: { $0.id == activeProjectID }) else {
            return
        }
        projects[index].name = trimmed
        projects[index].updatedAt = .now
        try? save()
    }

    func promptToRenameProject(_ project: ProcurementProject) {
        let field = NSTextField(string: project.name)
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)

        let alert = NSAlert()
        alert.messageText = "Byt namn på projekt"
        alert.informativeText = "Namnet används i appen och i exporterade svarsplaner."
        alert.accessoryView = field
        alert.addButton(withTitle: "Spara")
        alert.addButton(withTitle: "Avbryt")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              let index = projects.firstIndex(where: { $0.id == project.id }) else {
            return
        }
        projects[index].name = name
        projects[index].updatedAt = .now
        try? save()
    }

    func confirmAndDeleteProject(_ project: ProcurementProject) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Ta bort \(project.name)?"
        alert.informativeText = """
        Projektet och dess sparade analys, kravsvar och svarsplan tas bort från Atea upphandling.

        Originalfilerna och den valda mappen på datorn raderas inte.
        """
        alert.addButton(withTitle: "Ta bort projekt")
        alert.addButton(withTitle: "Avbryt")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        persistActiveProjectInMemory()
        projects.removeAll { $0.id == project.id }
        if project.id == activeProjectID {
            activeProjectID = projects.first?.id
            if let replacement = projects.first {
                loadProject(replacement)
            } else {
                documents = []
                chunks = []
                requirements = []
                products = []
                responseWorkspace = TenderResponseWorkspace()
            }
            resetTransientState()
            selection = .projects
        }
        try? save()
    }

    func exportResponsePlan() {
        guard let project = activeProject else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Exportera DOCX och PDF"
        panel.message = "Välj mapp för svarsplanen i Word- och PDF-format"
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        do {
            let result = try responsePlanExporter.export(project: project, to: folder)
            NSWorkspace.shared.activateFileViewerSelecting([result.docxURL, result.pdfURL])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateResponseWorkspace(
        _ update: (inout TenderResponseWorkspace) -> Void
    ) {
        update(&responseWorkspace)
        scheduleResponseSave()
    }

    func response(for requirementID: UUID) -> RequirementResponse {
        responseWorkspace.requirementResponses[requirementID] ?? RequirementResponse()
    }

    func updateResponse(
        for requirementID: UUID,
        _ update: (inout RequirementResponse) -> Void
    ) {
        var response = response(for: requirementID)
        update(&response)
        responseWorkspace.requirementResponses[requirementID] = response
        scheduleResponseSave()
    }

    func moveWizard(to step: Int) {
        responseWorkspace.currentStep = min(max(step, 0), 5)
        scheduleResponseSave()
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
        if activeProjectID == nil {
            createProject(name: "Min upphandling")
        }
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
        guard let data = try? Data(contentsOf: persistenceURL) else {
            let project = ProcurementProject(name: "Min upphandling")
            projects = [project]
            activeProjectID = project.id
            return
        }

        let decoder = JSONDecoder()
        if let workspace = try? decoder.decode(ProjectWorkspace.self, from: data),
           !workspace.projects.isEmpty {
            projects = workspace.projects
            let selectedID = workspace.activeProjectID.flatMap { id in
                projects.contains(where: { $0.id == id }) ? id : nil
            } ?? projects[0].id
            activeProjectID = selectedID
            if let project = projects.first(where: { $0.id == selectedID }) {
                loadProject(project)
            }
            return
        }

        if let library = try? decoder.decode(PersistedLibrary.self, from: data) {
            let folder = commonSourceFolder(for: library.documents)
            let project = ProcurementProject(
                name: folder?.lastPathComponent ?? "Importerad upphandling",
                sourceFolder: folder,
                createdAt: library.documents.map(\.importedAt).min() ?? .now,
                documents: library.documents,
                chunks: library.chunks,
                requirements: library.requirements,
                products: library.products
            )
            projects = [project]
            activeProjectID = project.id
            loadProject(project)
            try? save()
        }
    }

    private func save() throws {
        persistActiveProjectInMemory()
        let folder = persistenceURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(
            ProjectWorkspace(projects: projects, activeProjectID: activeProjectID)
        )
        try data.write(to: persistenceURL, options: .atomic)
    }

    private func persistActiveProjectInMemory() {
        guard let activeProjectID,
              let index = projects.firstIndex(where: { $0.id == activeProjectID }) else {
            return
        }
        if let snapshot = currentProjectSnapshot(basedOn: projects[index]) {
            projects[index] = snapshot
        }
    }

    private func currentProjectSnapshot(basedOn project: ProcurementProject?) -> ProcurementProject? {
        guard var project else { return nil }
        project.updatedAt = .now
        project.documents = documents
        project.chunks = chunks
        project.requirements = requirements
        project.products = products
        project.responseWorkspace = responseWorkspace
        return project
    }

    private func loadProject(_ project: ProcurementProject) {
        documents = project.documents
        chunks = project.chunks
        requirements = project.requirements
        products = project.products
        responseWorkspace = project.responseWorkspace ?? TenderResponseWorkspace()
    }

    private func resetTransientState() {
        searchResults = []
        query = ""
        generatedAnswer = ""
        requirementSummary = ""
        selectedRequirementCategory = nil
        selectedRequirementDocumentID = nil
        requirementFilter = ""
        productFilter = ""
        onlineProductFilter = ""
        selectedSourceChunkID = nil
        selectedDocumentPage = nil
    }

    private func scheduleResponseSave() {
        pendingResponseSave?.cancel()
        pendingResponseSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            do {
                try self.save()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func commonSourceFolder(for documents: [ProcurementDocument]) -> URL? {
        guard let first = documents.first else { return nil }
        let folders = documents.map { $0.sourceURL.deletingLastPathComponent().standardizedFileURL }
        var candidate = first.sourceURL.deletingLastPathComponent().standardizedFileURL
        while !folders.allSatisfy({ $0.path.hasPrefix(candidate.path) }) {
            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else { return nil }
            candidate = parent
        }
        return candidate
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
