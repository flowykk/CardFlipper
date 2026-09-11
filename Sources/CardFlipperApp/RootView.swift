import CardEditorFeature
import Core
import Data
import LibraryFeature
import Observation
import StudyFeature
import StatisticsFeature
import SwiftUI

enum AppRoute: Hashable {
    case studySetup
    case statistics
    case settings
    case tags
}

enum AppEditorPresentation: Equatable, Identifiable {
    enum ID: Hashable {
        case newCard
        case edit(UUID)
    }

    case newCard
    case edit(cardID: UUID)

    var id: ID {
        switch self {
        case .newCard: .newCard
        case let .edit(cardID): .edit(cardID)
        }
    }

    var cardID: UUID? {
        switch self {
        case .newCard: nil
        case let .edit(cardID): cardID
        }
    }
}

struct ActiveStudy: Equatable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let configuration: StudyConfiguration
    let snapshot: StudySessionSnapshot?

    init(
        id: UUID = UUID(),
        sessionID: UUID = UUID(),
        configuration: StudyConfiguration,
        snapshot: StudySessionSnapshot? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.configuration = configuration
        self.snapshot = snapshot
    }

    func repeated(with configuration: StudyConfiguration) -> ActiveStudy {
        ActiveStudy(id: id, configuration: configuration)
    }
}

@MainActor
@Observable
final class AppNavigationState {
    var path: [AppRoute] = []
    var editor: AppEditorPresentation?
    var activeStudy: ActiveStudy?

    func openNewEditor() {
        editor = .newCard
    }

    func openEditor(cardID: UUID) {
        editor = .edit(cardID: cardID)
    }

    func dismissEditor() {
        editor = nil
    }

    func openStudySetup() {
        if path.last != .studySetup {
            path.append(.studySetup)
        }
    }

    func openSettings() {
        if path.last != .settings {
            path.append(.settings)
        }
    }

    func startStudy(
        _ configuration: StudyConfiguration,
        snapshot: StudySessionSnapshot? = nil
    ) {
        activeStudy = ActiveStudy(configuration: configuration, snapshot: snapshot)
    }

    func repeatStudy(_ configuration: StudyConfiguration) {
        activeStudy = activeStudy?.repeated(with: configuration)
    }

    func resumeStudy(_ study: ActiveStudy) {
        activeStudy = study
    }

    func finishStudy() {
        activeStudy = nil
        path.removeAll()
    }

    func studyPresentationDidDismiss() {
        guard activeStudy == nil else { return }
        path.removeAll()
    }
}

@MainActor
@Observable
final class RootViewModel {
    let library: LibraryViewModel
    let navigation: AppNavigationState
    let studyTimer: StudyTimerController
    private(set) var resumableStudy: ActiveStudy?

    private let cards: any CardRepository
    private let tags: any TagRepository
    private let dictionary: any DictionaryService
    private let speech: any SpeechService
    private let shuffler: any CardShuffler
    private let statistics: any StatisticsRepository
    private let studySessionStore: any StudySessionStore
    let dailyProgress: any DailyProgressRepository

    init(
        cards: any CardRepository,
        tags: any TagRepository,
        dictionary: any DictionaryService,
        speech: any SpeechService,
        shuffler: any CardShuffler,
        statistics: any StatisticsRepository = UserDefaultsStatisticsRepository(),
        dailyProgress: any DailyProgressRepository = UserDefaultsDailyProgressRepository(),
        studySessionStore: any StudySessionStore = UserDefaultsStudySessionStore(),
        studyTimer: StudyTimerController? = nil,
        navigation: AppNavigationState = AppNavigationState()
    ) {
        self.cards = cards
        self.tags = tags
        self.dictionary = dictionary
        self.speech = speech
        self.shuffler = shuffler
        self.statistics = statistics
        self.dailyProgress = dailyProgress
        self.studySessionStore = studySessionStore
        self.studyTimer = studyTimer ?? StudyTimerController(progress: dailyProgress)
        self.navigation = navigation
        library = LibraryViewModel(cards: cards, tags: tags)
    }

    convenience init(container: AppContainer) {
        self.init(
            cards: container.cards,
            tags: container.tags,
            dictionary: container.dictionary,
            speech: container.speech,
            shuffler: container.shuffler,
            statistics: container.statistics,
            dailyProgress: container.dailyProgress,
            studySessionStore: container.studySessionStore,
            studyTimer: container.studyTimer
        )
    }

    var selectedEditorCard: VocabularyCard? {
        guard let cardID = navigation.editor?.cardID else { return nil }
        return library.cards.first { $0.id == cardID }
    }

    func loadLibrary() async {
        await library.load()
        prepareInterruptedStudyIfNeeded()
    }

    func loadInitialLibrary() async {
        if library.state == .idle {
            await library.load()
        }
        while library.state == .loading {
            await Task.yield()
        }
        prepareInterruptedStudyIfNeeded()
    }

    func editorSaved() async {
        await loadLibrary()
        navigation.dismissEditor()
    }

    func libraryChanged() async {
        await loadLibrary()
    }

    func prepareExport() async throws -> PreparedCardExport {
        try await CardTransferCoordinator(cards: cards).prepareExport()
    }

    func importCards(_ imported: [VocabularyCard]) async throws -> CardMergeResult {
        let result = CardMergeService.merge(existing: try await cards.fetchCards(), imported: imported)
        for card in result.cards {
            var resolvedTags: [Tag] = []
            for tag in card.tags {
                resolvedTags.append(try await tags.create(name: tag.name))
            }
            let resolvedCard = VocabularyCard(
                id: card.id,
                russianMeanings: card.russianMeanings,
                englishVariants: card.englishVariants,
                tags: resolvedTags,
                createdAt: card.createdAt,
                updatedAt: card.updatedAt,
                isLearned: card.isLearned
            )
            try await cards.save(resolvedCard)
        }
        return result
    }

    func makeEditorModel(for presentation: AppEditorPresentation) -> CardEditorViewModel? {
        switch presentation {
        case .newCard:
            return .newCard(
                cards: cards,
                tags: tags,
                dictionary: dictionary,
                speech: speech
            )
        case let .edit(cardID):
            guard let card = library.cards.first(where: { $0.id == cardID }) else {
                return nil
            }
            return .edit(
                card: card,
                cards: cards,
                tags: tags,
                dictionary: dictionary,
                speech: speech
            )
        }
    }

    func makeStudySetupModel() -> StudySetupViewModel {
        StudySetupViewModel(cards: library.cards, tags: library.tags)
    }

    func makeStudySessionModel(for activeStudy: ActiveStudy) -> StudySessionViewModel {
        let today = dailyProgress.progress(for: Date(), calendar: .current)
        return StudySessionViewModel(
            configuration: activeStudy.configuration,
            snapshot: activeStudy.snapshot,
            shuffler: shuffler,
            speech: speech,
            initialDailyGoalProgress: StudyDailyGoalProgress(
                elapsedSeconds: today.elapsedSeconds,
                goalSeconds: today.goalSeconds
            ),
            store: studySessionStore
        )
    }

    func resumeInterruptedStudy() {
        guard let resumableStudy else { return }
        navigation.resumeStudy(resumableStudy)
        self.resumableStudy = nil
    }

    func discardInterruptedStudy() {
        studySessionStore.clear()
        resumableStudy = nil
    }

    var studyStatistics: StudyStatistics {
        statistics.statistics
    }

    var libraryCardCount: Int {
        library.cards.count
    }

    func recordCompletedStudy(sessionID: UUID, result: StudyResult) {
        studyTimer.endSession(id: sessionID)
        statistics.record(sessionID: sessionID, result: result)
    }

    func studyDidAppear(sessionID: UUID) {
        studyTimer.startSession(id: sessionID)
    }

    func sceneActivityChanged(isActive: Bool) {
        studyTimer.setSceneActive(isActive)
    }

    func finishStudy(sessionID: UUID) {
        studyTimer.endSession(id: sessionID)
        studySessionStore.clear()
        navigation.finishStudy()
    }

    func studyDidDisappear(sessionID: UUID) {
        studyTimer.endSession(id: sessionID)
    }

    func cleanupOrphanedActivity() {
        studyTimer.cleanupOrphanedActivity()
    }

    private func prepareInterruptedStudyIfNeeded() {
        guard library.state == .loaded,
              navigation.activeStudy == nil,
              resumableStudy == nil,
              let snapshot = studySessionStore.load() else {
            return
        }

        let cardsByID = Dictionary(uniqueKeysWithValues: library.cards.map { ($0.id, $0) })
        let availableCards = snapshot.originalCardIDs.compactMap { cardsByID[$0] }
        let hasAvailableQueuedCard = snapshot.queueCardIDs.contains { cardsByID[$0] != nil }
        guard !availableCards.isEmpty,
              snapshot.completedResult != nil || hasAvailableQueuedCard else {
            studySessionStore.clear()
            return
        }

        resumableStudy = ActiveStudy(
            configuration: StudyConfiguration(
                direction: snapshot.direction,
                selectedTagIDs: snapshot.selectedTagIDs,
                cards: availableCards
            ),
            snapshot: snapshot
        )
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: RootViewModel
    @State private var appearanceSettings: AppearanceSettings
    @State private var iconSettings: AppIconSettings
    @State private var exportDocument = CardTransferFileDocument(
        transfer: CardTransferDocument(cards: [])
    )
    @State private var isShowingExporter = false
    @State private var isShowingImporter = false
    @State private var isPreparingExport = false
    @State private var preparedExportCardCount = 0
    @State private var transferMessage: String?

    init(
        container: AppContainer,
        appearanceSettings: AppearanceSettings = AppearanceSettings(),
        iconSettings: AppIconSettings = AppIconSettings()
    ) {
        _model = State(initialValue: RootViewModel(container: container))
        _appearanceSettings = State(initialValue: appearanceSettings)
        _iconSettings = State(initialValue: iconSettings)
    }

    var body: some View {
        @Bindable var navigation = model.navigation

        NavigationStack(path: $navigation.path) {
            LibraryView(
                model: model.library,
                onAddCard: navigation.openNewEditor,
                onEditCard: { navigation.openEditor(cardID: $0.id) },
                onStartStudy: navigation.openStudySetup,
                onImportCards: { isShowingImporter = true },
                onManageTags: { navigation.path.append(.tags) },
                onDataChanged: model.libraryChanged
            )
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: navigation.openSettings) {
                        Label("settings.open", systemImage: "gearshape.fill")
                    }
                    .accessibilityIdentifier("library.settings")

                    Button {
                        navigation.path.append(.statistics)
                    } label: {
                        Label {
                            Text("statistics.open", bundle: StatisticsFeatureResources.bundle)
                        } icon: {
                            Image(systemName: "chart.bar.xaxis")
                        }
                    }
                    .accessibilityIdentifier("library.statistics")
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .studySetup:
                    StudySetupView(model: model.makeStudySetupModel()) {
                        navigation.startStudy($0)
                    }
                case .statistics:
                    StatisticsView(
                        statistics: model.studyStatistics,
                        progress: model.dailyProgress,
                        libraryCardCount: model.libraryCardCount,
                        onStartStudy: navigation.openStudySetup
                    )
                case .settings:
                    SettingsView(
                        settings: appearanceSettings,
                        iconSettings: iconSettings,
                        isPreparingExport: isPreparingExport,
                        onExportCards: {
                            guard !isPreparingExport else { return }
                            isPreparingExport = true
                            Task {
                                defer { isPreparingExport = false }
                                do {
                                    let prepared = try await model.prepareExport()
                                    exportDocument = prepared.document
                                    preparedExportCardCount = prepared.cardCount
                                    isShowingExporter = true
                                } catch {
                                    transferMessage = String(localized: "settings.cards.export.failed")
                                }
                            }
                        },
                        onImportCards: { isShowingImporter = true }
                    )
                case .tags:
                    TagManagementView(
                        model: model.library,
                        onDataChanged: model.libraryChanged
                    )
                }
            }
        }
        .sheet(item: $navigation.editor, onDismiss: navigation.dismissEditor) { presentation in
            editor(presentation)
        }
        .fullScreenCover(
            item: $navigation.activeStudy,
            onDismiss: navigation.studyPresentationDidDismiss
        ) { presentation in
            NavigationStack {
                StudySessionView(
                    model: model.makeStudySessionModel(for: presentation),
                    onRepeat: navigation.repeatStudy,
                    onFinish: { model.finishStudy(sessionID: presentation.sessionID) },
                    onComplete: {
                        model.recordCompletedStudy(
                            sessionID: presentation.sessionID,
                            result: $0
                        )
                    }
                )
                .safeAreaInset(edge: .top) {
                    if model.studyTimer.snapshot.isVisible {
                        StudyTimerPill(snapshot: model.studyTimer.snapshot)
                            .padding(.top, 4)
                    }
                }
            }
            .id(presentation.sessionID)
            .task {
                model.studyDidAppear(sessionID: presentation.sessionID)
                while !Task.isCancelled, model.studyTimer.snapshot.isVisible {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { break }
                    model.studyTimer.tick()
                }
            }
            .onDisappear {
                model.studyDidDisappear(sessionID: presentation.sessionID)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            model.sceneActivityChanged(isActive: phase == .active)
        }
        .task {
            model.cleanupOrphanedActivity()
            await model.loadInitialLibrary()
        }
        .alert(
            "study.resume.title",
            isPresented: Binding(
                get: { model.resumableStudy != nil },
                set: { _ in }
            )
        ) {
            Button("study.resume.action", action: model.resumeInterruptedStudy)
            Button(
                "study.resume.discard",
                role: .destructive,
                action: model.discardInterruptedStudy
            )
        } message: {
            Text("study.resume.message")
        }
        .fileExporter(
            isPresented: $isShowingExporter,
            document: exportDocument,
            contentTypes: [.json],
            defaultFilename: "CardFlipper-cards.json"
        ) { result in
            switch result {
            case .success:
                let format = String(localized: "settings.cards.export.success")
                transferMessage = String.localizedStringWithFormat(
                    format,
                    preparedExportCardCount
                )
            case let .failure(error):
                guard (error as NSError).code != NSUserCancelledError else { return }
                transferMessage = String(localized: "settings.cards.export.failed")
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            Task {
                let hasSecurityScope = url.startAccessingSecurityScopedResource()
                defer {
                    if hasSecurityScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let data = try Data(contentsOf: url)
                    let document = try JSONDecoder().decode(CardTransferDocument.self, from: data)
                    let summary = try await model.importCards(document.decodedCards())
                    let format = String(localized: "settings.cards.import.success")
                    transferMessage = String.localizedStringWithFormat(
                        format,
                        summary.addedCount,
                        summary.mergedCount
                    )
                    await model.libraryChanged()
                } catch {
                    transferMessage = String(localized: "settings.cards.import.failed")
                }
            }
        }
        .alert("settings.cards.import.result", isPresented: Binding(
            get: { transferMessage != nil },
            set: { if !$0 { transferMessage = nil } }
        )) {
            Button("common.close", role: .cancel) { transferMessage = nil }
        } message: {
            Text(transferMessage ?? "")
        }
        .tint(appearanceSettings.accentColor)
    }

    @ViewBuilder
    private func editor(_ presentation: AppEditorPresentation) -> some View {
        if let editorModel = model.makeEditorModel(for: presentation) {
            CardEditorView(
                model: editorModel,
                onSaved: model.editorSaved,
                onCancel: model.navigation.dismissEditor
            )
        } else {
            NavigationStack {
                ContentUnavailableView {
                    Label("data.load.failed", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("common.close", action: model.navigation.dismissEditor)
                }
                .navigationTitle("editor.title")
            }
        }
    }
}

struct AppStartupView: View {
    @Bindable var startup: AppStartupState

    var body: some View {
        if let container = startup.container {
            RootView(container: container)
        } else {
            ContentUnavailableView {
                Label("app.startup.failed", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text("app.startup.failed.message")
            } actions: {
                Button("common.retry", action: startup.retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
