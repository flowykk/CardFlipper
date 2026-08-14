import Core
import Data
import Foundation
import StudyFeature
import SwiftUI
import Testing
import StatisticsFeature
@testable import CardFlipper

@Test func appDeclaresAModernLaunchScreenToAvoidLegacyLetterboxing() {
    #expect(Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen") != nil)
}

@MainActor
@Test func appearanceSettingsDefaultToSystemBlue() throws {
    let suiteName = "AppearanceSettingsTests.default"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppearanceSettings(defaults: defaults)
    let components = try #require(settings.sRGBComponents)

    #expect(abs(components.red - 0.0) < 0.001)
    #expect(abs(components.green - 0.478) < 0.001)
    #expect(abs(components.blue - 1.0) < 0.001)
}

@MainActor
@Test func appearanceSettingsPersistAndRestoreOpaqueSRGBColor() throws {
    let suiteName = "AppearanceSettingsTests.persistence"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppearanceSettings(defaults: defaults)
    settings.accentColor = Color(.sRGB, red: 0.25, green: 0.5, blue: 0.75)

    let restored = AppearanceSettings(defaults: defaults)
    let components = try #require(restored.sRGBComponents)
    #expect(abs(components.red - 0.25) < 0.001)
    #expect(abs(components.green - 0.5) < 0.001)
    #expect(abs(components.blue - 0.75) < 0.001)
}

@MainActor
@Test func appearanceSettingsRejectInvalidPersistedColor() throws {
    let suiteName = "AppearanceSettingsTests.invalid"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(Data("{\"red\":2}".utf8), forKey: AppearanceSettings.storageKey)

    let settings = AppearanceSettings(defaults: defaults)
    let components = try #require(settings.sRGBComponents)

    #expect(abs(components.red - 0.0) < 0.001)
    #expect(abs(components.green - 0.478) < 0.001)
    #expect(abs(components.blue - 1.0) < 0.001)
}

@MainActor
@Test func openingSettingsAppendsTheSettingsRouteOnlyOnce() {
    let navigation = AppNavigationState()

    navigation.openSettings()
    navigation.openSettings()

    #expect(navigation.path == [.settings])
}

#if DEBUG
@Test func uiTestLaunchConfigurationSelectsIsolatedStoreAndSeed() {
    let configuration = AppLaunchConfiguration(arguments: [
        "CardFlipper",
        "-uiTesting",
        "-uiTestSeed",
    ])

    #expect(configuration.usesInMemoryStore)
    #expect(configuration.seedsDeterministicVocabulary)
}

@Test func uiTestSeedCannotSelectThePersistentStore() {
    let configuration = AppLaunchConfiguration(arguments: [
        "CardFlipper",
        "-uiTestSeed",
    ])

    #expect(configuration.seedsDeterministicVocabulary)
    #expect(configuration.usesInMemoryStore)
}

@Test func partOfSpeechNamesResolveFromTheAppCatalogAtRuntime() {
    #expect(
        PartOfSpeech.noun.localizedName(locale: Locale(identifier: "en")) == "Noun"
    )
    #expect(
        PartOfSpeech.noun.localizedName(locale: Locale(identifier: "ru")) == "Существительное"
    )
}

@MainActor
@Test func seededUITestContainerContainsDeterministicCardsAndTags() async throws {
    let configuration = AppLaunchConfiguration(arguments: [
        "CardFlipper",
        "-uiTesting",
        "-uiTestSeed",
    ])
    let container = try AppContainer(configuration: configuration)

    let cards = try await container.cards.fetchCards()
    let tags = try await container.tags.fetchTags()

    #expect(cards.map(\.id) == AppLaunchConfiguration.seededCardIDs)
    #expect(cards.map { $0.russianMeanings.first?.text } == ["книга", "кот", "дом"])
    #expect(tags.map(\.name) == ["Основы", "Повторение"])
}
#endif

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
@Test func rootModelExposesCurrentLibraryCardCount() async {
    let cards = AppCardRepositoryFake([
        .appFixture(id: 1, russian: "слово", english: "word"),
        .appFixture(id: 2, russian: "книга", english: "book")
    ])
    let model = makeRootModel(cards: cards)

    await model.loadLibrary()
    #expect(model.libraryCardCount == 2)

    cards.fetchedCards = []
    await model.loadLibrary()
    #expect(model.libraryCardCount == 0)
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
@Test func rootModelCoordinatesStudyTimerLifecycleIdempotently() {
    let defaults = UserDefaults(suiteName: "AppTimerLifecycle.\(UUID().uuidString)")!
    let progress = UserDefaultsDailyProgressRepository(defaults: defaults)
    let timer = StudyTimerController(progress: progress)
    let model = RootViewModel(
        cards: AppCardRepositoryFake(),
        tags: AppTagRepositoryFake(),
        dictionary: AppDictionaryServiceFake(),
        speech: AppSpeechServiceFake(),
        shuffler: AppIdentityShuffler(),
        dailyProgress: progress,
        studyTimer: timer
    )
    let sessionID = UUID()

    model.sceneActivityChanged(isActive: true)
    model.studyDidAppear(sessionID: sessionID)
    #expect(timer.snapshot.isVisible)

    model.finishStudy(sessionID: sessionID)
    model.finishStudy(sessionID: sessionID)
    #expect(!timer.snapshot.isVisible)
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
