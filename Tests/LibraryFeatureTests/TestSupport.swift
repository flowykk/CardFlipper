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
    var addTagsError: Error?
    var saveError: Error?
    private(set) var deletedIDs: [UUID] = []
    private(set) var savedCards: [VocabularyCard] = []
    private(set) var addedTagIDs: Set<UUID> = []
    private(set) var addedTagCardIDs: Set<UUID> = []

    init(
        _ cards: [VocabularyCard] = [],
        fetchError: Error? = nil,
        deletionError: Error? = nil,
        saveError: Error? = nil,
        addTagsError: Error? = nil
    ) {
        fetchedCards = cards
        self.fetchError = fetchError
        self.deletionError = deletionError
        self.saveError = saveError
        self.addTagsError = addTagsError
    }

    func fetchCards() async throws -> [VocabularyCard] {
        if let fetchError {
            throw fetchError
        }
        return fetchedCards
    }

    func save(_ card: VocabularyCard) async throws {
        if let saveError {
            throw saveError
        }
        savedCards.append(card)
    }

    func delete(id: UUID) async throws {
        if let deletionError {
            throw deletionError
        }
        deletedIDs.append(id)
    }

    func addTags(ids: Set<UUID>, toCardIDs cardIDs: Set<UUID>) async throws {
        if let addTagsError {
            throw addTagsError
        }
        addedTagIDs = ids
        addedTagCardIDs = cardIDs
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
    var mutationError: Error?
    private(set) var deletedIDs: [UUID] = []
    private(set) var renameRequests: [(id: UUID, name: String)] = []
    private(set) var mergeRequests: [(sourceID: UUID, destinationID: UUID)] = []

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

    func rename(id: UUID, name: String) async throws -> Tag {
        if let mutationError { throw mutationError }
        renameRequests.append((id, name))
        return Tag(id: id, name: name)
    }

    func merge(id: UUID, into destinationID: UUID) async throws {
        if let mutationError { throw mutationError }
        mergeRequests.append((id, destinationID))
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
        tags: [Tag] = [],
        isLearned: Bool = false
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
            updatedAt: Date(timeIntervalSince1970: 2_000),
            isLearned: isLearned
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
