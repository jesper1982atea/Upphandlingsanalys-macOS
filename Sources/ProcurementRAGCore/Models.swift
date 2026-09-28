import Foundation

public struct ProcurementDocument: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let sourceURL: URL
    public let importedAt: Date
    public let pageCount: Int
    public let characterCount: Int

    public init(id: UUID, name: String, sourceURL: URL, importedAt: Date, pageCount: Int, characterCount: Int) {
        self.id = id
        self.name = name
        self.sourceURL = sourceURL
        self.importedAt = importedAt
        self.pageCount = pageCount
        self.characterCount = characterCount
    }
}

public struct DocumentChunk: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let documentID: UUID
    public let documentName: String
    public let page: Int?
    public let text: String

    public init(id: UUID, documentID: UUID, documentName: String, page: Int?, text: String) {
        self.id = id
        self.documentID = documentID
        self.documentName = documentName
        self.page = page
        self.text = text
    }
}

public enum RequirementCategory: String, Codable, CaseIterable, Sendable {
    case mandatory = "Obligatoriskt krav"
    case evaluation = "Utvärderingskrav"
    case contractual = "Avtalskrav"
    case information = "Övrigt"

    public var symbol: String {
        switch self {
        case .mandatory: "exclamationmark.shield.fill"
        case .evaluation: "star.fill"
        case .contractual: "doc.badge.gearshape"
        case .information: "info.circle"
        }
    }
}

public struct Requirement: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let text: String
    public let category: RequirementCategory
    public let documentID: UUID
    public let documentName: String
    public let page: Int?
    public var isReviewed: Bool
    public var aiSummary: String?

    public init(
        id: UUID,
        text: String,
        category: RequirementCategory,
        documentID: UUID,
        documentName: String,
        page: Int?,
        isReviewed: Bool,
        aiSummary: String? = nil
    ) {
        self.id = id
        self.text = text
        self.category = category
        self.documentID = documentID
        self.documentName = documentName
        self.page = page
        self.isReviewed = isReviewed
        self.aiSummary = aiSummary
    }
}

public struct SearchResult: Identifiable, Hashable, Sendable {
    public let chunk: DocumentChunk
    public let score: Double

    public var id: UUID { chunk.id }

    public init(chunk: DocumentChunk, score: Double) {
        self.chunk = chunk
        self.score = score
    }
}

public struct ProcurementProduct: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let identifier: String?
    public let details: [String]
    public let requirements: [String]
    public let documentID: UUID
    public let documentName: String
    public let sheetName: String
    public let row: Int

    public init(
        id: UUID,
        name: String,
        identifier: String?,
        details: [String],
        requirements: [String],
        documentID: UUID,
        documentName: String,
        sheetName: String,
        row: Int
    ) {
        self.id = id
        self.name = name
        self.identifier = identifier
        self.details = details
        self.requirements = requirements
        self.documentID = documentID
        self.documentName = documentName
        self.sheetName = sheetName
        self.row = row
    }
}

public struct PersistedLibrary: Codable, Sendable {
    public var documents: [ProcurementDocument]
    public var chunks: [DocumentChunk]
    public var requirements: [Requirement]
    public var products: [ProcurementProduct]

    public static let empty = PersistedLibrary(documents: [], chunks: [], requirements: [], products: [])

    public init(
        documents: [ProcurementDocument],
        chunks: [DocumentChunk],
        requirements: [Requirement],
        products: [ProcurementProduct] = []
    ) {
        self.documents = documents
        self.chunks = chunks
        self.requirements = requirements
        self.products = products
    }

    private enum CodingKeys: String, CodingKey {
        case documents, chunks, requirements, products
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        documents = try container.decode([ProcurementDocument].self, forKey: .documents)
        chunks = try container.decode([DocumentChunk].self, forKey: .chunks)
        requirements = try container.decode([Requirement].self, forKey: .requirements)
        products = try container.decodeIfPresent([ProcurementProduct].self, forKey: .products) ?? []
    }
}
