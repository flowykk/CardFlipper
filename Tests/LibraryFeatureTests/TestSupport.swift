import Foundation
@testable import Core

enum LibraryTestError: Error {
    case fetch
    case delete
}

@MainActor
final class CardRepositoryFake: CardRepository {
    var fetchedCards: [VocabularyCard]
    var fetchError: Error?
    var deletionError: Error?
    private(set) var deletedIDs: [UUID] = []

    init(
        _ cards: [VocabularyCard] = [],
        fetchError: Error? = nil,
        deletionError: Error? = nil
    ) {
        fetchedCards = cards
        self.fetchError = fetchError
        self.deletionError = deletionError
    }

    func fetchCards() async throws -> [VocabularyCard] {
        if let fetchError {
            throw fetchError
        }
        return fetchedCards
    }

    func save(_ card: VocabularyCard) async throws {}

    func delete(id: UUID) async throws {
        if let deletionError {
            throw deletionError
        }
        deletedIDs.append(id)
    }

    func duplicateCandidates(
        for draft: CardDraft,
        excluding id: UUID?
    ) async throws -> [VocabularyCard] {
        []
    }
}

@MainActor
final class TagRepositoryFake: TagRepository {
    var fetchedTags: [Tag]
    var fetchError: Error?
    var deletionError: Error?
    private(set) var deletedIDs: [UUID] = []

    init(
        _ tags: [Tag] = [],
        fetchError: Error? = nil,
        deletionError: Error? = nil
    ) {
        fetchedTags = tags
        self.fetchError = fetchError
        self.deletionError = deletionError
    }

    func fetchTags() async throws -> [Tag] {
        if let fetchError {
            throw fetchError
        }
        return fetchedTags
    }

    func create(name: String) async throws -> Tag {
        Tag(id: .fixture(99), name: name)
    }

    func delete(id: UUID) async throws {
        if let deletionError {
            throw deletionError
        }
        deletedIDs.append(id)
    }
}

extension UUID {
    static func fixture(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

extension Tag {
    static let work = Tag(id: .fixture(1), name: "Work")
    static let exam = Tag(id: .fixture(2), name: "Exam")
    static let travel = Tag(id: .fixture(3), name: "Travel")
    static let fixtures = [work, exam, travel]
}

extension VocabularyCard {
    static func fixture(
        id: UUID,
        russian: String,
        english: String,
        tags: [Tag] = []
    ) -> VocabularyCard {
        VocabularyCard(
            id: id,
            russianMeanings: [
                RussianMeaning(id: fixtureChildID(for: id, offset: 1), text: russian),
            ],
            englishVariants: [
                EnglishVariant(
                    id: fixtureChildID(for: id, offset: 2),
                    text: english,
                    ipa: nil,
                    partsOfSpeech: []
                ),
            ],
            tags: tags,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
    }

    static let workCard = fixture(
        id: .fixture(101),
        russian: "работа",
        english: "work",
        tags: [.work]
    )
    static let examCard = fixture(
        id: .fixture(102),
        russian: "экзамен",
        english: "exam",
        tags: [.exam]
    )
    static let sharedCard = fixture(
        id: .fixture(103),
        russian: "подготовка",
        english: "preparation",
        tags: [.work, .exam]
    )
    static let travelCard = fixture(
        id: .fixture(104),
        russian: "поездка",
        english: "trip",
        tags: [.travel]
    )
    static let taggedFixtures = [workCard, examCard, sharedCard, travelCard]

    private static func fixtureChildID(for id: UUID, offset: UInt8) -> UUID {
        var bytes = id.uuid
        bytes.15 &+= offset
        return UUID(uuid: bytes)
    }
}
