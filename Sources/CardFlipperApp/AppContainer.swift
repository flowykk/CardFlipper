import Core
import Data
import SwiftData

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let cards: any CardRepository
    let tags: any TagRepository
    let dictionary: any DictionaryService
    let speech: any SpeechService
    let shuffler: any CardShuffler

    convenience init() throws {
        self.init(modelContainer: try ModelContainerFactory.makeDefault())
    }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        cards = SwiftDataCardRepository(container: modelContainer)
        tags = SwiftDataTagRepository(container: modelContainer)
        dictionary = FreeDictionaryClient()
        speech = SystemSpeechService()
        shuffler = SystemCardShuffler()
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
