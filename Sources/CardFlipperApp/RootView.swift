import CardEditorFeature
import Core
import LibraryFeature
import Observation
import StudyFeature
import SwiftUI

enum AppRoute: Hashable {
    case studySetup
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

    init(
        id: UUID = UUID(),
        sessionID: UUID = UUID(),
        configuration: StudyConfiguration
    ) {
        self.id = id
        self.sessionID = sessionID
        self.configuration = configuration
    }

    func repeated() -> ActiveStudy {
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

    func startStudy(_ configuration: StudyConfiguration) {
        activeStudy = ActiveStudy(configuration: configuration)
    }

    func repeatStudy() {
        activeStudy = activeStudy?.repeated()
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

    private let cards: any CardRepository
    private let tags: any TagRepository
    private let dictionary: any DictionaryService
    private let speech: any SpeechService
    private let shuffler: any CardShuffler

    init(
        cards: any CardRepository,
        tags: any TagRepository,
        dictionary: any DictionaryService,
        speech: any SpeechService,
        shuffler: any CardShuffler,
        navigation: AppNavigationState = AppNavigationState()
    ) {
        self.cards = cards
        self.tags = tags
        self.dictionary = dictionary
        self.speech = speech
        self.shuffler = shuffler
        self.navigation = navigation
        library = LibraryViewModel(cards: cards, tags: tags)
    }

    convenience init(container: AppContainer) {
        self.init(
            cards: container.cards,
            tags: container.tags,
            dictionary: container.dictionary,
            speech: container.speech,
            shuffler: container.shuffler
        )
    }

    var selectedEditorCard: VocabularyCard? {
        guard let cardID = navigation.editor?.cardID else { return nil }
        return library.cards.first { $0.id == cardID }
    }

    func loadLibrary() async {
        await library.load()
    }

    func editorSaved() async {
        await loadLibrary()
        navigation.dismissEditor()
    }

    func libraryChanged() async {
        await loadLibrary()
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

    func makeStudySessionModel(configuration: StudyConfiguration) -> StudySessionViewModel {
        StudySessionViewModel(
            configuration: configuration,
            shuffler: shuffler,
            speech: speech
        )
    }
}

struct RootView: View {
    @State private var model: RootViewModel

    init(container: AppContainer) {
        _model = State(initialValue: RootViewModel(container: container))
    }

    var body: some View {
        @Bindable var navigation = model.navigation

        NavigationStack(path: $navigation.path) {
            LibraryView(
                model: model.library,
                onAddCard: navigation.openNewEditor,
                onEditCard: { navigation.openEditor(cardID: $0.id) },
                onStartStudy: navigation.openStudySetup,
                onDataChanged: model.libraryChanged
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .studySetup:
                    StudySetupView(model: model.makeStudySetupModel()) {
                        navigation.startStudy($0)
                    }
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
                    model: model.makeStudySessionModel(
                        configuration: presentation.configuration
                    ),
                    onRepeat: { _ in navigation.repeatStudy() },
                    onFinish: navigation.finishStudy
                )
            }
            .id(presentation.sessionID)
        }
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
