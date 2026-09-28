import ProcurementRAGCore
import SwiftUI

struct TenderWizardView: View {
    @EnvironmentObject private var store: LibraryStore

    private let steps = [
        WizardStep(title: "Upphandlingen", subtitle: "Referens, beställare och deadline", symbol: "doc.text.magnifyingglass"),
        WizardStep(title: "Anbudsteam", subtitle: "Organisation, kontakt och ansvar", symbol: "person.3.fill"),
        WizardStep(title: "Kravsvar", subtitle: "Svar, bevis och ansvarig per krav", symbol: "checklist.checked"),
        WizardStep(title: "Erbjudande", subtitle: "Produkter, priser och avvikelser", symbol: "shippingbox.fill"),
        WizardStep(title: "Leverans & kvalitet", subtitle: "Säkerhet, hållbarhet och leverans", symbol: "checkmark.shield.fill"),
        WizardStep(title: "Slutkontroll", subtitle: "Kvalitetssäkra och exportera", symbol: "paperplane.fill")
    ]

    private var currentStep: Int {
        min(max(store.responseWorkspace.currentStep, 0), steps.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            wizardHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    stepHeading
                    stepContent
                }
                .frame(maxWidth: 980, alignment: .leading)
                .padding(30)
                .frame(maxWidth: .infinity)
            }
            Divider()
            navigationBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ANBUDSGUIDE")
                        .font(.caption.bold())
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    Text(store.activeProject?.name ?? "Aktivt projekt")
                        .font(.title2.bold())
                }
                Spacer()
                Label(
                    store.responseMissingCount == 0
                        ? "Redo för slutkontroll"
                        : "\(store.responseMissingCount) uppgifter återstår",
                    systemImage: store.responseMissingCount == 0
                        ? "checkmark.seal.fill"
                        : "exclamationmark.circle.fill"
                )
                .font(.callout.bold())
                .foregroundStyle(store.responseMissingCount == 0 ? .green : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    (store.responseMissingCount == 0 ? Color.green : Color.orange).opacity(0.1),
                    in: Capsule()
                )
            }

            HStack(spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    WizardStepButton(
                        index: index,
                        step: step,
                        isSelected: index == currentStep,
                        missingCount: missingCount(for: index)
                    ) {
                        store.moveWizard(to: index)
                    }
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .background(.bar)
    }

    private var stepHeading: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: steps[currentStep].symbol)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Color(red: 0, green: 0.54, blue: 0), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text("Steg \(currentStep + 1) av \(steps.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(steps[currentStep].title)
                    .font(.largeTitle.bold())
                Text(steps[currentStep].subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if missingCount(for: currentStep) > 0 {
                Label(
                    "\(missingCount(for: currentStep)) saknas",
                    systemImage: "arrow.down.circle.fill"
                )
                .foregroundStyle(.red)
                .font(.headline)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0: procurementStep
        case 1: teamStep
        case 2: requirementsStep
        case 3: offerStep
        case 4: deliveryStep
        default: reviewStep
        }
    }

    private var procurementStep: some View {
        WizardSection(
            title: "Grunduppgifter",
            help: "Uppgifterna används i svarsplanens försättsblad och slutkontroll."
        ) {
            WizardField(
                title: "Upphandlingsreferens",
                placeholder: "Exempel: 2026-1234",
                text: workspaceBinding(\.procurementReference)
            )
            WizardField(
                title: "Upphandlande organisation",
                placeholder: "Kommun, region eller bolag",
                text: workspaceBinding(\.contractingAuthority)
            )
            WizardField(
                title: "Sista svarsdag och tid",
                placeholder: "ÅÅÅÅ-MM-DD HH:MM",
                text: workspaceBinding(\.submissionDeadline)
            )
            WizardField(
                title: "Inlämningsportal",
                placeholder: "Portal och eventuell URL",
                text: workspaceBinding(\.submissionPortal),
                required: false
            )
            WizardLongField(
                title: "Sammanfattning av omfattningen",
                placeholder: "Vad ska levereras, under vilken period och till vilka verksamheter?",
                text: workspaceBinding(\.scopeSummary)
            )
        }
    }

    private var teamStep: some View {
        VStack(spacing: 16) {
            WizardSection(
                title: "Anbudsgivare",
                help: "Juridiska uppgifter och huvudkontakt ska stämma med kvalificeringsbilagorna."
            ) {
                WizardField(title: "Organisationsnamn", placeholder: "Atea Sverige AB", text: workspaceBinding(\.organizationName))
                WizardField(title: "Organisationsnummer", placeholder: "XXXXXX-XXXX", text: workspaceBinding(\.organizationNumber))
                WizardField(title: "Kontaktperson", placeholder: "För- och efternamn", text: workspaceBinding(\.contactName))
                WizardField(title: "E-post", placeholder: "namn@atea.se", text: workspaceBinding(\.contactEmail))
                WizardField(title: "Telefon", placeholder: "+46 …", text: workspaceBinding(\.contactPhone), required: false)
            }
            WizardSection(
                title: "Ansvariga",
                help: "Varje kritiskt område behöver en namngiven ägare före slutkontrollen."
            ) {
                WizardField(title: "Anbudsansvarig", placeholder: "Namn", text: workspaceBinding(\.bidLead))
                WizardField(title: "Pris- och kalkylansvarig", placeholder: "Namn", text: workspaceBinding(\.pricingOwner))
                WizardField(title: "Juridisk godkännare", placeholder: "Namn", text: workspaceBinding(\.legalApprover))
            }
        }
    }

    private var requirementsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardNotice(
                symbol: store.unansweredRequirementCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tint: store.unansweredRequirementCount == 0 ? .green : .orange,
                title: store.unansweredRequirementCount == 0
                    ? "Alla kravsvar är kompletta"
                    : "\(store.unansweredRequirementCount) kravsvar är ofullständiga",
                text: "Ange status, formulera svaret, peka ut bevis och tilldela en ansvarig. Börja med obligatoriska krav."
            )

            ForEach(sortedRequirements) { requirement in
                RequirementAnswerCard(
                    requirement: requirement,
                    status: requirementStatusBinding(requirement.id),
                    responseText: requirementTextBinding(requirement.id),
                    evidence: requirementEvidenceBinding(requirement.id),
                    owner: requirementOwnerBinding(requirement.id)
                )
            }
        }
    }

    private var offerStep: some View {
        VStack(spacing: 16) {
            WizardSection(
                title: "Erbjudandets innehåll",
                help: "Beskriv lösningen kort och tydligt. Avvikelser ska vara uttryckliga och konsekventa."
            ) {
                WizardLongField(
                    title: "Sammanfattning av erbjudandet",
                    placeholder: "Beskriv lösning, mervärden och varför erbjudandet uppfyller behovet.",
                    text: workspaceBinding(\.offerSummary)
                )
                WizardLongField(
                    title: "Avvikelser och förbehåll",
                    placeholder: "Skriv 'Inga' om erbjudandet saknar avvikelser.",
                    text: workspaceBinding(\.deviations),
                    required: false
                )
            }
            WizardSection(
                title: "Kommersiell kontroll",
                help: "Markera endast när underlaget är verifierat av ansvarig person."
            ) {
                WizardCheckRow(
                    title: "Produkter och tjänster är verifierade",
                    detail: "\(store.products.count) rader i projektets produktunderlag",
                    isOn: workspaceBinding(\.productsVerified)
                )
                WizardCheckRow(
                    title: "Priser och kalkyl är kompletta",
                    detail: "Alla priser, optioner, rabatter och indexvillkor är kontrollerade",
                    isOn: workspaceBinding(\.pricingComplete)
                )
                WizardCheckRow(
                    title: "Leveranstider och kapacitet är bekräftade",
                    detail: "Logistik, lager, etablering och beroenden är säkrade",
                    isOn: workspaceBinding(\.deliveryConfirmed)
                )
            }
        }
    }

    private var deliveryStep: some View {
        VStack(spacing: 16) {
            WizardSection(
                title: "Genomförande",
                help: "Dessa texter blir underlag i den exporterade svarsplanen."
            ) {
                WizardLongField(
                    title: "Leverans- och införandeplan",
                    placeholder: "Milstolpar, resurser, ansvar, tider, överlämning och uppföljning.",
                    text: workspaceBinding(\.deliveryPlan)
                )
                WizardLongField(
                    title: "Informationssäkerhet och dataskydd",
                    placeholder: "Styrning, tekniska kontroller, incidenthantering, personuppgifter och bevis.",
                    text: workspaceBinding(\.securityResponse)
                )
                WizardLongField(
                    title: "Hållbarhet",
                    placeholder: "Klimat, cirkularitet, återtag, social hållbarhet och uppföljning.",
                    text: workspaceBinding(\.sustainabilityResponse)
                )
            }
        }
    }

    private var reviewStep: some View {
        VStack(spacing: 16) {
            WizardNotice(
                symbol: store.responseMissingCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                tint: store.responseMissingCount == 0 ? .green : .orange,
                title: store.responseMissingCount == 0
                    ? "Anbudsunderlaget är redo för export"
                    : "\(store.responseMissingCount) kontrollpunkter återstår",
                text: "Exporten är ett arbetsunderlag. Behörig beslutsfattare ska alltid godkänna slutversionen före inlämning."
            )

            WizardSection(
                title: "Slutlig kvalitetssäkring",
                help: "Markera först när kontrollen är genomförd och dokumenterad."
            ) {
                WizardCheckRow(
                    title: "Alla obligatoriska bilagor är bifogade",
                    detail: "Intyg, referenser, försäkringar, produktblad och prisbilagor",
                    isOn: workspaceBinding(\.requiredAttachmentsComplete)
                )
                WizardCheckRow(
                    title: "Juridisk granskning är godkänd",
                    detail: "Avtal, reservationer, ansvar och sekretess är kontrollerade",
                    isOn: workspaceBinding(\.legalReviewComplete)
                )
                WizardCheckRow(
                    title: "Oberoende kvalitetskontroll är genomförd",
                    detail: "Svar, bilagor, priser och källhänvisningar är konsekventa",
                    isOn: workspaceBinding(\.qualityReviewComplete)
                )
            }

            HStack(spacing: 14) {
                Button {
                    store.selection = .responsePlan
                } label: {
                    Label("Förhandsgranska svarsplan", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: store.exportResponsePlan) {
                    Label("Exportera DOCX + PDF", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var navigationBar: some View {
        HStack {
            Button {
                store.moveWizard(to: currentStep - 1)
            } label: {
                Label("Föregående", systemImage: "chevron.left")
            }
            .disabled(currentStep == 0)

            Spacer()

            Text("Steg \(currentStep + 1) av \(steps.count)")
                .font(.callout.bold())
                .foregroundStyle(.secondary)

            Spacer()

            if currentStep < steps.count - 1 {
                Button {
                    store.moveWizard(to: currentStep + 1)
                } label: {
                    Label(
                        missingCount(for: currentStep) == 0 ? "Nästa" : "Fortsätt – uppgifter saknas",
                        systemImage: "chevron.right"
                    )
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: store.exportResponsePlan) {
                    Label("Exportera", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private var sortedRequirements: [Requirement] {
        store.requirements.sorted {
            if $0.category != $1.category {
                return categoryOrder($0.category) < categoryOrder($1.category)
            }
            return $0.documentName.localizedStandardCompare($1.documentName) == .orderedAscending
        }
    }

    private func categoryOrder(_ category: RequirementCategory) -> Int {
        switch category {
        case .mandatory: 0
        case .evaluation: 1
        case .contractual: 2
        case .information: 3
        }
    }

    private func missingCount(for step: Int) -> Int {
        let workspace = store.responseWorkspace
        switch step {
        case 0:
            return missing([
                workspace.procurementReference,
                workspace.contractingAuthority,
                workspace.submissionDeadline,
                workspace.scopeSummary
            ])
        case 1:
            return missing([
                workspace.organizationName,
                workspace.organizationNumber,
                workspace.contactName,
                workspace.contactEmail,
                workspace.bidLead,
                workspace.pricingOwner,
                workspace.legalApprover
            ])
        case 2:
            return store.unansweredRequirementCount
        case 3:
            return missing([workspace.offerSummary])
                + (workspace.productsVerified ? 0 : 1)
                + (workspace.pricingComplete ? 0 : 1)
                + (workspace.deliveryConfirmed ? 0 : 1)
        case 4:
            return missing([
                workspace.deliveryPlan,
                workspace.securityResponse,
                workspace.sustainabilityResponse
            ])
        default:
            return (workspace.requiredAttachmentsComplete ? 0 : 1)
                + (workspace.legalReviewComplete ? 0 : 1)
                + (workspace.qualityReviewComplete ? 0 : 1)
        }
    }

    private func missing(_ values: [String]) -> Int {
        values.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private func workspaceBinding<Value>(
        _ keyPath: WritableKeyPath<TenderResponseWorkspace, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.responseWorkspace[keyPath: keyPath] },
            set: { value in
                store.updateResponseWorkspace { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func requirementStatusBinding(_ id: UUID) -> Binding<RequirementResponseStatus> {
        Binding(
            get: { store.response(for: id).status },
            set: { value in store.updateResponse(for: id) { $0.status = value } }
        )
    }

    private func requirementTextBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { store.response(for: id).responseText },
            set: { value in store.updateResponse(for: id) { $0.responseText = value } }
        )
    }

    private func requirementEvidenceBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { store.response(for: id).evidence },
            set: { value in store.updateResponse(for: id) { $0.evidence = value } }
        )
    }

    private func requirementOwnerBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { store.response(for: id).owner },
            set: { value in store.updateResponse(for: id) { $0.owner = value } }
        )
    }
}

private struct WizardStep {
    let title: String
    let subtitle: String
    let symbol: String
}

private struct WizardStepButton: View {
    let index: Int
    let step: WizardStep
    let isSelected: Bool
    let missingCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: step.symbol)
                    Spacer()
                    if missingCount == 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(isSelected ? .white : .green)
                    } else {
                        Text("\(missingCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(isSelected ? .white : .orange)
                    }
                }
                Text("\(index + 1). \(step.title)")
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? Color(red: 0, green: 0.54, blue: 0)
                    : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WizardSection<Content: View>: View {
    let title: String
    let help: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                Text(help)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).stroke(.quaternary)
        }
    }
}

private struct WizardField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var required = true

    private var isMissing: Bool {
        required && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                if required {
                    Text("OBLIGATORISK")
                        .font(.caption2.bold())
                        .foregroundStyle(isMissing ? .red : .green)
                }
                Spacer()
                if isMissing {
                    Label("Behöver fyllas i", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct WizardLongField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var required = true

    private var isMissing: Bool {
        required && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.headline)
                if required {
                    Text("OBLIGATORISK")
                        .font(.caption2.bold())
                        .foregroundStyle(isMissing ? .red : .green)
                }
                Spacer()
                if isMissing {
                    Label("Behöver fyllas i", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(6)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isMissing ? Color.red.opacity(0.6) : Color.secondary.opacity(0.2))
            }
        }
    }
}

private struct WizardCheckRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.headline)
                    if !isOn {
                        Text("ÅTERSTÅR")
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
        .padding(12)
        .background(
            (isOn ? Color.green : Color.orange).opacity(0.06),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }
}

private struct WizardNotice: View {
    let symbol: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct RequirementAnswerCard: View {
    let requirement: Requirement
    @Binding var status: RequirementResponseStatus
    @Binding var responseText: String
    @Binding var evidence: String
    @Binding var owner: String

    private var isIncomplete: Bool {
        status == .unanswered
            || responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Bedömning", selection: $status) {
                    ForEach(RequirementResponseStatus.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                WizardLongField(
                    title: "Svar till beställaren",
                    placeholder: "Beskriv exakt hur kravet uppfylls.",
                    text: $responseText
                )
                WizardField(
                    title: "Bevis och bilaga",
                    placeholder: "Dokument, certifikat, produktblad eller bilagenamn",
                    text: $evidence
                )
                WizardField(
                    title: "Ansvarig",
                    placeholder: "Namn eller roll",
                    text: $owner
                )
            }
            .padding(.top, 14)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: requirement.category.symbol)
                    .foregroundStyle(isIncomplete ? .orange : .green)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(requirement.text)
                        .font(.headline)
                        .lineLimit(3)
                    Text("\(requirement.category.rawValue) · \(requirement.documentName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(status.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(isIncomplete ? .orange : .green)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(isIncomplete ? Color.orange.opacity(0.55) : Color.green.opacity(0.25))
        }
    }
}
