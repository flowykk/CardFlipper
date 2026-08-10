import Core
import Data
import StudyFeature
import Testing
@testable import CardFlipper

@MainActor
@Test func startupFailureCanRetryContainerConstruction() throws {
    var attempts = 0
    let startup = AppStartupState {
        attempts += 1
        if attempts == 1 {
            throw AppTestError.startup
        }
        return AppContainer(modelContainer: try ModelContainerFactory.makeInMemory())
    }

    #expect(startup.container == nil)
    #expect(startup.hasFailure)

    startup.retry()

    #expect(startup.container != nil)
    #expect(!startup.hasFailure)
    #expect(attempts == 2)
}

@MainActor
@Test func editorSaveReloadsLibraryThenDismissesPresentation() async {
    let original = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let updated = VocabularyCard.appFixture(id: 1, russian: "термин", english: "term")
    let cards = AppCardRepositoryFake([original])
    let model = makeRootModel(cards: cards)
    await model.loadLibrary()
    model.navigation.openEditor(cardID: original.id)
    cards.fetchedCards = [updated]

    await model.editorSaved()

    #expect(model.library.cards == [updated])
    #expect(model.navigation.editor == nil)
    #expect(cards.fetchCount == 2)
}

@MainActor
@Test func editorSelectionResolvesTheCurrentCardByIdentifier() async {
    let selected = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let other = VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")
    let cards = AppCardRepositoryFake([selected, other])
    let model = makeRootModel(cards: cards)
    await model.loadLibrary()

    model.navigation.openEditor(cardID: selected.id)

    #expect(model.selectedEditorCard == selected)
    #expect(model.navigation.editor?.cardID == selected.id)
}

@MainActor
@Test func activeStudyRepeatKeepsCoverPresentedWithFreshSessionIdentity() {
    let configuration = StudyConfiguration(
        direction: .englishToRussian,
        selectedTagIDs: [],
        cards: [.appFixture(id: 1, russian: "слово", english: "word")]
    )
    let navigation = AppNavigationState()
    navigation.path = [.studySetup]

    navigation.startStudy(configuration)
    let first = navigation.activeStudy
    navigation.repeatStudy()
    let repeated = navigation.activeStudy
    navigation.studyPresentationDidDismiss()

    #expect(first?.configuration == configuration)
    #expect(repeated?.configuration == configuration)
    #expect(first?.id == repeated?.id)
    #expect(first?.sessionID != repeated?.sessionID)
    #expect(navigation.path == [.studySetup])
    #expect(navigation.activeStudy != nil)
}

@MainActor
@Test func finishingOrAbandoningStudyReturnsToLibraryAndNewStateRestoresNoSession() {
    let configuration = StudyConfiguration(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        cards: [.appFixture(id: 1, russian: "слово", english: "word")]
    )
    let navigation = AppNavigationState()
    navigation.path = [.studySetup]
    navigation.startStudy(configuration)

    navigation.finishStudy()

    #expect(navigation.activeStudy == nil)
    #expect(navigation.path.isEmpty)
    #expect(AppNavigationState().activeStudy == nil)
}

@MainActor
private func makeRootModel(cards: AppCardRepositoryFake) -> RootViewModel {
    RootViewModel(
        cards: cards,
        tags: AppTagRepositoryFake(),
        dictionary: AppDictionaryServiceFake(),
        speech: AppSpeechServiceFake(),
        shuffler: AppIdentityShuffler()
    )
}
