import AppKit
import PDFKit
import ProcurementRAGCore
import SwiftUI

enum AppSection: Hashable {
    case projects
    case overview
    case search
    case requirements
    case products
    case onlineMatches
    case responsePlan
    case document(UUID)
}

enum RequirementReviewFilter: String, CaseIterable {
    case all = "Alla"
    case pending = "Ej granskade"
    case reviewed = "Granskade"
}

struct ContentView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 340)
        } detail: {
            detail
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 1_100, minHeight: 720)
        .tint(Color(red: 0, green: 0.54, blue: 0))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                importMenu
            }
        }
        .overlay {
            if store.isWorking {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Läser och analyserar dokument…")
                            .font(.headline)
                        Text("Stora mappar kan ta en stund")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .shadow(radius: 24)
                }
            }
        }
        .alert("Åtgärden kunde inte slutföras", isPresented: errorBinding) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var sidebar: some View {
        List(selection: $store.selection) {
            Section {
                HStack(spacing: 10) {
                    AteaBrandLogo()
                        .frame(width: 86, height: 28)
                    Divider()
                        .frame(height: 24)
                    Text("upphandling")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            }

            Section("Projekt") {
                Menu {
                    ForEach(store.projects) { project in
                        Button {
                            store.switchProject(to: project.id)
                        } label: {
                            if project.id == store.activeProjectID {
                                Label(project.name, systemImage: "checkmark")
                            } else {
                                Text(project.name)
                            }
                        }
                    }
                    Divider()
                    Button(action: store.chooseAndCreateProject) {
                        Label("Nytt projekt från mapp…", systemImage: "folder.badge.plus")
                    }
                    if let project = store.activeProject {
                        Button {
                            store.promptToRenameProject(project)
                        } label: {
                            Label("Byt namn på aktivt projekt…", systemImage: "pencil")
                        }
                    }
                } label: {
                    HStack(spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(
                                    LinearGradient(
                                        colors: [.indigo, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                            Image(systemName: "briefcase.fill")
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.activeProject?.name ?? "Välj projekt")
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(store.documents.count) dokument · \(store.requirements.count) krav")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
            }

            Section {
                NavigationLabel(
                    title: "Alla projekt",
                    symbol: "square.stack.3d.up.fill",
                    tint: .indigo,
                    count: store.projects.count
                )
                .tag(AppSection.projects)

                NavigationLabel(
                    title: "Översikt",
                    symbol: "square.grid.2x2.fill",
                    tint: .blue
                )
                .tag(AppSection.overview)

                NavigationLabel(
                    title: "Sök & fråga",
                    symbol: "sparkle.magnifyingglass",
                    tint: .purple
                )
                .tag(AppSection.search)

                NavigationLabel(
                    title: "Kravlista",
                    symbol: "checklist",
                    tint: .orange,
                    count: store.requirements.count
                )
                .tag(AppSection.requirements)

                NavigationLabel(
                    title: "Produkter",
                    symbol: "shippingbox.fill",
                    tint: .green,
                    count: store.products.count
                )
                .tag(AppSection.products)

                NavigationLabel(
                    title: "Online-matchning",
                    symbol: "globe.badge.chevron.backward",
                    tint: .cyan,
                    count: store.products.count
                )
                .tag(AppSection.onlineMatches)

                NavigationLabel(
                    title: "Svarsplan",
                    symbol: "doc.badge.arrow.up",
                    tint: .indigo,
                    count: store.requirements.filter(\.isReviewed).count
                )
                .tag(AppSection.responsePlan)
            }

            Section {
                if store.documents.isEmpty {
                    Text("Inga dokument inlästa")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.documents) { document in
                        HStack(spacing: 9) {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.name)
                                    .lineLimit(1)
                                Text(documentSubtitle(document))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(AppSection.document(document.id))
                        .contextMenu {
                            Button("Visa i Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([document.sourceURL])
                            }
                            Divider()
                            Button("Ta bort från biblioteket", role: .destructive) {
                                store.removeDocument(document)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Dokument")
                    Spacer()
                    Text("\(store.documents.count)")
                        .monospacedDigit()
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Atea upphandling")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Divider()
                Button(action: store.chooseAndImportFolder) {
                    Label("Lägg till dokument", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 12)
                Button(action: store.chooseAndCreateProject) {
                    Label("Nytt projekt", systemImage: "plus.rectangle.on.folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .background(.bar)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch store.selection {
        case .projects:
            ProjectsView()
        case .overview, .none:
            OverviewView()
        case .search:
            SearchView()
        case .requirements:
            RequirementsView()
        case .products:
            ProductsView()
        case .onlineMatches:
            OnlineMatchesView()
        case .responsePlan:
            ResponsePlanView()
        case .document(let id):
            if let document = store.documents.first(where: { $0.id == id }) {
                DocumentDetailView(document: document)
            } else {
                ContentUnavailableView("Dokumentet finns inte", systemImage: "doc.questionmark")
            }
        }
    }

    private var importMenu: some View {
        Menu {
            Button(action: store.chooseAndImportFolder) {
                Label("Läs in mapp…", systemImage: "folder.badge.plus")
            }
            Button(action: store.chooseAndImportDocuments) {
                Label("Välj enskilda filer…", systemImage: "doc.badge.plus")
            }
            Divider()
            Button(action: store.chooseAndCreateProject) {
                Label("Nytt projekt från mapp…", systemImage: "plus.rectangle.on.folder")
            }
            Button(action: store.exportResponsePlan) {
                Label("Exportera svarsplan…", systemImage: "doc.badge.arrow.up")
            }
            .disabled(store.requirements.isEmpty)
        } label: {
            Label("Importera", systemImage: "plus")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }

    private func documentSubtitle(_ document: ProcurementDocument) -> String {
        let count = store.requirements.lazy.filter { $0.documentID == document.id }.count
        return "\(count) krav · \(document.pageCount) \(document.locationUnitPlural)"
    }
}

private struct AteaBrandLogo: View {
    private var logo: NSImage? {
        guard let url = Bundle.module.url(forResource: "AteaLogo", withExtension: "svg") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        Group {
            if let logo {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Atea")
            } else {
                Text("ATEA")
                    .font(.title2.bold())
                    .tracking(3)
                    .foregroundStyle(Color(red: 0.45, green: 0.49, blue: 0.52))
            }
        }
    }
}

private struct NavigationLabel: View {
    let title: String
    let symbol: String
    let tint: Color
    var count: Int?

    var body: some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(title)
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}

private struct ProjectsView: View {
                @EnvironmentObject private var store: LibraryStore

                var body: some View {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 12) {
                                    AteaBrandLogo()
                                        .frame(width: 120, height: 34)
                                    PageHeader(
                                        eyebrow: "ARBETSYTOR",
                                        title: "Upphandlingsprojekt",
                                        subtitle: "Håll dokument, krav, produkter och svarsplaner separerade"
                                    )
                                }
                                Spacer()
                                Button(action: store.chooseAndCreateProject) {
                                    Label("Nytt projekt från mapp", systemImage: "plus.rectangle.on.folder")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }

                            HStack(spacing: 12) {
                                MiniMetric(
                                    value: "\(store.projects.count)",
                                    label: "Projekt",
                                    symbol: "briefcase.fill"
                                )
                                MiniMetric(
                                    value: "\(store.projects.reduce(0) { $0 + $1.documents.count })",
                                    label: "Dokument totalt",
                                    symbol: "doc.on.doc.fill"
                                )
                                MiniMetric(
                                    value: "\(store.projects.reduce(0) { $0 + $1.requirements.count })",
                                    label: "Krav totalt",
                                    symbol: "checklist"
                                )
                            }

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 340), spacing: 16)],
                                spacing: 16
                            ) {
                                ForEach(store.projects) { project in
                                    ProjectCard(
                                        project: project,
                                        isActive: project.id == store.activeProjectID
                                    )
                                }
                            }
                        }
                        .padding(30)
                    }
                }
            }

            private struct ProjectCard: View {
                @EnvironmentObject private var store: LibraryStore
                let project: ProcurementProject
                let isActive: Bool

                private var reviewed: Int {
                    project.requirements.filter(\.isReviewed).count
                }

                var body: some View {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(
                                        LinearGradient(
                                            colors: isActive ? [.indigo, .blue] : [.gray.opacity(0.55), .gray],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)
                                Image(systemName: "briefcase.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                    .font(.title3.bold())
                                    .lineLimit(2)
                                Text(project.updatedAt, format: .relative(presentation: .named))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isActive {
                                Label("Aktivt", systemImage: "checkmark.circle.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                        }

                        HStack {
                            ProjectStat(value: project.documents.count, label: "dokument")
                            Divider().frame(height: 28)
                            ProjectStat(value: project.requirements.count, label: "krav")
                            Divider().frame(height: 28)
                            ProjectStat(value: project.products.count, label: "produkter")
                        }

                        if !project.requirements.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Granskning")
                                        .font(.caption.bold())
                                    Spacer()
                                    Text("\(reviewed)/\(project.requirements.count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: Double(reviewed), total: Double(project.requirements.count))
                                    .tint(.indigo)
                            }
                        }

                        HStack {
                            Button(isActive ? "Öppet" : "Öppna") {
                                store.switchProject(to: project.id)
                                store.selection = .overview
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isActive)

                            Button("Byt namn") {
                                store.promptToRenameProject(project)
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Menu {
                                if let folder = project.sourceFolder {
                                    Button("Visa mapp i Finder") {
                                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                                    }
                                }
                                Button("Ta bort projekt…", role: .destructive) {
                                    store.confirmAndDeleteProject(project)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }
                    .padding(18)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isActive ? Color.indigo.opacity(0.55) : Color.secondary.opacity(0.16))
                    }
                    .shadow(color: isActive ? .indigo.opacity(0.09) : .clear, radius: 12, y: 5)
                }
            }

            private struct ProjectStat: View {
                let value: Int
                let label: String

                var body: some View {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(value)")
                            .font(.title3.bold())
                            .monospacedDigit()
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

private struct OverviewView: View {
    @EnvironmentObject private var store: LibraryStore

    private var reviewedCount: Int {
        store.requirements.lazy.filter(\.isReviewed).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(
                    eyebrow: "LOKAL ANALYS",
                    title: "Din upphandling i ett ögonkast",
                    subtitle: "Dokument, krav och sökning samlat på ett ställe. All analys sker lokalt på din Mac."
                )

                if store.documents.isEmpty {
                    EmptyLibraryView()
                } else {
                    ProjectHeroCard()

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 190), spacing: 14)],
                        spacing: 14
                    ) {
                        MetricCard(
                            title: "Dokument",
                            value: "\(store.documents.count)",
                            detail: "\(store.chunks.count) sökbara avsnitt",
                            symbol: "doc.on.doc.fill",
                            tint: .blue
                        )
                        MetricCard(
                            title: "Identifierade krav",
                            value: "\(store.requirements.count)",
                            detail: "med källhänvisning",
                            symbol: "checklist",
                            tint: .orange
                        )
                        MetricCard(
                            title: "Obligatoriska",
                            value: "\(categoryCount(.mandatory))",
                            detail: "kräver särskild kontroll",
                            symbol: "exclamationmark.shield.fill",
                            tint: .red
                        )
                        MetricCard(
                            title: "Produkter",
                            value: "\(store.products.count)",
                            detail: "från prisbilagor",
                            symbol: "shippingbox.fill",
                            tint: .green
                        )
                        MetricCard(
                            title: "Granskade",
                            value: "\(reviewedCount)",
                            detail: "\(max(store.requirements.count - reviewedCount, 0)) återstår",
                            symbol: "checkmark.seal.fill",
                            tint: .green
                        )
                    }

                    OverviewDocumentPanels()
                }
            }
            .padding(30)
        }
    }

    private func categoryCount(_ category: RequirementCategory) -> Int {
        store.requirements.lazy.filter { $0.category == category }.count
    }
}

private struct ProjectHeroCard: View {
                        @EnvironmentObject private var store: LibraryStore

                        private var progress: Double {
                            guard !store.requirements.isEmpty else { return 0 }
                            return Double(store.requirements.filter(\.isReviewed).count)
                                / Double(store.requirements.count)
                        }

                        var body: some View {
                            HStack(spacing: 22) {
                                ZStack {
                                    Circle()
                                        .stroke(.white.opacity(0.2), lineWidth: 9)
                                    Circle()
                                        .trim(from: 0, to: progress)
                                        .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    VStack(spacing: 0) {
                                        Text(progress, format: .percent.precision(.fractionLength(0)))
                                            .font(.title2.bold())
                                        Text("granskat")
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                }
                                .frame(width: 106, height: 106)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("AKTIVT PROJEKT")
                                        .font(.caption.bold())
                                        .tracking(1.4)
                                        .opacity(0.75)
                                    HStack(spacing: 9) {
                                        Text(store.activeProject?.name ?? "Min upphandling")
                                            .font(.largeTitle.bold())
                                        if let project = store.activeProject {
                                            Button {
                                                store.promptToRenameProject(project)
                                            } label: {
                                                Image(systemName: "pencil.circle.fill")
                                                    .font(.title2)
                                                    .symbolRenderingMode(.hierarchical)
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(.white.opacity(0.88))
                                            .help("Byt namn på projektet")
                                        }
                                    }
                                    Text("Fortsätt granska krav, matcha produkter och bygg en komplett svarsplan med spårbara källor.")
                                        .foregroundStyle(.white.opacity(0.82))
                                        .lineLimit(2)
                                }

                                Spacer()

                                VStack(spacing: 9) {
                                    Button(action: { store.selection = .responsePlan }) {
                                        Label("Öppna svarsplan", systemImage: "arrow.right")
                                            .frame(minWidth: 145)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.white)
                                    .foregroundStyle(.indigo)

                                    Button(action: store.exportResponsePlan) {
                                        Label("Exportera DOCX + PDF", systemImage: "square.and.arrow.up")
                                            .frame(minWidth: 145)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.white)
                                    .disabled(store.requirements.isEmpty)
                                }
                            }
                            .padding(24)
                            .foregroundStyle(.white)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.20, green: 0.24, blue: 0.72), .indigo, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                            .shadow(color: .indigo.opacity(0.18), radius: 20, y: 8)
                        }
                    }

                    private struct ResponsePlanView: View {
                        @EnvironmentObject private var store: LibraryStore

                        private var reviewedCount: Int {
                            store.requirements.filter(\.isReviewed).count
                        }

                        private var progress: Double {
                            guard !store.requirements.isEmpty else { return 0 }
                            return Double(reviewedCount) / Double(store.requirements.count)
                        }

                        var body: some View {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 24) {
                                    HStack(alignment: .bottom) {
                                        PageHeader(
                                            eyebrow: "ANBUDSARBETE",
                                            title: "Svarsplan",
                                            subtitle: "Från kravgranskning till kvalitetssäkrat anbud"
                                        )
                                        Spacer()
                                        Button(action: store.exportResponsePlan) {
                                            Label("Exportera DOCX + PDF", systemImage: "square.and.arrow.up")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.large)
                                        .disabled(store.requirements.isEmpty)
                                    }

                                    HStack(spacing: 18) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("Projektets beredskap")
                                                .font(.title2.bold())
                                            Text("\(reviewedCount) av \(store.requirements.count) krav är granskade")
                                                .foregroundStyle(.secondary)
                                            ProgressView(value: progress)
                                                .tint(.indigo)
                                            Text(progress, format: .percent.precision(.fractionLength(0)))
                                                .font(.largeTitle.bold())
                                                .foregroundStyle(.indigo)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .cardStyle()

                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Exporten innehåller")
                                                .font(.title3.bold())
                                            PlanFeatureRow(symbol: "list.clipboard.fill", text: "Prioriterad arbetsordning")
                                            PlanFeatureRow(symbol: "checklist.checked", text: "Krav- och svarsmatris")
                                            PlanFeatureRow(symbol: "shippingbox.fill", text: "Produkt- och dokumentkontroll")
                                            PlanFeatureRow(symbol: "checkmark.seal.fill", text: "Slutlig kvalitetskontroll")
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .cardStyle()
                                    }

                                    SectionTitle(
                                        "Arbetsflöde",
                                        subtitle: "Fyra steg för ett komplett och spårbart svar"
                                    )

                                    LazyVGrid(
                                        columns: [GridItem(.adaptive(minimum: 230), spacing: 14)],
                                        spacing: 14
                                    ) {
                                        PlanStepCard(number: "01", title: "Kvalificera", text: "Kontrollera formkrav, datum, bilagor och ansvar.")
                                        PlanStepCard(number: "02", title: "Besvara krav", text: "Granska varje krav och koppla verifierbart bevis.")
                                        PlanStepCard(number: "03", title: "Säkra erbjudandet", text: "Verifiera produkter, priser, livscykel och leverans.")
                                        PlanStepCard(number: "04", title: "Kvalitetssäkra", text: "Genomför oberoende kontroll före inlämning.")
                                    }

                                    SectionTitle(
                                        "Status per kravtyp",
                                        subtitle: "Fokusera först på obligatoriska krav"
                                    )

                                    VStack(spacing: 0) {
                                        ForEach(RequirementCategory.allCases, id: \.self) { category in
                                            let requirements = store.requirements.filter { $0.category == category }
                                            let reviewed = requirements.filter(\.isReviewed).count
                                            HStack(spacing: 12) {
                                                Image(systemName: category.symbol)
                                                    .foregroundStyle(category.tint)
                                                    .frame(width: 28)
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(category.rawValue)
                                                        .font(.headline)
                                                    ProgressView(
                                                        value: requirements.isEmpty
                                                            ? 0
                                                            : Double(reviewed) / Double(requirements.count)
                                                    )
                                                    .tint(category.tint)
                                                }
                                                Spacer()
                                                Text("\(reviewed)/\(requirements.count)")
                                                    .font(.headline.monospacedDigit())
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(16)
                                            if category != RequirementCategory.allCases.last {
                                                Divider().padding(.leading, 56)
                                            }
                                        }
                                    }
                                    .background(.background, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14).stroke(.quaternary)
                                    }
                                }
                                .padding(30)
                            }
                        }
                    }

                    private struct PlanFeatureRow: View {
                        let symbol: String
                        let text: String

                        var body: some View {
                            Label(text, systemImage: symbol)
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }

                    private struct PlanStepCard: View {
                        let number: String
                        let title: String
                        let text: String

                        var body: some View {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(number)
                                    .font(.title.bold())
                                    .foregroundStyle(.indigo)
                                Text(title)
                                    .font(.title3.bold())
                                Text(text)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                            .cardStyle()
                        }
                    }

private struct OverviewDocumentPanels: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle("Krav per dokument", subtitle: "Se var kraven finns")
                            ForEach(store.documents.prefix(8)) { document in
                                DocumentOverviewRow(document: document)
                            }
                        }
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle("Senast identifierade krav", subtitle: "Med direkt källspårning")
                            ForEach(store.requirements.suffix(5).reversed()) { requirement in
                                CompactRequirementRow(requirement: requirement)
                            }
                            if store.requirements.isEmpty {
                                Text("Inga krav har identifierats ännu.")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 100)
                            }
                        }
                        .cardStyle()
        }
    }
}

private struct EmptyLibraryView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 110, height: 110)
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 46))
                    .foregroundStyle(.blue)
            }
            Text("Börja med en upphandlingsmapp")
                .font(.title2.bold())
            Text("Appen hittar alla PDF-, Excel-, TXT- och Markdown-filer i mappen och dess undermappar, skapar en kravlista och gör innehållet sökbart.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
            HStack {
                Button("Läs in mapp", action: store.chooseAndImportFolder)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("Välj filer", action: store.chooseAndImportDocuments)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .cardStyle()
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                Spacer()
            }
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private struct DocumentOverviewRow: View {
    @EnvironmentObject private var store: LibraryStore
    let document: ProcurementDocument

    private var count: Int {
        store.requirements.lazy.filter { $0.documentID == document.id }.count
    }

    var body: some View {
        Button {
            store.selection = .document(document.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(document.name).fontWeight(.medium).lineLimit(1)
                    Text("\(document.pageCount) \(document.locationUnitPlural)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(count) krav")
                    .font(.caption.bold())
                    .foregroundStyle(count > 0 ? .orange : .secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CompactRequirementRow: View {
    @EnvironmentObject private var store: LibraryStore
    let requirement: Requirement

    var body: some View {
        Button {
            store.selection = .requirements
            store.selectedRequirementDocumentID = requirement.documentID
            store.selectedRequirementCategory = nil
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(requirement.category.tint)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(requirement.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(requirement.sourceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SearchView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    eyebrow: "KÄLLGRUNDAD SÖKNING",
                    title: "Sök i hela upphandlingen",
                    subtitle: "Hitta exakta formuleringar eller ställ en fråga till Apple Intelligence."
                )

                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(
                            "Exempel: Vilka krav finns på informationssäkerhet?",
                            text: $store.query
                        )
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .onSubmit(store.search)
                        if !store.query.isEmpty {
                            Button {
                                store.query = ""
                                store.searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(.background, in: RoundedRectangle(cornerRadius: 11))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(.quaternary, lineWidth: 1)
                    }

                    Button("Sök", action: store.search)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Button(action: store.generateAnswer) {
                        Label("Fråga AI", systemImage: "apple.intelligence")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(30)

            Divider()

            if store.documents.isEmpty {
                ContentUnavailableView(
                    "Inga dokument att söka i",
                    systemImage: "folder.badge.plus",
                    description: Text("Läs först in en upphandlingsmapp.")
                )
            } else if store.searchResults.isEmpty && store.generatedAnswer.isEmpty {
                SearchReadyView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if !store.generatedAnswer.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Svar från Apple Intelligence", systemImage: "apple.intelligence")
                                    .font(.headline)
                                    .foregroundStyle(.purple)
                                Text(store.generatedAnswer)
                                    .font(.body)
                                    .lineSpacing(4)
                                    .textSelection(.enabled)
                            }
                            .padding(20)
                            .background(
                                LinearGradient(
                                    colors: [.purple.opacity(0.1), .blue.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 15)
                            )
                        }

                        HStack {
                            SectionTitle(
                                "Källor",
                                subtitle: "\(store.searchResults.count) relevanta avsnitt"
                            )
                            Spacer()
                        }

                        ForEach(store.searchResults) { result in
                            SourceCard(result: result)
                        }
                    }
                    .padding(30)
                }
            }
        }
    }
}

private struct SearchReadyView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Redo att söka")
                .font(.title2.bold())
            Text("\(store.documents.count) dokument och \(store.chunks.count) textavsnitt är indexerade.")
                .foregroundStyle(.secondary)
            HStack {
                SuggestionButton(text: "Obligatoriska krav")
                SuggestionButton(text: "Informationssäkerhet")
                SuggestionButton(text: "Sista svarsdatum")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SuggestionButton: View {
    @EnvironmentObject private var store: LibraryStore
    let text: String

    var body: some View {
        Button(text) {
            store.query = text
            store.search()
        }
        .buttonStyle(.bordered)
    }
}

private struct SourceCard: View {
    @EnvironmentObject private var store: LibraryStore
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    store.showSource(result.chunk)
                } label: {
                    Label(result.chunk.documentName, systemImage: "doc.text.fill")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                if let page = result.chunk.page {
                    SourcePill(
                        text: locationLabel(documentName: result.chunk.documentName, page: page),
                        symbol: "doc.text"
                    )
                }
                Spacer()
                Text("Relevans \(result.score.formatted(.number.precision(.fractionLength(2))))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(result.chunk.text)
                .lineLimit(9)
                .lineSpacing(3)
                .textSelection(.enabled)
            HStack {
                Button {
                    store.showSource(result.chunk)
                } label: {
                    Label(
                        result.chunk.page == nil ? "Visa källavsnitt" : "Öppna på rätt plats",
                        systemImage: "arrow.up.forward.square"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Spacer()
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct RequirementsView: View {
    @EnvironmentObject private var store: LibraryStore

    private var visibleRequirements: [Requirement] {
        store.requirements.filter { requirement in
            let categoryMatches = store.selectedRequirementCategory.map {
                requirement.category == $0
            } ?? true
            let documentMatches = store.selectedRequirementDocumentID.map {
                requirement.documentID == $0
            } ?? true
            let reviewMatches: Bool = switch store.requirementReviewFilter {
            case .all: true
            case .pending: !requirement.isReviewed
            case .reviewed: requirement.isReviewed
            }
            let query = store.requirementFilter.trimmingCharacters(in: .whitespacesAndNewlines)
            let textMatches = query.isEmpty
                || requirement.text.localizedCaseInsensitiveContains(query)
                || requirement.documentName.localizedCaseInsensitiveContains(query)
            return categoryMatches && documentMatches && reviewMatches && textMatches
        }
    }

    private var groupedRequirements: [(ProcurementDocument, [Requirement])] {
        store.documents.compactMap { document in
            let matching = visibleRequirements.filter { $0.documentID == document.id }
            return matching.isEmpty ? nil : (document, matching)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom) {
                    PageHeader(
                        eyebrow: "SPÅRBARA KRAV",
                        title: "Kravlista",
                        subtitle: "\(visibleRequirements.count) av \(store.requirements.count) krav visas"
                    )
                    Spacer()
                    Menu {
                        Button {
                            store.summarizeRequirementsIndividually(visibleRequirements)
                        } label: {
                            Label(
                                "Utveckla alla synliga krav",
                                systemImage: "text.badge.sparkles"
                            )
                        }
                        Button(action: store.summarizeRequirements) {
                            Label("Sammanställ hela kravlistan", systemImage: "doc.text")
                        }
                    } label: {
                        Label("Apple Intelligence", systemImage: "apple.intelligence")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.requirements.isEmpty)
                }

                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Filtrera krav eller dokument…", text: $store.requirementFilter)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8).stroke(.quaternary)
                    }

                    Picker("Kategori", selection: $store.selectedRequirementCategory) {
                        Text("Alla kategorier").tag(nil as RequirementCategory?)
                        ForEach(RequirementCategory.allCases, id: \.self) {
                            Text($0.shortName).tag($0 as RequirementCategory?)
                        }
                    }
                    .frame(width: 180)

                    Picker("Dokument", selection: $store.selectedRequirementDocumentID) {
                        Text("Alla dokument").tag(nil as UUID?)
                        ForEach(store.documents) {
                            Text($0.name).tag($0.id as UUID?)
                        }
                    }
                    .frame(width: 210)

                    Picker("Status", selection: $store.requirementReviewFilter) {
                        ForEach(RequirementReviewFilter.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .frame(width: 135)
                }
            }
            .padding(30)

            Divider()

            if store.requirements.isEmpty {
                ContentUnavailableView(
                    "Inga krav identifierade",
                    systemImage: "checklist",
                    description: Text("Läs in en upphandlingsmapp för att skapa kravlistan.")
                )
            } else if visibleRequirements.isEmpty {
                ContentUnavailableView(
                    "Inga matchande krav",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Ändra sökningen eller filtren.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if !store.requirementSummary.isEmpty {
                            AISummaryCard(text: store.requirementSummary)
                        }

                        ForEach(groupedRequirements, id: \.0.id) { document, requirements in
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    store.selection = .document(document.id)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundStyle(.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(document.name)
                                                .font(.title3.bold())
                                            Text("\(requirements.count) krav i dokumentet")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("Visa dokument")
                                            .font(.caption.bold())
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                ForEach(requirements) { requirement in
                                    RequirementCard(requirement: requirement)
                                }
                            }
                        }
                    }
                    .padding(30)
                }
            }
        }
    }
}

private struct ProductsView: View {
    @EnvironmentObject private var store: LibraryStore

    private var visibleProducts: [ProcurementProduct] {
        let query = store.productFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.products }
        return store.products.filter { product in
            product.name.localizedCaseInsensitiveContains(query)
                || product.identifier?.localizedCaseInsensitiveContains(query) == true
                || product.documentName.localizedCaseInsensitiveContains(query)
                || product.requirements.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
                || product.details.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
        }
    }

    private var groupedProducts: [(String, [ProcurementProduct])] {
        Dictionary(grouping: visibleProducts, by: \.documentName)
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "PRIS- OCH PRODUKTBILAGOR",
                    title: "Produkter",
                    subtitle: "\(visibleProducts.count) produkter med specifikationer och krav"
                )

                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Produktunika uppgifter visas här. Gemensamma säkerhets-, avtals- och leveranskrav finns i kravlistan.")
                        .font(.callout)
                    Spacer()
                    Button("Öppna kravlistan") {
                        store.selection = .requirements
                    }
                }
                .padding(12)
                .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(
                        "Sök produkt, artikelnummer, krav eller dokument…",
                        text: $store.productFilter
                    )
                    .textFieldStyle(.plain)
                    if !store.productFilter.isEmpty {
                        Button {
                            store.productFilter = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 13)
                .frame(height: 40)
                .background(.background, in: RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9).stroke(.quaternary)
                }
            }
            .padding(30)

            Divider()

            if store.products.isEmpty {
                ContentUnavailableView(
                    "Inga produkter identifierade",
                    systemImage: "shippingbox",
                    description: Text("Läs in en prisbilaga i XLS- eller XLSX-format. Kolumner för produkt, specifikation och krav identifieras automatiskt.")
                )
            } else if visibleProducts.isEmpty {
                ContentUnavailableView.search(text: store.productFilter)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        ForEach(groupedProducts, id: \.0) { documentName, products in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "tablecells.fill")
                                        .foregroundStyle(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(documentName)
                                            .font(.title3.bold())
                                        Text("\(products.count) produkter")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let document = store.documents.first(where: {
                                        $0.name == documentName
                                    }) {
                                        Button("Visa dokument") {
                                            store.selection = .document(document.id)
                                        }
                                    }
                                }

                                ForEach(products) { product in
                                    ProductCard(product: product)
                                }
                            }
                        }
                    }
                    .padding(30)
                }
            }
        }
    }
}

private struct OnlineMatchesView: View {
    @EnvironmentObject private var store: LibraryStore

    private var productSearchGroups: [ProductSearchGroup] {
        let groups = Dictionary(grouping: store.products) {
            ProductSearchGroup.normalizedName($0.name)
        }
        return groups.compactMap { _, products in
            guard let first = products.first else { return nil }
            return ProductSearchGroup(product: first, occurrences: products)
        }
        .filter { group in
            store.onlineProductFilter.isEmpty
                || group.name.localizedCaseInsensitiveContains(store.onlineProductFilter)
                || group.category.localizedCaseInsensitiveContains(store.onlineProductFilter)
                || group.requirements.contains {
                    $0.localizedCaseInsensitiveContains(store.onlineProductFilter)
                }
        }
        .sorted {
            if $0.category != $1.category {
                return $0.category.localizedStandardCompare($1.category) == .orderedAscending
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var groupedSearches: [(String, [ProductSearchGroup])] {
        Dictionary(grouping: productSearchGroups, by: \.category)
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) {
                    PageHeader(
                        eyebrow: "VERIFIERAD ONLINE-RESEARCH",
                        title: "Produkter som kan passa",
                        subtitle: "Matchade mot produktkraven med spårbara onlinekällor"
                    )
                    Spacer()
                    Button {
                        openBroaderSearch()
                    } label: {
                        Label("Sök fler online", systemImage: "safari")
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Källor och begränsningar")
                            .font(.headline)
                        Text("Matchningen använder officiella tillverkarkällor. Ett MIL-STD-påstående innebär inte automatiskt att varje enskild testmetod i kravbilagan är uppfylld; detta måste styrkas av leverantören. Organisatoriska informationssäkerhetskrav kan inte uppfyllas av telefonen ensam.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))

                HStack(spacing: 12) {
                    MiniMetric(
                        value: "\(store.products.count)/\(store.products.count)",
                        label: "Produktrader täckta",
                        symbol: "shippingbox"
                    )
                    MiniMetric(
                        value: "\(ProductSearchGroup.uniqueCount(in: store.products))",
                        label: "Unika sökbehov",
                        symbol: "rectangle.3.group"
                    )
                    MiniMetric(
                        value: "\(VerifiedPhoneCandidate.all.count + AteaHeadsetCandidate.all.count)",
                        label: "Källverifierade",
                        symbol: "checkmark.seal"
                    )
                    MiniMetric(
                        value: "\(VerifiedPhoneCandidate.all.filter { $0.assessment == .strong }.count + AteaHeadsetCandidate.all.filter(\.isStrong).count)",
                        label: "Starka matchningar",
                        symbol: "checkmark.seal"
                    )
                }

                SectionTitle(
                    "Samtliga produkter och tjänster",
                    subtitle: "Alla \(store.products.count) rader från prisbilagan · identiska behov är grupperade"
                )

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        "Filtrera produkt, kategori eller krav…",
                        text: $store.onlineProductFilter
                    )
                    .textFieldStyle(.plain)
                    if !store.onlineProductFilter.isEmpty {
                        Button {
                            store.onlineProductFilter = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 13)
                .frame(height: 40)
                .background(.background, in: RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9).stroke(.quaternary)
                }

                if groupedSearches.isEmpty {
                    ContentUnavailableView.search(text: store.onlineProductFilter)
                } else {
                    ForEach(groupedSearches, id: \.0) { category, groups in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(category, systemImage: ProductSearchGroup.symbol(for: category))
                                    .font(.title3.bold())
                                Spacer()
                                Text("\(groups.reduce(0) { $0 + $1.occurrences.count }) rader")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(groups) { group in
                                ProductSearchCard(group: group)
                            }
                        }
                    }
                }

                SectionTitle(
                    "Källverifierat · Atea eShop",
                    subtitle: "Kandidater från det angivna Atea-filtret, jämförda mot variant 1 och 2"
                )

                ForEach(AteaHeadsetCandidate.all) { candidate in
                    AteaHeadsetCard(candidate: candidate)
                }

                SectionTitle(
                    "Mobiltelefoner",
                    subtitle: "Verifierade mot robusthet, säkerhet och företagshantering"
                )

                ForEach(VerifiedPhoneCandidate.all) { candidate in
                    CandidateCard(candidate: candidate)
                }

                Text("De åtta kandidaterna nedan är källverifierade. Övriga poster ovan är kompletta sökunderlag, inte automatiskt godkända produkter. Senast verifierad 28 september 2026. Kontrollera alltid aktuell svensk modell, lagerstatus, avtalspris och samtliga krav före offert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(30)
        }
    }

    private func openBroaderSearch() {
        let query = """
        enterprise smartphone IP68 MIL-STD-810H 5G MDM security updates \
        rugged mobile phone Sweden
        """
        var components = URLComponents(string: "https://duckduckgo.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        if let url = components?.url {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct ProductSearchCard: View {
                let group: ProductSearchGroup

                var body: some View {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(.headline)
                                Text(group.referenceText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(group.occurrences.count == 1 ? "1 rad" : "\(group.occurrences.count) rader")
                                .font(.caption.bold())
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(.cyan.opacity(0.1), in: Capsule())
                                .foregroundStyle(.cyan)
                        }

                        if !group.requirements.isEmpty {
                            DisclosureGroup(
                                content: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(group.requirements, id: \.self) { requirement in
                                            Label {
                                                Text(requirement.trimmingCharacters(in: CharacterSet(charactersIn: "• ")))
                                                    .fixedSize(horizontal: false, vertical: true)
                                            } icon: {
                                                Image(systemName: "checkmark.circle")
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.top, 8)
                                },
                                label: {
                                    Text("\(group.requirements.count) krav ingår i sökningen")
                                        .font(.callout.bold())
                                }
                            )
                        } else {
                            Label(
                                group.isService ? "Tjänst – begär leverantörsbeskrivning och pris" : "Namngiven produkt – kontrollera exakt modell och företagsversion",
                                systemImage: group.isService ? "person.badge.clock" : "shippingbox"
                            )
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }

                        HStack {
                            Link(destination: group.ateaSearchURL) {
                                Label("Sök hos Atea", systemImage: "cart")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Link(destination: group.webSearchURL) {
                                Label("Sök på webben", systemImage: "safari")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Link(destination: group.manufacturerSearchURL) {
                                Label("Tillverkarkällor", systemImage: "checkmark.shield")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Spacer()

                            Text("Sökning klar")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13).stroke(.quaternary)
                    }
                }
            }

            private struct ProductSearchGroup: Identifiable {
                let product: ProcurementProduct
                let occurrences: [ProcurementProduct]

                var id: String { Self.normalizedName(name) }
                var name: String { product.name }
                var requirements: [String] { product.requirements }

                var category: String {
                    let value = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    if value.contains("headset") { return "Headset" }
                    if value.contains("laddare") { return "Laddare" }
                    if value.contains("laddkabel") { return "Laddkablar" }
                    if value.contains("skarmskydd") { return "Skärmskydd" }
                    if value.contains("mobilskal") || value.contains("mobilfodral") { return "Skal och fodral" }
                    if value.contains("iphone") || value.contains("galaxy") { return "Mobiltelefoner och support" }
                    return "Tjänster och övrigt"
                }

                var isService: Bool {
                    category == "Tjänster och övrigt"
                        || name.localizedCaseInsensitiveContains("AppleCare")
                        || name.localizedCaseInsensitiveContains("tjänst")
                }

                var referenceText: String {
                    let sheets = Set(occurrences.map(\.sheetName)).sorted()
                    let sheetText = sheets.count <= 3
                        ? sheets.joined(separator: ", ")
                        : "\(sheets.count) kalkylblad"
                    return "\(product.documentName) · \(sheetText)"
                }

                private var searchQuery: String {
                    let requirementTerms = requirements
                        .prefix(4)
                        .map {
                            $0.trimmingCharacters(in: CharacterSet(charactersIn: "• "))
                        }
                        .joined(separator: " ")
                    return "\(name) \(requirementTerms)"
                }

                var ateaSearchURL: URL {
                    searchURL(
                        base: "https://www.google.com/search",
                        query: "site:atea.se/eshop/product/ \(searchQuery)"
                    )
                }

                var webSearchURL: URL {
                    searchURL(base: "https://www.google.com/search", query: "\(searchQuery) Sverige")
                }

                var manufacturerSearchURL: URL {
                    searchURL(
                        base: "https://www.google.com/search",
                        query: "\(searchQuery) official specifications manufacturer"
                    )
                }

                private func searchURL(base: String, query: String) -> URL {
                    var components = URLComponents(string: base)!
                    components.queryItems = [URLQueryItem(name: "q", value: query)]
                    return components.url!
                }

                static func normalizedName(_ name: String) -> String {
                    name
                        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                        .replacingOccurrences(of: ":", with: "")
                        .replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: "varian 1", with: "variant 1")
                        .split(whereSeparator: \.isWhitespace)
                        .joined(separator: " ")
                }

                static func uniqueCount(in products: [ProcurementProduct]) -> Int {
                    Set(products.map { normalizedName($0.name) }).count
                }

                static func symbol(for category: String) -> String {
                    switch category {
                    case "Headset": "headphones"
                    case "Laddare": "powerplug.fill"
                    case "Laddkablar": "cable.connector"
                    case "Skärmskydd": "rectangle.inset.filled"
                    case "Skal och fodral": "iphone.gen3"
                    case "Mobiltelefoner och support": "apps.iphone"
                    default: "wrench.and.screwdriver"
                    }
                }
}

private struct AteaHeadsetCard: View {
    let candidate: AteaHeadsetCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.target.uppercased())
                        .font(.caption.bold())
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text(candidate.name)
                        .font(.title3.bold())
                }
                Spacer()
                Label(candidate.status, systemImage: candidate.isStrong ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(candidate.isStrong ? .green : .orange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        (candidate.isStrong ? Color.green : Color.orange).opacity(0.11),
                        in: Capsule()
                    )
            }

            HStack(alignment: .top, spacing: 18) {
                CandidateEvidenceColumn(
                    title: "Matchar",
                    symbol: "checkmark.circle.fill",
                    tint: .green,
                    values: candidate.matches
                )
                CandidateEvidenceColumn(
                    title: "Verifiera före offert",
                    symbol: "questionmark.circle.fill",
                    tint: .orange,
                    values: candidate.verify
                )
            }

            HStack {
                Link(destination: candidate.ateaURL) {
                    Label("Visa hos Atea", systemImage: "cart")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                if let manufacturerURL = candidate.manufacturerURL {
                    Link(destination: manufacturerURL) {
                        Label("Tillverkarspecifikation", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Spacer()
                Text("Atea produkt-ID \(candidate.ateaProductID)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(candidate.isStrong ? .green : .orange)
            .frame(width: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(.quaternary)
        }
    }
}

private struct AteaHeadsetCandidate: Identifiable {
    let name: String
    let target: String
    let status: String
    let isStrong: Bool
    let matches: [String]
    let verify: [String]
    let ateaProductID: String
    let ateaURL: URL
    let manufacturerURL: URL?
    var id: String { ateaProductID }

    static let all: [AteaHeadsetCandidate] = [
        AteaHeadsetCandidate(
            name: "ASUS ROG Cetra II Core",
            target: "Trådat headset · Variant 2",
            status: "Stark kandidat",
            isStrong: true,
            matches: [
                "In-ear med silikonproppar i tre storlekar och extra skumproppar",
                "3,5 mm fyrpolig kontakt och 1,25 m kabel",
                "Inbyggd rundupptagande mikrofon",
                "Kabelkontroller för volym samt uppspelning",
                "Passiv ljudisolering genom tät in-ear-passform"
            ],
            verify: [
                "Mikrofonens brusreducering behöver styrkas uttryckligen i offert",
                "Modellen saknar aktiv brusreducering; kravet avser främst högupplöst ljud och brusreducerande egenskaper"
            ],
            ateaProductID: "2601156",
            ateaURL: URL(string: "https://www.atea.se/eshop/product/asus-rog-cetra-ii-core-horlurar-med-mikrofon-inuti-orat-kabelansluten-3-5-mm-kontakt-svart/?prodid=2601156")!,
            manufacturerURL: URL(string: "https://rog.asus.com/uk/headsets-audio/in-ear-headphone/rog-cetra-ii-core-model/")
        ),
        AteaHeadsetCandidate(
            name: "Apple EarPods med 3,5 mm kontakt",
            target: "Trådat headset · Variant 1",
            status: "Lovande kandidat",
            isStrong: false,
            matches: [
                "Öronknoppsdesign som vilar i ytterörat",
                "3,5 mm kontakt och inbyggd mikrofon",
                "Kabelkontroll för volym och uppspelning",
                "Utpekad formfaktor i kravets eget exempel"
            ],
            verify: [
                "Atea-underlaget behöver styrka kabelns exakta längd om minst 0,8 m",
                "Bekräfta lagerstatus och exakt artikel MWU52ZM/A i offert"
            ],
            ateaProductID: "2476167",
            ateaURL: URL(string: "https://www.atea.se/eshop/product/apple-earpods-horlurar-med-mikrofon-oronknopp-kabelansluten-3-5-mm-kontakt/?prodid=2476167")!,
            manufacturerURL: URL(string: "https://www.apple.com/shop/product/MWU53AM/A/earpods-35mm-headphone-plug")
        ),
        AteaHeadsetCandidate(
            name: "Logitech Zone Wired Earbuds",
            target: "Trådat headset · Variant 2",
            status: "Behöver verifieras",
            isStrong: false,
            matches: [
                "In-ear, 3,5 mm och ljudisolerande konstruktion",
                "Headset med mikrofon för professionella samtal",
                "Certifierad för Microsoft Teams"
            ],
            verify: [
                "Kontrollera öronproppar i flera storlekar",
                "Styrk kabel minst 0,8 m och mikrofonens brusreducering",
                "Verifiera volym- och uppspelningskontroller på 3,5 mm-versionen"
            ],
            ateaProductID: "2230265",
            ateaURL: URL(string: "https://www.atea.se/eshop/product/logitech-zone-wired-earbuds-headset-inuti-orat-kabelansluten-3-5-mm-kontakt-ljudisolerande-grafit-certifierad-for-microsoft-teams/?prodid=2230265")!,
            manufacturerURL: nil
        ),
        AteaHeadsetCandidate(
            name: "HyperX Cloud Earbuds II",
            target: "Trådat headset · Variant 2",
            status: "Behöver verifieras",
            isStrong: false,
            matches: [
                "In-ear, kabelansluten och 3,5 mm kontakt",
                "Inbyggd mikrofon",
                "Utbytbara öronproppar finns för passform"
            ],
            verify: [
                "Styrk mikrofon med brusreducerande egenskaper",
                "Kontrollera kabelns längd och fullständiga kabelkontroller",
                "Bedöm om ljudisolering och ljudkvalitet når upphandlingskravet"
            ],
            ateaProductID: "2545919",
            ateaURL: URL(string: "https://www.atea.se/eshop/product/hyperx-cloud-earbuds-ii-horlurar-med-mikrofon-inuti-orat-kabelansluten-3-5-mm-kontakt-rod/?prodid=2545919")!,
            manufacturerURL: nil
        )
    ]
}

private struct CandidateCard: View {
    let candidate: VerifiedPhoneCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(candidate.manufacturer.uppercased())
                        .font(.caption.bold())
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text(candidate.name)
                        .font(.title2.bold())
                }
                Spacer()
                Label(candidate.assessment.title, systemImage: candidate.assessment.symbol)
                    .font(.caption.bold())
                    .foregroundStyle(candidate.assessment.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(candidate.assessment.tint.opacity(0.11), in: Capsule())
            }

            Text(candidate.summary)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            HStack(alignment: .top, spacing: 18) {
                CandidateEvidenceColumn(
                    title: "Verifierad matchning",
                    symbol: "checkmark.circle.fill",
                    tint: .green,
                    values: candidate.evidence
                )
                CandidateEvidenceColumn(
                    title: "Måste kontrolleras",
                    symbol: "exclamationmark.triangle.fill",
                    tint: .orange,
                    values: candidate.gaps
                )
            }

            Divider()

            HStack {
                Text("Officiella källor")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(candidate.sources) { source in
                    Link(destination: source.url) {
                        Label(source.title, systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Spacer()
                Button {
                    openProductSearch(candidate)
                } label: {
                    Label("Sök återförsäljare", systemImage: "cart")
                }
                .controlSize(.small)
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 15))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 15,
                bottomLeadingRadius: 15,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(candidate.assessment.tint)
            .frame(width: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15).stroke(.quaternary)
        }
    }

    private func openProductSearch(_ candidate: VerifiedPhoneCandidate) {
        var components = URLComponents(string: "https://duckduckgo.com/")
        components?.queryItems = [
            URLQueryItem(
                name: "q",
                value: "\(candidate.name) Enterprise Edition Sverige återförsäljare"
            )
        ]
        if let url = components?.url {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct CandidateEvidenceColumn: View {
    let title: String
    let symbol: String
    let tint: Color
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(tint)
            ForEach(values, id: \.self) { value in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: symbol)
                        .foregroundStyle(tint)
                        .padding(.top, 2)
                    Text(value)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct VerifiedPhoneCandidate: Identifiable {
    struct Source: Identifiable {
        let title: String
        let url: URL
        var id: URL { url }
    }

    enum Assessment: Equatable {
        case strong
        case partial

        var title: String {
            switch self {
            case .strong: "Stark kandidat"
            case .partial: "Delvis match"
            }
        }

        var symbol: String {
            switch self {
            case .strong: "checkmark.seal.fill"
            case .partial: "circle.lefthalf.filled"
            }
        }

        var tint: Color {
            switch self {
            case .strong: .green
            case .partial: .orange
            }
        }
    }

    let name: String
    let manufacturer: String
    let assessment: Assessment
    let summary: String
    let evidence: [String]
    let gaps: [String]
    let sources: [Source]
    var id: String { name }

    static let all: [VerifiedPhoneCandidate] = [
        VerifiedPhoneCandidate(
            name: "Galaxy XCover7 Pro Enterprise Edition",
            manufacturer: "Samsung",
            assessment: .strong,
            summary: "Robust företagsmobil som ligger närmast kravbilagans inriktning på tålighet, säkerhet och lång förvaltning.",
            evidence: [
                "MIL-STD-810H och IP68 enligt Samsung",
                "Knox Vault och Knox Suite för företagshantering",
                "Upp till sju års säkerhetsuppdateringar",
                "5G, Wi-Fi 6E och utbytbart 4 350 mAh-batteri"
            ],
            gaps: [
                "Begär testrapport som mappar varje obligatorisk MIL-STD-metod",
                "Verifiera svensk Enterprise Edition, garantitid och livscykel",
                "Leverantörens incident-, lagrings- och revisionsrutiner bedöms separat"
            ],
            sources: [
                Source(
                    title: "Samsung Business",
                    url: URL(string: "https://www.samsung.com/uk/business/smartphones/xcover/galaxy-xcover7-pro-black-128gb-sm-g766bzkdeeb/")!
                ),
                Source(
                    title: "Samsung Newsroom",
                    url: URL(string: "https://news.samsung.com/global/samsung-introduces-galaxy-xcover7-pro-and-galaxy-tab-active5-pro-ruggedized-devices-for-frontline-excellence")!
                )
            ]
        ),
        VerifiedPhoneCandidate(
            name: "Galaxy XCover7 Enterprise Edition",
            manufacturer: "Samsung",
            assessment: .strong,
            summary: "Robust och hanterbar 5G-modell med officiellt stöd för MIL-STD-810H, IP68 och Samsung Knox.",
            evidence: [
                "MIL-STD-810H och falltest upp till 1,5 meter enligt Samsung",
                "IP68 mot vatten och damm",
                "Samsung Knox Suite och Knox Vault",
                "5G och utbytbart 4 050 mAh-batteri"
            ],
            gaps: [
                "Verifiera exakt vilka MIL-STD-metoder den offererade modellen har testats mot",
                "Kontrollera återstående supporttid vid avtalsstart",
                "Styrk krav på oberoende säkerhetsgranskning separat"
            ],
            sources: [
                Source(
                    title: "Samsung Business",
                    url: URL(string: "https://www.samsung.com/uk/business/smartphones/xcover/galaxy-xcover7-black-128gb-sm-g556bzkdeeb/")!
                )
            ]
        ),
        VerifiedPhoneCandidate(
            name: "iPhone 17",
            manufacturer: "Apple",
            assessment: .partial,
            summary: "Stark säkerhets- och förvaltningsplattform med IP68, men saknar verifierat MIL-STD-underlag i Apples tekniska specifikation.",
            evidence: [
                "IP68 enligt IEC 60529",
                "Secure Enclave, Face ID och hårdvarubaserat nyckelskydd",
                "Apple Business Manager och MDM-stöd",
                "Löpande säkerhetsuppdateringar för iOS"
            ],
            gaps: [
                "Ingen officiell MIL-STD-810H-certifiering identifierad",
                "Krav på obligatoriska stöt-, temperatur- och vibrationstester måste styrkas separat",
                "Leverantörens organisatoriska säkerhetskrav kvarstår"
            ],
            sources: [
                Source(
                    title: "Apple teknisk specifikation",
                    url: URL(string: "https://support.apple.com/en-us/125089")!
                ),
                Source(
                    title: "Apple Platform Security",
                    url: URL(string: "https://support.apple.com/guide/security/welcome/web")!
                )
            ]
        ),
        VerifiedPhoneCandidate(
            name: "iPhone 17e",
            manufacturer: "Apple",
            assessment: .partial,
            summary: "Företagshanterbar iPhone med IP68 och Apples säkerhetsplattform, men utan verifierad militär tålighetsstandard.",
            evidence: [
                "IP68 enligt Apples tekniska specifikation",
                "Secure Enclave, Face ID och krypterat nyckelskydd",
                "Stöd för Apple Business Manager och MDM",
                "5G och lång iOS-förvaltning"
            ],
            gaps: [
                "Ingen officiell MIL-STD-810H-certifiering identifierad",
                "Verifiera kravbilagans miljö- och stöttester genom separat dokumentation",
                "Kontrollera svensk modell, garantitjänst och supportperiod"
            ],
            sources: [
                Source(
                    title: "Apple teknisk specifikation",
                    url: URL(string: "https://support.apple.com/en-us/126470")!
                ),
                Source(
                    title: "Apple Deployment",
                    url: URL(string: "https://support.apple.com/guide/deployment/welcome/web")!
                )
            ]
        )
    ]
}

private struct ProductCard: View {
    let product: ProcurementProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                        .textSelection(.enabled)
                    if let identifier = product.identifier {
                        Text("Position / referens: \(identifier)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                Spacer()
                SourcePill(
                    text: "\(product.sheetName) · rad \(product.row)",
                    symbol: "tablecells"
                )
            }

            if !product.requirements.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Krav och specifikation", systemImage: "checklist")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    ForEach(product.requirements, id: \.self) { requirement in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.orange)
                                .padding(.top, 1)
                            Text(requirement)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(12)
                .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Label(
                    "Inga produktunika krav angavs på denna rad i prisbilagan",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if !product.details.isEmpty {
                FlowDetails(values: product.details)
            }
        }
        .padding(17)
        .background(.background, in: RoundedRectangle(cornerRadius: 13))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 13,
                bottomLeadingRadius: 13,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(.green)
            .frame(width: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13).stroke(.quaternary)
        }
    }
}

private struct FlowDetails: View {
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(values, id: \.self) { value in
                Text(value)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct RequirementCard: View {
    @EnvironmentObject private var store: LibraryStore
    let requirement: Requirement

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                store.toggleReviewed(requirement)
            } label: {
                Image(systemName: requirement.isReviewed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(requirement.isReviewed ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(requirement.isReviewed ? "Markera som ej granskad" : "Markera som granskad")

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    CategoryBadge(category: requirement.category)
                    SourcePill(
                        text: requirement.page.map {
                            locationLabel(documentName: requirement.documentName, page: $0)
                        } ?? "Ingen plats",
                        symbol: "text.page"
                    )
                    if requirement.isReviewed {
                        SourcePill(text: "Granskad", symbol: "checkmark")
                    }
                    Spacer()
                }
                Text(requirement.text)
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)

                if let summary = requirement.aiSummary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Apple Intelligence-förklaring", systemImage: "apple.intelligence")
                                .font(.caption.bold())
                                .foregroundStyle(.purple)
                            Spacer()
                            Menu {
                                Button("Skapa ny sammanfattning") {
                                    store.summarizeRequirement(requirement)
                                }
                                Button("Ta bort sammanfattning", role: .destructive) {
                                    store.clearRequirementSummary(requirement)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        }
                        if let attributed = try? AttributedString(
                            markdown: summary,
                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                        ) {
                            Text(attributed)
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        } else {
                            Text(summary)
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(13)
                    .background(
                        LinearGradient(
                            colors: [.purple.opacity(0.09), .blue.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                } else {
                    Button {
                        store.summarizeRequirement(requirement)
                    } label: {
                        if store.summarizingRequirementIDs.contains(requirement.id) {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Utvecklar kravet…")
                            }
                        } else {
                            Label(
                                "Utveckla kravet med Apple Intelligence",
                                systemImage: "apple.intelligence"
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    .disabled(store.summarizingRequirementIDs.contains(requirement.id))
                }

                Button {
                    store.showRequirementSource(requirement)
                } label: {
                    Label("Öppna källan · \(requirement.sourceLabel)", systemImage: "arrow.up.forward.square")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 13))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 13,
                bottomLeadingRadius: 13,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(requirement.category.tint)
            .frame(width: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct CategoryBadge: View {
    let category: RequirementCategory

    var body: some View {
        Label(category.shortName, systemImage: category.symbol)
            .font(.caption.bold())
            .foregroundStyle(category.tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(category.tint.opacity(0.11), in: Capsule())
    }
}

private struct SourcePill: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.7), in: Capsule())
    }
}

private struct AISummaryCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI-sammanställning", systemImage: "apple.intelligence")
                .font(.headline)
                .foregroundStyle(.purple)
            Text(text)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
        .padding(20)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
    }
}

private struct DocumentDetailView: View {
    @EnvironmentObject private var store: LibraryStore
    let document: ProcurementDocument

    private var documentChunks: [DocumentChunk] {
        store.chunks.filter { $0.documentID == document.id }
    }

    private var documentRequirements: [Requirement] {
        store.requirements.filter { $0.documentID == document.id }
    }

    private var documentProducts: [ProcurementProduct] {
        store.products.filter { $0.documentID == document.id }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    PageHeader(
                        eyebrow: "DOKUMENT",
                        title: document.name,
                        subtitle: document.sourceURL.deletingLastPathComponent().path
                    )
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(document.sourceURL)
                    } label: {
                        Label("Öppna original", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 12) {
                    MiniMetric(
                        value: "\(document.pageCount)",
                        label: document.locationUnitPlural.capitalized,
                        symbol: document.isSpreadsheet ? "tablecells" : "doc.text"
                    )
                    MiniMetric(value: "\(documentRequirements.count)", label: "Krav", symbol: "checklist")
                    MiniMetric(
                        value: "\(documentProducts.count)",
                        label: "Produkter",
                        symbol: "shippingbox"
                    )
                    MiniMetric(value: "\(documentChunks.count)", label: "Textavsnitt", symbol: "square.stack.3d.up")
                    MiniMetric(
                        value: "\(documentRequirements.filter(\.isReviewed).count)",
                        label: "Granskade",
                        symbol: "checkmark.seal"
                    )
                }

                if document.sourceURL.pathExtension.lowercased() == "pdf",
                   let page = store.selectedDocumentPage {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionTitle(
                                "Källträff",
                                subtitle: "Originaldokument · sida \(page)"
                            )
                            Spacer()
                            Button {
                                NSWorkspace.shared.open(document.sourceURL)
                            } label: {
                                Label("Öppna i Förhandsvisning", systemImage: "arrow.up.forward.app")
                            }
                        }
                        PDFSourceView(url: document.sourceURL, page: page)
                            .frame(minHeight: 620)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13)
                                    .stroke(.blue.opacity(0.35), lineWidth: 2)
                            }
                    }
                    .id("source-preview")
                }

                if !documentRequirements.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionTitle(
                                "Identifierade krav",
                                subtitle: "Alla krav som hittats i detta dokument"
                            )
                            Spacer()
                            Button("Visa i kravlistan") {
                                store.selectedRequirementDocumentID = document.id
                                store.selectedRequirementCategory = nil
                                store.selection = .requirements
                            }

                            if !documentProducts.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        SectionTitle(
                                            "Produkter och produktkrav",
                                            subtitle: "Strukturerat från prisbilagan"
                                        )
                                        Spacer()
                                        Button("Visa alla produkter") {
                                            store.productFilter = document.name
                                            store.selection = .products
                                        }
                                    }
                                    ForEach(documentProducts) { product in
                                        ProductCard(product: product)
                                    }
                                }
                            }
                        }
                        ForEach(documentRequirements) { requirement in
                            RequirementCard(requirement: requirement)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Dokumentinnehåll", subtitle: "\(documentChunks.count) sökbara avsnitt")
                    ForEach(documentChunks) { chunk in
                        VStack(alignment: .leading, spacing: 9) {
                            if let page = chunk.page {
                                SourcePill(
                                    text: locationLabel(documentName: document.name, page: page),
                                    symbol: document.isSpreadsheet ? "tablecells" : "text.page"
                                )
                            }
                            Text(chunk.text)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(17)
                        .background(
                            chunk.id == store.selectedSourceChunkID
                                ? Color.blue.opacity(0.1)
                                : Color(nsColor: .textBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 13)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(
                                    chunk.id == store.selectedSourceChunkID
                                        ? Color.blue
                                        : Color.secondary.opacity(0.15),
                                    lineWidth: chunk.id == store.selectedSourceChunkID ? 2 : 1
                                )
                        }
                        .id(chunk.id)
                    }
                }
            }
            .padding(30)
            }
            .onAppear {
                scrollToSource(using: proxy)
            }
            .onChange(of: store.selectedSourceChunkID) {
                scrollToSource(using: proxy)
            }
        }
    }

    private func scrollToSource(using proxy: ScrollViewProxy) {
        guard let chunkID = store.selectedSourceChunkID,
              documentChunks.contains(where: { $0.id == chunkID }) else {
            if document.sourceURL.pathExtension.lowercased() == "pdf",
               store.selectedDocumentPage != nil {
                withAnimation { proxy.scrollTo("source-preview", anchor: .top) }
            }
            return
        }
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(chunkID, anchor: .center)
            }
        }
    }
}

private struct PDFSourceView: NSViewRepresentable {
    let url: URL
    let page: Int

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
        guard let document = view.document,
              page > 0,
              page <= document.pageCount,
              let target = document.page(at: page - 1) else {
            return
        }
        view.go(to: target)
    }
}

private struct MiniMetric: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3.bold()).monospacedDigit()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(.quaternary)
        }
    }
}

private struct PageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.caption.bold())
                .tracking(1.2)
                .foregroundStyle(.blue)
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(subtitle)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String

    init(_ title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.background, in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(.quaternary, lineWidth: 1)
            }
    }
}

private extension RequirementCategory {
    var tint: Color {
        switch self {
        case .mandatory: .red
        case .evaluation: .orange
        case .contractual: .blue
        case .information: .secondary
        }
    }

    var shortName: String {
        switch self {
        case .mandatory: "Obligatoriskt"
        case .evaluation: "Utvärdering"
        case .contractual: "Avtal"
        case .information: "Övrigt"
        }
    }
}

private extension Requirement {
    var sourceLabel: String {
        if let page {
            "\(documentName) · \(locationLabel(documentName: documentName, page: page).lowercased())"
        } else {
            documentName
        }
    }
}

private extension ProcurementDocument {
    var isSpreadsheet: Bool {
        ["xls", "xlsx"].contains(sourceURL.pathExtension.lowercased())
    }

    var locationUnitPlural: String {
        isSpreadsheet ? "kalkylblad" : "sidor"
    }
}

private func locationLabel(documentName: String, page: Int) -> String {
    documentName.lowercased().hasSuffix(".xlsx") ? "Blad \(page)" : "Sida \(page)"
}
