import Core
import Data
import DesignSystem
import Foundation
import StudyFeature
import SwiftUI
import Testing
import UIKit
import StatisticsFeature
@testable import CardFlipper

@MainActor
@Test func appOffersTenIconsWithLoadablePreviewsAndDeclaredAlternates() throws {
    #expect(AppIconSettings.AppIcon.allCases.count == 10)
    let icons = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
    let alternates = try #require(icons["CFBundleAlternateIcons"] as? [String: [String: Any]])
    for icon in AppIconSettings.AppIcon.allCases {
        let preview = icon == .default ? "Preview_AppIcon" : "Preview_\(icon.rawValue)"
        #expect(UIImage(named: preview) != nil, "Missing preview: \(preview)")
        if let name = icon.alternateIconName {
            let entry = try #require(alternates[name])
            #expect(entry["CFBundleIconName"] as? String == name)
        }
    }
}

@Test func appDeclaresAModernLaunchScreenToAvoidLegacyLetterboxing() {
    #expect(Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen") != nil)
}

@MainActor
@Test func appearanceSettingsDefaultToSystemAccent() throws {
    let suiteName = "AppearanceSettingsTests.default"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppearanceSettings(defaults: defaults)
    let components = try #require(settings.sRGBComponents)
    let expected = try #require(lightSRGBComponents(of: Color(uiColor: .systemBlue)))

    #expect(abs(components.red - expected.red) < 0.001)
    #expect(abs(components.green - expected.green) < 0.001)
    #expect(abs(components.blue - expected.blue) < 0.001)
}

@MainActor
@Test func appIconSettingsReadTheActualSystemSelection() {
    let settings = AppIconSettings()
    let expected = UIApplication.shared.alternateIconName
        .flatMap(AppIconSettings.AppIcon.init(rawValue:)) ?? .default
    #expect(settings.selectedIcon == expected)
}

@MainActor
@Test func appearanceSettingsPersistAndRestoreCustomAccent() throws {
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
@Test func appearanceSettingsMigratesSelectedPresetToCustomColor() throws {
    let suiteName = "AppearanceSettingsTests.migration"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("berry", forKey: AppearanceSettings.selectionKey)

    let settings = AppearanceSettings(defaults: defaults)
    let components = try #require(settings.sRGBComponents)
    let berry = try #require(AccessibleAccent.all.first { $0.id == "berry" })
    let expected = try #require(lightSRGBComponents(of: berry.lightColor))

    #expect(abs(components.red - expected.red) < 0.001)
    #expect(abs(components.green - expected.green) < 0.001)
    #expect(abs(components.blue - expected.blue) < 0.001)
    #expect(defaults.data(forKey: AppearanceSettings.storageKey) != nil)
    #expect(defaults.string(forKey: AppearanceSettings.selectionKey) == nil)
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
    let expected = try #require(lightSRGBComponents(of: Color(uiColor: .systemBlue)))

    #expect(abs(components.red - expected.red) < 0.001)
    #expect(abs(components.green - expected.green) < 0.001)
    #expect(abs(components.blue - expected.blue) < 0.001)
}

@MainActor
private func lightSRGBComponents(of color: Color) -> (red: Double, green: Double, blue: Double)? {
    guard
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let components = UIColor(color).resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .light)
        ).cgColor.converted(
            to: colorSpace,
            intent: .defaultIntent,
            options: nil
        )?.components,
        components.count >= 3
    else {
        return nil
    }

    return (
        red: Double(components[0]),
        green: Double(components[1]),
        blue: Double(components[2])
    )
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
    #expect(!configuration.preservesStudySession)
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
@Test func exportPreparationPropagatesRepositoryFailureWithoutCreatingDocument() async {
    let cards = AppCardRepositoryFake(fetchError: AppTestError.startup)
    let model = makeRootModel(cards: cards)
    var didFail = false

    do {
        _ = try await model.prepareExport()
    } catch {
        didFail = true
    }

    #expect(didFail)
    #expect(cards.fetchCount == 1)
}

@MainActor
@Test func exportPreparationReportsExactCardCount() async throws {
    let sourceCards = [
        VocabularyCard.appFixture(id: 1, russian: "слово", english: "word"),
        VocabularyCard.appFixture(id: 2, russian: "книга", english: "book"),
    ]
    let model = makeRootModel(cards: AppCardRepositoryFake(sourceCards))

    let prepared = try await model.prepareExport()

    #expect(prepared.cardCount == 2)
    #expect(prepared.document.transfer.decodedCards() == sourceCards)
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
    navigation.repeatStudy(configuration)
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
@Test func loadingLibraryOffersAnInterruptedSessionWithMissingCardsRemoved() async throws {
    let first = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let second = VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")
    let store = AppStudySessionStoreFake(snapshot: StudySessionSnapshot(
        direction: .englishToRussian,
        selectedTagIDs: [],
        originalCardIDs: [first.id, second.id],
        queueCardIDs: [first.id, second.id],
        isShowingAnswer: true,
        isRevealed: true,
        forgottenCount: 1,
        repeatedCardIDs: [first.id],
        totalAssessmentCount: 2,
        accumulatedDurationSeconds: 15
    ))
    let model = makeRootModel(
        cards: AppCardRepositoryFake([second]),
        studySessionStore: store
    )

    await model.loadLibrary()
    let resumable = try #require(model.resumableStudy)

    #expect(resumable.configuration.cards == [second])
    #expect(resumable.snapshot?.queueCardIDs == [first.id, second.id])

    model.resumeInterruptedStudy()
    #expect(model.navigation.activeStudy == resumable)
    #expect(model.resumableStudy == nil)
}

@MainActor
@Test func emptyInterruptedSessionIsDiscardedAndExplicitActionsClearStorage() async {
    let missingID = UUID.appFixture(999)
    let invalidStore = AppStudySessionStoreFake(snapshot: StudySessionSnapshot(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        originalCardIDs: [missingID],
        queueCardIDs: [missingID],
        isShowingAnswer: false,
        isRevealed: false,
        forgottenCount: 0,
        repeatedCardIDs: [],
        totalAssessmentCount: 0,
        accumulatedDurationSeconds: 0
    ))
    let invalidModel = makeRootModel(
        cards: AppCardRepositoryFake(),
        studySessionStore: invalidStore
    )

    await invalidModel.loadLibrary()
    #expect(invalidModel.resumableStudy == nil)
    #expect(invalidStore.clearCount == 1)

    let card = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let validStore = AppStudySessionStoreFake(snapshot: StudySessionSnapshot(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        originalCardIDs: [card.id],
        queueCardIDs: [card.id],
        isShowingAnswer: false,
        isRevealed: false,
        forgottenCount: 0,
        repeatedCardIDs: [],
        totalAssessmentCount: 0,
        accumulatedDurationSeconds: 0
    ))
    let validModel = makeRootModel(
        cards: AppCardRepositoryFake([card]),
        studySessionStore: validStore
    )
    await validModel.loadLibrary()
    validModel.discardInterruptedStudy()
    #expect(validStore.clearCount == 1)

    validModel.navigation.startStudy(StudyConfiguration(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        cards: [card]
    ))
    validModel.finishStudy(sessionID: validModel.navigation.activeStudy!.sessionID)
    #expect(validStore.clearCount == 2)
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
private func makeRootModel(
    cards: AppCardRepositoryFake,
    studySessionStore: any StudySessionStore = AppStudySessionStoreFake()
) -> RootViewModel {
    RootViewModel(
        cards: cards,
        tags: AppTagRepositoryFake(),
        dictionary: AppDictionaryServiceFake(),
        speech: AppSpeechServiceFake(),
        shuffler: AppIdentityShuffler(),
        studySessionStore: studySessionStore
    )
}

@MainActor
private final class AppIconClientStub: AppIconClient {
    var supportsAlternateIcons = true
    var alternateIconName: String?
    var fails = false
    var suspends = false
    var continuation: CheckedContinuation<Void, Never>?
    var requests: [String?] = []

    func changeIcon(to name: String?) async throws {
        requests.append(name)
        if suspends {
            await withCheckedContinuation { continuation = $0 }
        }
        if fails { throw AppTestError.startup }
        alternateIconName = name
    }
}

@MainActor
@Test func iconSelectionFollowsSystemStateAndCanReturnToPrimary() async {
    let client = AppIconClientStub()
    client.alternateIconName = "IconViolet3D"
    let settings = AppIconSettings(client: client)
    #expect(settings.selectedIcon == .violet3D)
    await settings.select(.mint3D)
    #expect(settings.selectedIcon == .mint3D)
    #expect(client.requests == ["IconMint3D"])
    await settings.select(.default)
    #expect(settings.selectedIcon == .default)
    #expect(client.requests.count == 2)
    #expect(client.requests.last! == nil)
    #expect(settings.errorMessage == nil)
    #expect(!settings.isChanging)
}

@MainActor
@Test func iconSelectionFailureKeepsCurrentIconAndAllowsRetry() async {
    let client = AppIconClientStub()
    client.fails = true
    let settings = AppIconSettings(client: client)
    await settings.select(.orange3D)
    #expect(settings.selectedIcon == .default)
    #expect(settings.errorMessage != nil)
    #expect(!settings.isChanging)
    client.fails = false
    await settings.select(.orange3D)
    #expect(settings.selectedIcon == .orange3D)
    #expect(settings.errorMessage == nil)
}

@MainActor
@Test func iconSelectionRejectsOverlappingRequests() async {
    let client = AppIconClientStub()
    client.suspends = true
    let settings = AppIconSettings(client: client)
    let first = Task { await settings.select(.violet3D) }
    for _ in 0..<100 where client.continuation == nil { await Task.yield() }
    #expect(settings.pendingIcon == .violet3D)
    #expect(settings.selectedIcon == .default)
    await settings.select(.orange3D)
    #expect(client.requests == ["IconViolet3D"])
    client.continuation?.resume()
    await first.value
    #expect(settings.selectedIcon == .violet3D)
    #expect(!settings.isChanging)
}

@MainActor
@Test func iconSelectionRefreshesExternalChangesAndSkipsUnavailableRequests() async {
    let client = AppIconClientStub()
    let settings = AppIconSettings(client: client)
    client.alternateIconName = "IconMidnight3D"
    settings.refreshSelection()
    #expect(settings.selectedIcon == .midnight3D)
    await settings.select(.midnight3D)
    #expect(client.requests.isEmpty)
    client.supportsAlternateIcons = false
    await settings.select(.mint3D)
    #expect(client.requests.isEmpty)
    #expect(settings.selectedIcon == .midnight3D)
    #expect(settings.errorMessage != nil)
}
