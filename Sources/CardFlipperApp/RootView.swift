import CardEditorFeature
import Core
import Data
import DesignSystem
import LibraryFeature
import HistoryFeature
import Observation
import StudyFeature
import StatisticsFeature
import SwiftUI

enum AppRoute: Hashable {
    case studySetup
    case statistics
    case history
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

@MainActor
@Observable
final class CardImportPreviewModel: Identifiable {
    let id = UUID()
    private(set) var preview: CardImportPreview

    private let store: CardImportDraftStore
    private let dictionary: any DictionaryService
    private let speech: any SpeechService

    init(
        preview: CardImportPreview,
        availableTags: [Tag] = [],
        dictionary: any DictionaryService,
        speech: any SpeechService
    ) throws {
        try CardImportValidator.validate(preview.importedCards)
        self.preview = preview
        store = CardImportDraftStore(cards: preview.draftCards, tags: availableTags)
        self.dictionary = dictionary
        self.speech = speech
    }

    func makeEditorModel(cardID: UUID) -> CardEditorViewModel? {
        guard let card = preview.changes.first(where: { $0.id == cardID })?.card else {
            return nil
        }
        return .edit(
            card: card,
            cards: store,
            tags: store,
            dictionary: dictionary,
            speech: speech
        )
    }

    func editorSaved() async {
        guard let cards = try? await store.fetchCards() else { return }
        preview = preview.replacingEditedCards(cards)
        await store.replaceCards(preview.draftCards)
    }

    func replacePreview(_ preview: CardImportPreview) async {
        self.preview = preview
        await store.replaceCards(preview.draftCards)
    }
}

@MainActor
private final class CardImportDraftStore: CardRepository, TagRepository {
    private var cards: [VocabularyCard]
    private var tags: [Tag]

    init(cards: [VocabularyCard], tags: [Tag]) {
        self.cards = cards
        self.tags = (tags + cards.flatMap(\.tags)).reduce(into: []) { result, tag in
            guard !result.contains(where: { $0.id == tag.id }) else { return }
            result.append(tag)
        }
    }

    func fetchCards() async throws -> [VocabularyCard] {
        cards
    }

    func save(_ card: VocabularyCard) async throws {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else {
            cards.append(card)
            return
        }
        cards[index] = card
    }

    func replaceCards(_ cards: [VocabularyCard]) {
        self.cards = cards
        tags = (tags + cards.flatMap(\.tags)).reduce(into: []) { result, tag in
            guard !result.contains(where: { $0.id == tag.id }) else { return }
            result.append(tag)
        }
    }

    func addTags(ids: Set<UUID>, toCardIDs cardIDs: Set<UUID>) async throws {
        let selectedTags = tags.filter { ids.contains($0.id) }
        for index in cards.indices where cardIDs.contains(cards[index].id) {
            cards[index] = cards[index].updating(tags: selectedTags)
        }
    }

    func delete(id: UUID) async throws {
        tags.removeAll { $0.id == id }
        for index in cards.indices {
            cards[index] = cards[index].updating(
                tags: cards[index].tags.filter { $0.id != id }
            )
        }
    }

    func duplicateCandidates(
        for draft: CardDraft,
        excluding id: UUID?
    ) async throws -> [VocabularyCard] {
        let russianValues = Set(draft.russianMeanings.map(TextNormalizer.searchKey))
        let englishValues = Set(draft.englishVariants.map { TextNormalizer.searchKey($0.text) })
        return cards.filter { card in
            guard card.id != id else { return false }
            let cardRussian = Set(card.russianMeanings.map { TextNormalizer.searchKey($0.text) })
            let cardEnglish = Set(card.englishVariants.map { TextNormalizer.searchKey($0.text) })
            return !cardRussian.isDisjoint(with: russianValues)
                || !cardEnglish.isDisjoint(with: englishValues)
        }
    }

    func fetchTags() async throws -> [Tag] {
        tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func create(name: String) async throws -> Tag {
        let normalizedName = TextNormalizer.searchKey(name)
        guard !normalizedName.isEmpty else { throw TagRepositoryError.emptyName }
        if let existing = tags.first(where: { TextNormalizer.searchKey($0.name) == normalizedName }) {
            return existing
        }
        let tag = Tag(id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        tags.append(tag)
        return tag
    }

}

struct ActiveStudy: Equatable, Identifiable {
    let id: UUID
    /// A fresh owner for every model/presentation lifetime, including resumes of the same session.
    let presentationID = UUID()
    let sessionID: UUID
    let configuration: StudyConfiguration
    let snapshot: StudySessionSnapshot?

    init(
        id: UUID? = nil,
        sessionID: UUID = UUID(),
        configuration: StudyConfiguration,
        snapshot: StudySessionSnapshot? = nil
    ) {
        self.sessionID = snapshot?.sessionID ?? sessionID
        self.id = id ?? snapshot?.sessionID ?? sessionID
        self.configuration = configuration
        self.snapshot = snapshot
    }

    func repeated(with configuration: StudyConfiguration) -> ActiveStudy {
        ActiveStudy(id: id, configuration: configuration)
    }
}

enum RootPresentationError: Equatable {
    case finalization(sessionID: UUID)
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
    private(set) var pendingStudyConfiguration: StudyConfiguration?
    private(set) var isNewGameConflictPresented = false
    private(set) var presentationError: RootPresentationError?

    var resumableSnapshot: StudySessionSnapshot? { resumableStudy?.snapshot }

    private let cards: any CardRepository
    private let cardImporter: any CardImportRepository
    private let tags: any TagRepository
    private let dictionary: any DictionaryService
    private let speech: any SpeechService
    private let shuffler: any CardShuffler
    private let statistics: any StatisticsRepository
    private let studySessionStore: any StudySessionStore
    private let history: any StudyHistoryRepository
    private let finalizer: StudyHistoryFinalizer
    private var failedFinalization: StudySessionSnapshot?
    private var isPendingRepeat = false
    private var shouldOpenStudySetupAfterFinalization = false
    private var finalizedSessionIDs: Set<UUID> = []
    @ObservationIgnored private var cachedStudyModel: (id: UUID, model: StudySessionViewModel)?
    @ObservationIgnored private var cachedWritingModel: (id: UUID, model: WritingSessionViewModel)?
    let dailyProgress: any DailyProgressRepository

    init(
        cards: any CardRepository,
        cardImporter: any CardImportRepository,
        tags: any TagRepository,
        dictionary: any DictionaryService,
        speech: any SpeechService,
        shuffler: any CardShuffler,
        history: any StudyHistoryRepository,
        statistics: any StatisticsRepository = UserDefaultsStatisticsRepository(),
        dailyProgress: any DailyProgressRepository = UserDefaultsDailyProgressRepository(),
        studySessionStore: any StudySessionStore = UserDefaultsStudySessionStore(),
        studyTimer: StudyTimerController? = nil,
        navigation: AppNavigationState = AppNavigationState()
    ) {
        self.cards = cards
        self.cardImporter = cardImporter
        self.tags = tags
        self.dictionary = dictionary
        self.speech = speech
        self.shuffler = shuffler
        self.statistics = statistics
        self.dailyProgress = dailyProgress
        self.studySessionStore = studySessionStore
        self.history = history
        finalizer = StudyHistoryFinalizer(history: history, statistics: statistics, sessionStore: studySessionStore)
        self.studyTimer = studyTimer ?? StudyTimerController(progress: dailyProgress)
        self.navigation = navigation
        library = LibraryViewModel(cards: cards, tags: tags)
    }

    convenience init(container: AppContainer) {
        self.init(
            cards: container.cards,
            cardImporter: container.cardImporter,
            tags: container.tags,
            dictionary: container.dictionary,
            speech: container.speech,
            shuffler: container.shuffler,
            history: container.history,
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

    func makeImportPreview(
        _ imported: [VocabularyCard],
        fileName: String,
        replacingCardIDs: Set<UUID> = []
    ) async throws -> CardImportPreview {
        try CardImportValidator.validate(imported)
        let existing = try await cards.fetchCards()
        try CardImportValidator.validate(
            imported,
            against: existing,
            replacingCardIDs: replacingCardIDs
        )
        return CardImportPreview(
            fileName: fileName,
            existing: existing,
            imported: imported,
            replacingCardIDs: replacingCardIDs
        )
    }

    func makeImportPreviewModel(
        _ imported: [VocabularyCard],
        fileName: String
    ) async throws -> CardImportPreviewModel {
        try CardImportPreviewModel(
            preview: await makeImportPreview(imported, fileName: fileName),
            availableTags: await tags.fetchTags(),
            dictionary: dictionary,
            speech: speech
        )
    }

    func confirmImport(_ preview: CardImportPreview) async throws {
        let current = try await cards.fetchCards()
        guard Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
            == Dictionary(uniqueKeysWithValues: preview.originalCards.map { ($0.id, $0) }) else {
            throw CardImportError.libraryChanged
        }
        let cardsToSaveIDs = Set(preview.cardsToSave.map(\.id))
        let replacingCardIDs = preview.replacingCardIDs.intersection(cardsToSaveIDs)
        _ = try await cardImporter.importCards(
            preview.cardsToSave,
            replacingCardIDs: replacingCardIDs
        )
        await libraryChanged()
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
        if let cachedStudyModel, cachedStudyModel.id == activeStudy.presentationID {
            return cachedStudyModel.model
        }
        let today = dailyProgress.progress(for: Date(), calendar: .current)
        let model = StudySessionViewModel(
            configuration: activeStudy.configuration,
            sessionID: activeStudy.sessionID,
            selectedTagNames: activeStudy.configuration.selectedTagNames,
            snapshot: activeStudy.snapshot,
            shuffler: shuffler,
            speech: speech,
            initialDailyGoalProgress: StudyDailyGoalProgress(
                elapsedSeconds: today.elapsedSeconds,
                goalSeconds: today.goalSeconds
            ),
            store: sessionWriteGate(for: activeStudy)
        )
        if navigation.activeStudy?.presentationID == activeStudy.presentationID {
            cachedStudyModel = (activeStudy.presentationID, model)
        }
        return model
    }

    func makeWritingSessionModel(for activeStudy: ActiveStudy) -> WritingSessionViewModel {
        if let cachedWritingModel, cachedWritingModel.id == activeStudy.presentationID {
            return cachedWritingModel.model
        }
        let today = dailyProgress.progress(for: Date(), calendar: .current)
        let model = WritingSessionViewModel(
            configuration: activeStudy.configuration,
            sessionID: activeStudy.sessionID,
            selectedTagNames: activeStudy.configuration.selectedTagNames,
            snapshot: activeStudy.snapshot,
            shuffler: shuffler,
            speech: speech,
            initialDailyGoalProgress: StudyDailyGoalProgress(
                elapsedSeconds: today.elapsedSeconds,
                goalSeconds: today.goalSeconds
            ),
            store: sessionWriteGate(for: activeStudy)
        )
        if navigation.activeStudy?.presentationID == activeStudy.presentationID {
            cachedWritingModel = (activeStudy.presentationID, model)
        }
        return model
    }

    private func sessionWriteGate(for study: ActiveStudy) -> StudySessionWriteGate {
        StudySessionWriteGate(store: studySessionStore) { [weak self] in
            guard let self, !finalizedSessionIDs.contains(study.sessionID) else { return false }
            return navigation.activeStudy?.presentationID == study.presentationID
        }
    }

    func makeHistoryModel() -> StudyHistoryViewModel {
        StudyHistoryViewModel(repository: history)
    }

    func requestOpenStudySetup() {
        prepareInterruptedStudyIfNeeded()
        guard studySessionStore.load() != nil else {
            navigation.openStudySetup()
            return
        }
        shouldOpenStudySetupAfterFinalization = true
        isNewGameConflictPresented = presentationError == nil
    }

    func requestStartStudy(_ configuration: StudyConfiguration) {
        prepareInterruptedStudyIfNeeded()
        guard studySessionStore.load() != nil else {
            navigation.startStudy(configuration)
            return
        }
        pendingStudyConfiguration = configuration
        isNewGameConflictPresented = presentationError == nil
    }

    func continueInterruptedStudy() {
        cancelPendingStudy()
        guard let resumableStudy else { return }
        navigation.resumeStudy(resumableStudy)
        self.resumableStudy = nil
    }

    func resumeInterruptedStudy() {
        continueInterruptedStudy()
    }

    func cancelPendingStudy() {
        pendingStudyConfiguration = nil
        isNewGameConflictPresented = false
        isPendingRepeat = false
        shouldOpenStudySetupAfterFinalization = false
    }

    func repeatStudy(_ configuration: StudyConfiguration, sessionID: UUID, presentationID: UUID) {
        guard ownsPresentation(sessionID: sessionID, presentationID: presentationID) else { return }
        if let snapshot = studySessionStore.load() {
            pendingStudyConfiguration = configuration
            isPendingRepeat = true
            finalize(snapshot)
        } else {
            navigation.repeatStudy(configuration)
        }
    }

    func replaceInterruptedStudy() {
        guard pendingStudyConfiguration != nil || shouldOpenStudySetupAfterFinalization,
              let snapshot = studySessionStore.load() else { return }
        isNewGameConflictPresented = false
        finalize(snapshot)
    }

    func retryFinalization() {
        guard let snapshot = failedFinalization else { return }
        finalize(snapshot)
    }

    func cancelFinalizationError() {
        presentationError = nil
        cancelPendingStudy()
    }

    var studyStatistics: StudyStatistics {
        statistics.statistics
    }

    var libraryCardCount: Int {
        library.cards.count
    }

    func recordCompletedStudy(sessionID: UUID, presentationID: UUID, mode: StudyMode, result: StudyResult) {
        guard ownsPresentation(sessionID: sessionID, presentationID: presentationID) else { return }
        studyTimer.endSession(id: sessionID)
        guard let snapshot = studySessionStore.load(), snapshot.sessionID == sessionID,
              snapshot.completedResult != nil else { return }
        finalize(snapshot)
    }

    func studyDidAppear(sessionID: UUID, presentationID: UUID) {
        guard ownsPresentation(sessionID: sessionID, presentationID: presentationID),
              !finalizedSessionIDs.contains(sessionID) else { return }
        studyTimer.startSession(id: sessionID)
    }

    func sceneActivityChanged(isActive: Bool) {
        studyTimer.setSceneActive(isActive)
    }

    func finishStudy(sessionID: UUID, presentationID: UUID) {
        saveAndExitStudy(sessionID: sessionID, presentationID: presentationID)
    }

    func saveAndExitStudy(sessionID: UUID, presentationID: UUID) {
        guard ownsPresentation(sessionID: sessionID, presentationID: presentationID) else { return }
        studyTimer.endSession(id: sessionID)
        cachedStudyModel = nil
        cachedWritingModel = nil
        navigation.finishStudy()
        prepareInterruptedStudyIfNeeded()
    }

    func studyDidDisappear(sessionID: UUID, presentationID: UUID) {
        guard ownsPresentation(sessionID: sessionID, presentationID: presentationID) else { return }
        studyTimer.endSession(id: sessionID)
    }

    private func ownsPresentation(sessionID: UUID, presentationID: UUID) -> Bool {
        navigation.activeStudy?.sessionID == sessionID
            && navigation.activeStudy?.presentationID == presentationID
    }

    func cleanupOrphanedActivity() {
        studyTimer.cleanupOrphanedActivity()
    }

    private func prepareInterruptedStudyIfNeeded() {
        guard library.state == .loaded,
              navigation.activeStudy == nil else { return }
        resumableStudy = nil
        guard let persistedSnapshot = studySessionStore.load() else { return }
        let snapshot = persistedSnapshot.backfillingStudyMetadata(cards: library.cards, tags: library.tags)
        if snapshot != persistedSnapshot {
            studySessionStore.save(snapshot)
        }

        let cardsByID = Dictionary(uniqueKeysWithValues: library.cards.map { ($0.id, $0) })
        let availableCards = snapshot.originalCardIDs.compactMap { cardsByID[$0] }
        let hasAvailableQueuedCard = snapshot.queueCardIDs.contains { cardsByID[$0] != nil }
        guard snapshot.completedResult == nil, hasAvailableQueuedCard else {
            finalize(snapshot)
            return
        }

        resumableStudy = ActiveStudy(
            configuration: StudyConfiguration(
                mode: snapshot.mode,
                direction: snapshot.direction,
                selectedTagIDs: snapshot.selectedTagIDs,
                selectedTagNames: snapshot.selectedTagNames,
                cards: availableCards
            ),
            snapshot: snapshot
        )
    }

    private func finalize(_ snapshot: StudySessionSnapshot) {
        do {
            _ = try finalizer.finalize(snapshot, completedAt: Date())
            finalizedSessionIDs.insert(snapshot.sessionID)
            failedFinalization = nil
            presentationError = nil
            resumableStudy = nil
            if let pendingStudyConfiguration {
                let repeatsCurrentPresentation = isPendingRepeat
                cancelPendingStudy()
                if repeatsCurrentPresentation {
                    navigation.repeatStudy(pendingStudyConfiguration)
                } else {
                    navigation.startStudy(pendingStudyConfiguration)
                }
            } else if shouldOpenStudySetupAfterFinalization {
                cancelPendingStudy()
                navigation.openStudySetup()
            }
        } catch {
            failedFinalization = snapshot
            presentationError = .finalization(sessionID: snapshot.sessionID)
        }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var importPreview: CardImportPreviewModel?

    init(
        container: AppContainer,
        appearanceSettings: AppearanceSettings = AppearanceSettings(),
        iconSettings: AppIconSettings = AppIconSettings()
    ) {
        let rootModel = RootViewModel(container: container)
        _model = State(initialValue: rootModel)
        _appearanceSettings = State(initialValue: appearanceSettings)
        _iconSettings = State(initialValue: iconSettings)
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestImportReview") {
            _importPreview = State(initialValue: try! CardImportPreviewModel(
                preview: Self.importPreviewFixture,
                dictionary: container.dictionary,
                speech: container.speech
            ))
        }
#endif
    }

    var body: some View {
        @Bindable var navigation = model.navigation

        NavigationStack(path: $navigation.path.withBackNavigationFeedback()) {
            LibraryView(
                model: model.library,
                onAddCard: navigation.openNewEditor,
                onEditCard: { navigation.openEditor(cardID: $0.id) },
                onStartStudy: model.requestOpenStudySetup,
                onOpenSettings: navigation.openSettings,
                onImportCards: { isShowingImporter = true },
                onManageTags: { navigation.path.append(.tags) },
                onDataChanged: model.libraryChanged
            )
            .safeAreaInset(edge: .top) {
                if let snapshot = model.resumableSnapshot {
                    ResumableStudyBanner(snapshot: snapshot, onResume: model.continueInterruptedStudy)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            }
            .toolbar {
                if !model.library.isBulkTagSelectionActive {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        HapticButton {
                            navigation.path.append(.history)
                        } label: {
                            Label("history.open", systemImage: "clock.arrow.circlepath")
                        }
                        .accessibilityIdentifier("library.history")

                        HapticButton {
                            navigation.path.append(.statistics)
                        } label: {
                            Label {
                                Text("statistics.open", bundle: StatisticsFeatureResources.bundle)
                            } icon: {
                                Image(systemName: AppSymbol.statistics)
                            }
                        }
                        .accessibilityIdentifier("library.statistics")
                    }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .studySetup:
                    StudySetupView(model: model.makeStudySetupModel()) {
                        model.requestStartStudy($0)
                    }
                case .history:
                    StudyHistoryView(
                        model: model.makeHistoryModel(),
                        resumableSnapshot: model.resumableSnapshot,
                        onResume: model.continueInterruptedStudy
                    )
                case .statistics:
                    StatisticsView(
                        statistics: model.studyStatistics,
                        progress: model.dailyProgress,
                        libraryCardCount: model.libraryCardCount,
                        onStartStudy: model.requestOpenStudySetup
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
                Group {
                    switch presentation.configuration.mode {
                    case .flashcards:
                        StudySessionView(
                            model: model.makeStudySessionModel(for: presentation),
                            onRepeat: { model.repeatStudy($0, sessionID: presentation.sessionID, presentationID: presentation.presentationID) },
                            onFinish: { model.saveAndExitStudy(sessionID: presentation.sessionID, presentationID: presentation.presentationID) },
                            onComplete: {
                                model.recordCompletedStudy(
                                    sessionID: presentation.sessionID,
                                    presentationID: presentation.presentationID,
                                    mode: presentation.configuration.mode,
                                    result: $0
                                )
                            }
                        )
                    case .writing:
                        WritingSessionView(
                            model: model.makeWritingSessionModel(for: presentation),
                            onRepeat: { model.repeatStudy($0, sessionID: presentation.sessionID, presentationID: presentation.presentationID) },
                            onFinish: { model.saveAndExitStudy(sessionID: presentation.sessionID, presentationID: presentation.presentationID) },
                            onComplete: {
                                model.recordCompletedStudy(
                                    sessionID: presentation.sessionID,
                                    presentationID: presentation.presentationID,
                                    mode: presentation.configuration.mode,
                                    result: $0
                                )
                            }
                        )
                    }
                }
                .toolbar {
                    if model.studyTimer.snapshot.isVisible {
                        ToolbarItem(placement: .topBarLeading) {
                            Text(verbatim: dynamicTypeSize.isAccessibilitySize
                                 ? StudyDurationFormatter.string(
                                    seconds: model.studyTimer.snapshot.sessionElapsedSeconds
                                 )
                                 : StudyTimerCopy.summary(model.studyTimer.snapshot))
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            .padding(.horizontal, 8)
                            .fixedSize(horizontal: true, vertical: false)
                            .accessibilityLabel(Text(verbatim: StudyTimerCopy.summary(
                                model.studyTimer.snapshot
                            )))
                            .accessibilityIdentifier("study.timer")
                        }
                    }
                }
            }
            .id(presentation.sessionID)
            .alert("study.finalization.failed.title", isPresented: Binding(
                get: { model.presentationError != nil },
                set: { _ in }
            )) {
                HapticButton("study.finalization.retry", action: model.retryFinalization)
                HapticButton("common.cancel", role: .cancel, action: model.cancelFinalizationError)
            } message: {
                Text("study.finalization.failed.message")
            }
            .task {
                model.studyDidAppear(sessionID: presentation.sessionID, presentationID: presentation.presentationID)
                while !Task.isCancelled, model.studyTimer.snapshot.isVisible {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { break }
                    model.studyTimer.tick()
                }
            }
            .onDisappear {
                model.studyDidDisappear(sessionID: presentation.sessionID, presentationID: presentation.presentationID)
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
            "study.conflict.title",
            isPresented: Binding(
                get: { model.isNewGameConflictPresented },
                set: { _ in }
            )
        ) {
            HapticButton("study.conflict.continue", action: model.continueInterruptedStudy)
            HapticButton("study.conflict.startNew", action: model.replaceInterruptedStudy)
            HapticButton("common.cancel", role: .cancel, action: model.cancelPendingStudy)
        } message: {
            Text("study.conflict.message")
        }
        .alert("study.finalization.failed.title", isPresented: Binding(
            get: { model.presentationError != nil && navigation.activeStudy == nil },
            set: { _ in }
        )) {
            HapticButton("study.finalization.retry", action: model.retryFinalization)
            HapticButton("common.cancel", role: .cancel, action: model.cancelFinalizationError)
        } message: {
            Text("study.finalization.failed.message")
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
                    importPreview = try await model.makeImportPreviewModel(
                        document.decodedCards(),
                        fileName: url.lastPathComponent
                    )
                } catch {
                    transferMessage = String(localized: "settings.cards.import.failed")
                }
            }
        }
        .sheet(item: $importPreview) { previewModel in
            CardImportPreviewView(
                model: previewModel,
                onConfirm: model.confirmImport,
                onRefresh: { preview in
                    try await model.makeImportPreview(
                        preview.importedCards,
                        fileName: preview.fileName,
                        replacingCardIDs: preview.replacingCardIDs
                    )
                }
            )
        }
        .alert("settings.cards.import.result", isPresented: Binding(
            get: { transferMessage != nil },
            set: { if !$0 { transferMessage = nil } }
        )) {
            HapticButton("common.close", role: .cancel) { transferMessage = nil }
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
                    HapticButton("common.close", action: model.navigation.dismissEditor)
                }
                .navigationTitle("editor.title")
            }
        }
    }

#if DEBUG
    private static var importPreviewFixture: CardImportPreview {
        let unchanged = simpleImportFixture(
            cardID: 2,
            russianID: 2,
            englishID: 2,
            russian: "дом",
            english: "house"
        )
        let changedBefore = simpleImportFixture(
            cardID: 3,
            russianID: 3,
            englishID: 3,
            russian: "работа",
            english: "work"
        )
        let changedImport = simpleImportFixture(
            cardID: 4,
            russianID: 4,
            englishID: 4,
            russian: "работа",
            english: "job"
        )
        return CardImportPreview(
            fileName: "cards.json",
            existing: [unchanged, changedBefore],
            imported: [importReviewFixture, changedImport, unchanged]
        )
    }

    private static func simpleImportFixture(
        cardID: Int,
        russianID: Int,
        englishID: Int,
        russian: String,
        english: String
    ) -> VocabularyCard {
        VocabularyCard(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", cardID))!,
            russianMeanings: [
                RussianMeaning(
                    id: UUID(uuidString: String(format: "00000000-0000-0000-1000-%012d", russianID))!,
                    text: russian
                ),
            ],
            englishVariants: [
                EnglishVariant(
                    id: UUID(uuidString: String(format: "00000000-0000-0000-2000-%012d", englishID))!,
                    text: english,
                    ipa: nil,
                    partsOfSpeech: []
                ),
            ],
            tags: [],
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
    }

    private static var importReviewFixture: VocabularyCard {
        VocabularyCard(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            russianMeanings: [
                RussianMeaning(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000001001")!,
                    text: "книга"
                ),
            ],
            englishVariants: [
                EnglishVariant(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000002001")!,
                    text: "book",
                    ipa: "bʊk",
                    partsOfSpeech: [.noun],
                    usageExamples: [
                        UsageExample(
                            id: UUID(uuidString: "00000000-0000-0000-0000-000000003001")!,
                            text: "This book is easy to read.",
                            partOfSpeech: .noun
                        ),
                    ]
                ),
            ],
            tags: [
                Tag(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
                    name: "Основы"
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
    }
#endif
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
                HapticButton("common.retry", action: startup.retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
