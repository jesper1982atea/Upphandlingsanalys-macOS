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

public struct ProcurementProject: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var sourceFolder: URL?
    public let createdAt: Date
    public var updatedAt: Date
    public var documents: [ProcurementDocument]
    public var chunks: [DocumentChunk]
    public var requirements: [Requirement]
    public var products: [ProcurementProduct]
    public var responseWorkspace: TenderResponseWorkspace?

    public init(
        id: UUID = UUID(),
        name: String,
        sourceFolder: URL? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        documents: [ProcurementDocument] = [],
        chunks: [DocumentChunk] = [],
        requirements: [Requirement] = [],
        products: [ProcurementProduct] = [],
        responseWorkspace: TenderResponseWorkspace? = nil
    ) {
        self.id = id
        self.name = name
        self.sourceFolder = sourceFolder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.documents = documents
        self.chunks = chunks
        self.requirements = requirements
        self.products = products
        self.responseWorkspace = responseWorkspace
    }
}

public enum RequirementResponseStatus: String, Codable, CaseIterable, Sendable {
    case unanswered = "Ej besvarat"
    case compliant = "Uppfylls"
    case partial = "Uppfylls med förbehåll"
    case nonCompliant = "Uppfylls inte"
}

public struct RequirementResponse: Codable, Hashable, Sendable {
    public var status: RequirementResponseStatus
    public var responseText: String
    public var evidence: String
    public var owner: String

    public init(
        status: RequirementResponseStatus = .unanswered,
        responseText: String = "",
        evidence: String = "",
        owner: String = ""
    ) {
        self.status = status
        self.responseText = responseText
        self.evidence = evidence
        self.owner = owner
    }
}

public struct TenderResponseWorkspace: Codable, Hashable, Sendable {
    public var currentStep: Int
    public var procurementReference: String
    public var contractingAuthority: String
    public var submissionDeadline: String
    public var submissionPortal: String
    public var scopeSummary: String
    public var organizationName: String
    public var organizationNumber: String
    public var contactName: String
    public var contactEmail: String
    public var contactPhone: String
    public var bidLead: String
    public var pricingOwner: String
    public var legalApprover: String
    public var requirementResponses: [UUID: RequirementResponse]
    public var offerSummary: String
    public var deviations: String
    public var productsVerified: Bool
    public var pricingComplete: Bool
    public var deliveryConfirmed: Bool
    public var deliveryPlan: String
    public var securityResponse: String
    public var sustainabilityResponse: String
    public var requiredAttachmentsComplete: Bool
    public var legalReviewComplete: Bool
    public var qualityReviewComplete: Bool

    public init(
        currentStep: Int = 0,
        procurementReference: String = "",
        contractingAuthority: String = "",
        submissionDeadline: String = "",
        submissionPortal: String = "",
        scopeSummary: String = "",
        organizationName: String = "",
        organizationNumber: String = "",
        contactName: String = "",
        contactEmail: String = "",
        contactPhone: String = "",
        bidLead: String = "",
        pricingOwner: String = "",
        legalApprover: String = "",
        requirementResponses: [UUID: RequirementResponse] = [:],
        offerSummary: String = "",
        deviations: String = "",
        productsVerified: Bool = false,
        pricingComplete: Bool = false,
        deliveryConfirmed: Bool = false,
        deliveryPlan: String = "",
        securityResponse: String = "",
        sustainabilityResponse: String = "",
        requiredAttachmentsComplete: Bool = false,
        legalReviewComplete: Bool = false,
        qualityReviewComplete: Bool = false
    ) {
        self.currentStep = currentStep
        self.procurementReference = procurementReference
        self.contractingAuthority = contractingAuthority
        self.submissionDeadline = submissionDeadline
        self.submissionPortal = submissionPortal
        self.scopeSummary = scopeSummary
        self.organizationName = organizationName
        self.organizationNumber = organizationNumber
        self.contactName = contactName
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.bidLead = bidLead
        self.pricingOwner = pricingOwner
        self.legalApprover = legalApprover
        self.requirementResponses = requirementResponses
        self.offerSummary = offerSummary
        self.deviations = deviations
        self.productsVerified = productsVerified
        self.pricingComplete = pricingComplete
        self.deliveryConfirmed = deliveryConfirmed
        self.deliveryPlan = deliveryPlan
        self.securityResponse = securityResponse
        self.sustainabilityResponse = sustainabilityResponse
        self.requiredAttachmentsComplete = requiredAttachmentsComplete
        self.legalReviewComplete = legalReviewComplete
        self.qualityReviewComplete = qualityReviewComplete
    }
}

public struct ProjectWorkspace: Codable, Sendable {
    public var projects: [ProcurementProject]
    public var activeProjectID: UUID?

    public init(projects: [ProcurementProject], activeProjectID: UUID?) {
        self.projects = projects
        self.activeProjectID = activeProjectID
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
