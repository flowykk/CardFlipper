import Core
import Foundation

enum AppTestError: Error {
    case startup
}

@MainActor
final class AppCardRepositoryFake: CardRepository {
    var fetchedCards: [VocabularyCard]
    var fetchError: Error?
    private(set) var fetchCount = 0

    init(_ cards: [VocabularyCard] = [], fetchError: Error? = nil) {
        fetchedCards = cards
        self.fetchError = fetchError
    }

    func fetchCards() async throws -> [VocabularyCard] {
        fetchCount += 1
        if let fetchError { throw fetchError }
        return fetchedCards
    }

    func save(_ card: VocabularyCard) async throws {}

    func addTags(ids: Set<UUID>, toCardIDs cardIDs: Set<UUID>) async throws {}
    func delete(id: UUID) async throws {}

    func duplicateCandidates(
        for draft: CardDraft,
        excluding id: UUID?
    ) async throws -> [VocabularyCard] {
        []
    }
}

@MainActor
final class AppTagRepositoryFake: TagRepository {
    var fetchedTags: [Tag]

    init(_ tags: [Tag] = []) {
        fetchedTags = tags
    }

    func fetchTags() async throws -> [Tag] { fetchedTags }

    func create(name: String) async throws -> Tag {
        Tag(id: .appFixture(900), name: name)
    }

    func delete(id: UUID) async throws {}
}

struct AppDictionaryServiceFake: DictionaryService {
    func suggestion(for text: String) async throws -> DictionarySuggestion? { nil }
}

@MainActor
final class AppSpeechServiceFake: SpeechService {
    func speak(_ text: String) {}
}

struct AppIdentityShuffler: CardShuffler {
    func shuffle(_ cards: [VocabularyCard]) -> [VocabularyCard] { cards }
}

extension UUID {
    static func appFixture(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

extension VocabularyCard {
    static func appFixture(id: Int, russian: String, english: String) -> VocabularyCard {
        VocabularyCard(
            id: .appFixture(id),
            russianMeanings: [
                RussianMeaning(id: .appFixture(id + 1_000), text: russian),
            ],
            englishVariants: [
                EnglishVariant(
                    id: .appFixture(id + 2_000),
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
}
