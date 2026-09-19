import Core
import Foundation
import StatisticsFeature

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

    func save(_ card: VocabularyCard) async throws {
        if let index = fetchedCards.firstIndex(where: { $0.id == card.id }) {
            fetchedCards[index] = card
        } else {
            fetchedCards.append(card)
        }
    }

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
final class AppCardImportRepositoryFake: CardImportRepository {
    private(set) var importedCards: [VocabularyCard] = []
    private(set) var replacingCardIDs: Set<UUID> = []
    private(set) var importCallCount = 0
    var result = CardMergeResult(cards: [], addedCount: 0, mergedCount: 0)

    func importCards(
        _ cards: [VocabularyCard],
        replacingCardIDs: Set<UUID>
    ) async throws -> CardMergeResult {
        importCallCount += 1
        importedCards = cards
        self.replacingCardIDs = replacingCardIDs
        return result
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

@MainActor
final class AppStudySessionStoreFake: StudySessionStore {
    var onClear: (() -> Void)?
    var snapshot: StudySessionSnapshot?
    private(set) var saveCount = 0
    private(set) var clearCount = 0

    init(snapshot: StudySessionSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func load() -> StudySessionSnapshot? { snapshot }

    func save(_ snapshot: StudySessionSnapshot) {
        self.snapshot = snapshot
        saveCount += 1
    }

    func clear() {
        onClear?()
        snapshot = nil
        clearCount += 1
    }
}

@MainActor
final class AppHistoryRepositoryFake: StudyHistoryRepository {
    var entries: [StudyHistoryEntry] = []
    var fails = false
    var onInsert: (() -> Void)?
    func fetchHistory() throws -> [StudyHistoryEntry] { entries }
    func insertIfNeeded(_ entry: StudyHistoryEntry) throws -> Bool {
        onInsert?()
        if fails { throw AppTestError.startup }
        guard !entries.contains(where: { $0.id == entry.id }) else { return false }
        entries.append(entry)
        return true
    }
}

@MainActor
final class AppStatisticsSpy: StatisticsRepository {
    var statistics = StudyStatistics()
    var recordedIDs: [UUID] = []
    var results: [StudyResult] = []
    var onRecord: (() -> Void)?
    func record(sessionID: UUID, mode: StudyMode, result: StudyResult) {
        onRecord?()
        guard !recordedIDs.contains(sessionID) else { return }
        recordedIDs.append(sessionID)
        results.append(result)
    }
}

extension StudySessionSnapshot {
    static func appLegacyFixture() throws -> StudySessionSnapshot {
        try JSONDecoder().decode(Self.self, from: Data("""
        {"version":1,"mode":"flashcards","direction":"englishToRussian",
         "selectedTagIDs":["00000000-0000-0000-0000-000000000700"],
         "originalCardIDs":["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002"],
         "queueCardIDs":["00000000-0000-0000-0000-000000000002"],
         "isShowingAnswer":false,"isRevealed":false,"forgottenCount":1,
         "repeatedCardIDs":["00000000-0000-0000-0000-000000000002"],
         "totalAssessmentCount":2,"startedAt":100,"accumulatedDurationSeconds":15}
        """.utf8))
    }

    static func appHistoryFixture(
        mode: StudyMode = .flashcards,
        queue: [UUID] = [.appFixture(2), .appFixture(3)],
        completedResult: StudyResult? = nil
    ) -> StudySessionSnapshot {
        StudySessionSnapshot(
            mode: mode, direction: .russianToEnglish, selectedTagIDs: [],
            originalCardIDs: [.appFixture(1), .appFixture(2), .appFixture(3)],
            queueCardIDs: queue, isShowingAnswer: true, isRevealed: true,
            forgottenCount: 1, repeatedCardIDs: [.appFixture(2)], totalAssessmentCount: 2,
            writingResponse: "old answer", writingEvaluation: .correct,
            startedAt: Date(timeIntervalSince1970: 100), accumulatedDurationSeconds: 15,
            sessionID: .appFixture(500), encounteredCardIDs: [.appFixture(1), .appFixture(2)],
            selectedTagNames: ["Original tag"],
            cardDisplaySnapshots: [StudyCardDisplaySnapshot(id: .appFixture(2), title: "Original title")],
            completedResult: completedResult
        )
    }
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
