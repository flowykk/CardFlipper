import Core
import Data
import Foundation
import SwiftData
import StatisticsFeature

#if DEBUG
struct AppLaunchConfiguration: Equatable {
    let usesInMemoryStore: Bool
    let seedsDeterministicVocabulary: Bool
    let preservesStudySession: Bool
    let seedsStudyHistory: Bool
    let seedsResumableStudy: Bool

    init(arguments: [String]) {
        seedsStudyHistory = arguments.contains("-uiTestHistory")
        seedsResumableStudy = arguments.contains("-uiTestResume")
        seedsDeterministicVocabulary = arguments.contains("-uiTestSeed")
            || seedsStudyHistory || seedsResumableStudy
        usesInMemoryStore = arguments.contains("-uiTesting") || seedsDeterministicVocabulary
        preservesStudySession = arguments.contains("-uiTestPreserveStudySession")
    }

    static var seededCardIDs: [UUID] { UITestVocabularySeed.cardIDs }
}
#endif

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let cards: any CardRepository
    let cardImporter: any CardImportRepository
    let tags: any TagRepository
    let dictionary: any DictionaryService
    let speech: any SpeechService
    let shuffler: any CardShuffler
    let statistics: any StatisticsRepository
    let history: any StudyHistoryRepository
    let dailyProgress: any DailyProgressRepository
    let studySessionStore: any StudySessionStore
    let studyTimer: StudyTimerController

    convenience init() throws {
#if DEBUG
        let configuration = AppLaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
        if configuration.usesInMemoryStore {
            try self.init(configuration: configuration)
            return
        }
#endif
        self.init(modelContainer: try ModelContainerFactory.makeDefault())
    }

#if DEBUG
    convenience init(configuration: AppLaunchConfiguration) throws {
        let container = try configuration.usesInMemoryStore
            ? ModelContainerFactory.makeInMemory()
            : ModelContainerFactory.makeDefault()
        if configuration.seedsDeterministicVocabulary {
            try UITestVocabularySeed.insert(into: container)
        }
        if configuration.usesInMemoryStore {
            let suiteName = "CardFlipper.UITests"
            let defaults = UserDefaults(suiteName: suiteName)!
            let preservedSnapshot = configuration.preservesStudySession
                ? UserDefaultsStudySessionStore(defaults: defaults).load()
                : nil
            defaults.removePersistentDomain(forName: suiteName)
            self.init(modelContainer: container, defaults: defaults)
            if let preservedSnapshot {
                studySessionStore.save(preservedSnapshot)
            } else if configuration.seedsResumableStudy {
                studySessionStore.save(UITestStudyHistorySeed.resumableSnapshot)
            }
            if configuration.seedsStudyHistory {
                try UITestStudyHistorySeed.insert(into: container)
            }
        } else {
            self.init(modelContainer: container)
        }
    }
#endif

    init(
        modelContainer: ModelContainer,
        defaults: UserDefaults = .standard,
        liveActivityClient: any StudyTimerLiveActivityClient = SystemStudyTimerLiveActivityClient()
    ) {
        self.modelContainer = modelContainer
        cards = SwiftDataCardRepository(container: modelContainer)
        cardImporter = SwiftDataCardImportRepository(container: modelContainer)
        tags = SwiftDataTagRepository(container: modelContainer)
        dictionary = FreeDictionaryClient()
        speech = SystemSpeechService()
        shuffler = SystemCardShuffler()
        statistics = UserDefaultsStatisticsRepository(defaults: defaults)
        history = SwiftDataStudyHistoryRepository(container: modelContainer)
        studySessionStore = UserDefaultsStudySessionStore(defaults: defaults)
        let dailyProgress = UserDefaultsDailyProgressRepository(defaults: defaults)
        self.dailyProgress = dailyProgress
        studyTimer = StudyTimerController(
            progress: dailyProgress,
            liveActivity: liveActivityClient
        )
    }
}

@MainActor
@Observable
final class AppStartupState {
    private(set) var container: AppContainer?
    private(set) var hasFailure = false

    private let makeContainer: @MainActor () throws -> AppContainer

    init(makeContainer: @escaping @MainActor () throws -> AppContainer = AppContainer.init) {
        self.makeContainer = makeContainer
        retry()
    }

    func retry() {
        do {
            container = try makeContainer()
            hasFailure = false
        } catch {
            container = nil
            hasFailure = true
        }
    }
}
