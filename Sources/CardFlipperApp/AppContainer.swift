import Core
import Data
import Foundation
import SwiftData
import StatisticsFeature

#if DEBUG
struct AppLaunchConfiguration: Equatable {
    let usesInMemoryStore: Bool
    let seedsDeterministicVocabulary: Bool

    init(arguments: [String]) {
        seedsDeterministicVocabulary = arguments.contains("-uiTestSeed")
        usesInMemoryStore = arguments.contains("-uiTesting") || seedsDeterministicVocabulary
    }

    static var seededCardIDs: [UUID] { UITestVocabularySeed.cardIDs }
}
#endif

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let cards: any CardRepository
    let tags: any TagRepository
    let dictionary: any DictionaryService
    let speech: any SpeechService
    let shuffler: any CardShuffler
    let statistics: any StatisticsRepository

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
        self.init(modelContainer: container)
    }
#endif

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        cards = SwiftDataCardRepository(container: modelContainer)
        tags = SwiftDataTagRepository(container: modelContainer)
        dictionary = FreeDictionaryClient()
        speech = SystemSpeechService()
        shuffler = SystemCardShuffler()
        statistics = UserDefaultsStatisticsRepository()
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
